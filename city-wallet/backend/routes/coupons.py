import json
from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from datetime import datetime, timedelta
from database import get_db
from middleware.auth import require_merchant
from services.stripe_service import create_cashback_transfer
from services.preference_learner import update_after_redemption, get_preferences
from services.qr_service import generate_qr_token, verify_qr_token
from services.push_service import send_push
from services.payone_simulator import get_shop_busyness, haversine_m
from services.gemma_offer_generator import generate_coupon_copy
from services.weather_service import get_weather
from config import settings

router = APIRouter(prefix="/api/coupons", tags=["coupons"])
OFFER_ENGINE_VERSION = 4
DEMO_MIN_EXPIRES_MINUTES = 24 * 60
CREATIVE_LANES = [
    {
        "name": "direct",
        "headline_style": "plain and specific, merchant/product first",
        "avoid": "fuel, refuel, treat, perfect",
    },
    {
        "name": "cashback",
        "headline_style": "cashback-led, value first",
        "avoid": "morning fuel, refuel, perfect",
    },
    {
        "name": "weather",
        "headline_style": "weather-aware but not poetic",
        "avoid": "Sunday morning, fuel, perfect",
    },
    {
        "name": "nearby",
        "headline_style": "distance or convenience-led",
        "avoid": "fuel, refuel, treat",
    },
    {
        "name": "inventory",
        "headline_style": "product or stock-led",
        "avoid": "morning, perfect, quick stop",
    },
    {
        "name": "quiet",
        "headline_style": "quiet-time merchant need, subtle urgency",
        "avoid": "fuel, refuel, Sunday morning",
    },
]


class CouponCreateIn(BaseModel):
    shop_id: int
    user_id: int | None = None
    headline: str
    body_text: str
    why_now: str
    discount_pct: int
    cashback_cents: int
    product_id: int | None = None
    context_snapshot: dict
    expires_minutes: int = 60


class AutoNearbyIn(BaseModel):
    lat: float
    lng: float
    user_id: int | None = None
    radius_m: int = 800
    max_coupons: int = 3


def _demo_expiry_minutes(minutes: int | None) -> int:
    try:
        requested = int(minutes or 60)
    except (TypeError, ValueError):
        requested = 60
    return max(requested, DEMO_MIN_EXPIRES_MINUTES)


def _time_context(now: datetime) -> dict:
    hour = now.hour
    if hour < 6:
        period = "night"
    elif hour < 11:
        period = "morning"
    elif hour < 14:
        period = "lunch"
    elif hour < 17:
        period = "afternoon"
    elif hour < 20:
        period = "evening"
    else:
        period = "night"
    return {"hour": hour, "period": period, "day_of_week": now.strftime("%A")}


async def _weather_context(lat: float, lng: float) -> dict:
    if not settings.openweather_api_key:
        return {"available": False, "reason": "missing_openweather_api_key"}
    try:
        return {"available": True, **await get_weather(lat, lng)}
    except Exception as exc:
        return {"available": False, "reason": type(exc).__name__}


def _context_match(shop: dict, product: dict, time_ctx: dict, weather: dict) -> tuple[float, list[str]]:
    category = (shop["category"] or "").lower()
    product_text = f"{product['name']} {product['description'] or ''} {product['category'] or ''}".lower()
    period = time_ctx.get("period")
    temp = weather.get("feels_like", weather.get("temp"))
    condition = (weather.get("condition") or "").lower()
    score = 0.0
    reasons: list[str] = []

    def add(points: float, reason: str) -> None:
        nonlocal score
        score += points
        reasons.append(reason)

    if period == "morning":
        if category == "cafe" or any(term in product_text for term in ("coffee", "tea", "breakfast", "pastry", "bakery")):
            add(0.35, "morning fit")
    elif period == "lunch":
        if category in ("restaurant", "cafe") or any(term in product_text for term in ("lunch", "meal", "sandwich", "salad", "pizza", "wrap")):
            add(0.40, "lunch fit")
    elif period == "afternoon":
        if category in ("cafe", "retail") or any(term in product_text for term in ("coffee", "tea", "snack", "cake")):
            add(0.25, "afternoon fit")
    elif period == "evening":
        if category in ("restaurant", "bar") or any(term in product_text for term in ("dinner", "drink", "pizza", "pasta")):
            add(0.35, "evening fit")

    if isinstance(temp, (int, float)):
        if temp <= 10 and (category == "cafe" or any(term in product_text for term in ("coffee", "tea", "soup", "hot", "warm"))):
            add(0.35, "cold-weather fit")
        elif temp >= 22 and any(term in product_text for term in ("cold", "iced", "drink", "salad", "ice")):
            add(0.25, "warm-weather fit")

    if any(term in condition for term in ("rain", "drizzle", "snow", "cold", "wind")):
        if category in ("cafe", "restaurant") or any(term in product_text for term in ("coffee", "tea", "soup", "hot")):
            add(0.30, "shelter/weather fit")

    return min(score, 1.0), reasons[:3]


def _stock_score(product: dict) -> float:
    stock = (product["stock_level"] or "normal").lower()
    if stock == "high":
        return 0.20
    if stock == "low":
        return -0.10
    return 0.0


def _load_snapshot(raw: str | None) -> dict:
    if not raw:
        return {}
    try:
        return json.loads(raw)
    except Exception:
        return {}


def _context_signature(
    product: dict,
    distance_m: int,
    ratio: float,
    time_ctx: dict,
    weather: dict,
    busyness: dict,
    context_reasons: list[str],
    urgency: str,
) -> dict:
    return {
        "product_id": product["id"],
        "period": time_ctx.get("period"),
        "hour": time_ctx.get("hour"),
        "weather_condition": weather.get("condition"),
        "weather_temp": weather.get("feels_like", weather.get("temp")),
        "busyness": busyness.get("level"),
        "ratio_bucket": round(ratio, 1),
        "distance_bucket_m": int(distance_m // 100 * 100),
        "reasons": context_reasons,
        "urgency": urgency,
    }


def _creative_brief(index: int, shop: dict, product: dict) -> dict:
    lane = CREATIVE_LANES[index % len(CREATIVE_LANES)]
    return {
        **lane,
        "must_include": product["name"],
        "shop_name_policy": "Use the shop name only if it sounds natural; do not end every headline with the shop name.",
        "distinctness": "Make this offer noticeably different from the other nearby cards.",
    }


def _forbidden_openers(headlines: list[str]) -> list[str]:
    openers = []
    for headline in headlines:
        words = [word.strip(".,:;!?-").lower() for word in headline.split()]
        words = [word for word in words if word]
        if len(words) >= 2:
            openers.append(" ".join(words[:2]))
        if len(words) >= 3:
            openers.append(" ".join(words[:3]))
    return sorted(set(openers))[:10]


@router.post("")
async def create_coupon(body: CouponCreateIn):
    """Persist a device-generated offer and mint the signed QR token."""
    db = await get_db()
    expires_at = (datetime.utcnow() + timedelta(minutes=_demo_expiry_minutes(body.expires_minutes))).isoformat()
    token = generate_qr_token()

    async with db.execute(
        """INSERT INTO coupons
           (shop_id,user_id,headline,body_text,why_now,discount_pct,cashback_cents,
            product_id,context_snapshot,qr_token,expires_at)
           VALUES (?,?,?,?,?,?,?,?,?,?,?)""",
        (
            body.shop_id,
            body.user_id,
            body.headline,
            body.body_text,
            body.why_now,
            body.discount_pct,
            body.cashback_cents,
            body.product_id,
            json.dumps(body.context_snapshot),
            token,
            expires_at,
        ),
    ) as cur:
        coupon_id = cur.lastrowid
    await db.commit()

    async with db.execute("SELECT name FROM shops WHERE id=?", (body.shop_id,)) as cur:
        shop = await cur.fetchone()

    if body.user_id:
        async with db.execute("SELECT expo_push_token FROM users WHERE id=?", (body.user_id,)) as cur:
            user = await cur.fetchone()
        await send_push(
            user["expo_push_token"] if user else None,
            f"New offer: {body.headline}",
            f"Available now at {shop['name'] if shop else 'a nearby shop'}.",
            {"screen": "coupon", "coupon_id": str(coupon_id)},
        )

    return {"coupon_id": coupon_id, "qr_token": token, "expires_at": expires_at}


@router.post("/auto-nearby")
async def auto_nearby_coupons(body: AutoNearbyIn):
    """Backend-owned automatic coupon creation based on merchant thresholds."""
    db = await get_db()

    active_count = 0
    if body.user_id:
        async with db.execute(
            """SELECT COUNT(*) AS count FROM coupons
               WHERE user_id=? AND status='active' AND expires_at > datetime('now')
                 AND NOT (
                   discount_pct=10
                   AND cashback_cents=100
                   AND COALESCE(context_snapshot,'') NOT LIKE ?
                 )""",
            (body.user_id, f'%"offer_engine_version": {OFFER_ENGINE_VERSION}%'),
        ) as cur:
            active_row = await cur.fetchone()
        active_count = active_row["count"] if active_row else 0

    async with db.execute(
        """SELECT * FROM shops
           WHERE is_active=1 AND COALESCE(auto_coupon_enabled,1)=1"""
    ) as cur:
        shops = await cur.fetchall()

    now = datetime.utcnow()
    local_now = datetime.now()
    time_ctx = _time_context(local_now)
    weather = await _weather_context(body.lat, body.lng)
    user_prefs = await get_preferences(body.user_id) if body.user_id else {}
    candidates = []

    for shop in shops:
        distance_m = round(haversine_m(body.lat, body.lng, shop["latitude"], shop["longitude"]))
        trigger_radius = shop["auto_trigger_radius_m"] or 200

        busyness = await get_shop_busyness(shop["id"])
        typical = max(busyness.get("typical", 1), 1)
        ratio = busyness.get("txn_count_15min", 0) / typical
        threshold = shop["quiet_threshold_ratio"] or 0.6

        frequency_minutes = shop["coupon_frequency_minutes"] or 60
        cutoff = (now - timedelta(minutes=frequency_minutes)).isoformat()
        active_existing = None
        if body.user_id:
            async with db.execute(
                """SELECT id, discount_pct, cashback_cents, context_snapshot
                   FROM coupons
                   WHERE shop_id=? AND user_id=?
                     AND status='active' AND expires_at > datetime('now')
                   LIMIT 1""",
                (shop["id"], body.user_id),
            ) as cur:
                active_existing = await cur.fetchone()

            if active_existing is None:
                async with db.execute(
                    """SELECT id FROM coupons
                       WHERE shop_id=? AND user_id=?
                         AND status='active' AND expires_at > datetime('now')
                         AND datetime(generated_at)>=datetime(?)
                       LIMIT 1""",
                    (shop["id"], body.user_id, cutoff),
                ) as cur:
                    recent_existing = await cur.fetchone()
                if recent_existing:
                    continue
        else:
            async with db.execute(
                """SELECT id FROM coupons
                   WHERE shop_id=?
                     AND status='active' AND expires_at > datetime('now')
                     AND datetime(generated_at)>=datetime(?)
                   LIMIT 1""",
                (shop["id"], cutoff),
            ) as cur:
                recent_shop_coupon = await cur.fetchone()
            if recent_shop_coupon:
                continue

        async with db.execute(
            "SELECT * FROM products WHERE shop_id=? AND is_active=1 ORDER BY id LIMIT 6",
            (shop["id"],),
        ) as cur:
            products = await cur.fetchall()
        if not products:
            continue

        product_options = []
        for product in products:
            context_score, context_reasons = _context_match(shop, product, time_ctx, weather)
            product_options.append((context_score + _stock_score(product), context_score, context_reasons, product))
        product_options.sort(key=lambda item: (-item[0], item[3]["price_cents"]))
        _, context_score, context_reasons, product = product_options[0]

        discount_pct = min(shop["max_discount_pct"] or 15, 20)
        cashback_cents = min(
            round(product["price_cents"] * discount_pct / 100),
            shop["cashback_budget_per_coupon_cents"] or 300,
        )
        quiet_score = max(0.0, threshold - ratio) / max(threshold, 0.1)
        if ratio > threshold:
            quiet_score = max(0.0, 1 - ratio) * 0.25
        discovery_radius = max(body.radius_m, 1)
        distance_score = 1 / (1 + (distance_m / discovery_radius))
        trigger_score = 1 / (1 + (distance_m / max(trigger_radius, 1)))
        cat_boost = user_prefs.get("category_affinity", {}).get(shop["category"] or "", 0.0)
        prod_boost = user_prefs.get("product_affinity", {}).get(str(product["id"]), 0.0)
        pref_score = min(cat_boost * 0.6 + prod_boost * 0.4, 1.0)
        score = (
            quiet_score * 0.35
            + distance_score * 0.22
            + context_score * 0.22
            + trigger_score * 0.09
            + pref_score * 0.12
        )
        score_components = {
            "quiet": round(quiet_score, 3),
            "distance": round(distance_score, 3),
            "context": round(context_score, 3),
            "trigger": round(trigger_score, 3),
            "preference": round(pref_score, 3),
        }
        urgency = "high" if ratio <= threshold * 0.5 else "normal"
        if distance_m > body.radius_m:
            urgency = "fallback"
        signature = _context_signature(product, distance_m, ratio, time_ctx, weather, busyness, context_reasons, urgency)
        existing_coupon_id = None
        if active_existing is not None:
            snapshot = _load_snapshot(active_existing["context_snapshot"])
            existing_coupon_id = active_existing["id"]
            if (
                snapshot.get("offer_engine_version") == OFFER_ENGINE_VERSION
                and snapshot.get("context_signature") == signature
            ):
                continue
        candidates.append((score, distance_m, shop, product, busyness, ratio, threshold, discount_pct, cashback_cents, trigger_radius, context_reasons, score_components, urgency, signature, existing_coupon_id))

    created = []
    max_coupons = max(0, min(body.max_coupons, 3))
    candidates.sort(key=lambda item: (-item[0], item[1]))
    new_coupon_slots = max(0, 5 - active_count) if body.user_id else max_coupons
    new_coupon_count = 0
    updated_coupon_count = 0
    generated_headlines: list[str] = []

    for creative_index, (_, distance_m, shop, product, busyness, ratio, threshold, discount_pct, cashback_cents, trigger_radius, context_reasons, score_components, urgency, signature, existing_coupon_id) in enumerate(candidates):
        if existing_coupon_id is None and new_coupon_count >= max_coupons:
            continue
        if existing_coupon_id is None and new_coupon_count >= new_coupon_slots:
            continue
        if existing_coupon_id is not None and updated_coupon_count >= 5:
            continue
        context = {
            "time": time_ctx,
            "weather": weather,
            "reasons": context_reasons,
            "urgency": urgency,
            "score_components": score_components,
            "creative_brief": _creative_brief(creative_index, shop, product),
            "neighbor_headlines": generated_headlines[-6:],
            "forbidden_openers": _forbidden_openers(generated_headlines),
        }
        offer = await generate_coupon_copy(dict(shop), dict(product), distance_m, busyness, ratio, threshold, context)
        discount_pct = offer["discount_pct"]
        cashback_cents = offer["cashback_cents"]
        expires_minutes = _demo_expiry_minutes(offer.get("expires_minutes"))
        expires_at = (now + timedelta(minutes=expires_minutes)).isoformat()
        token = generate_qr_token()
        headline = offer["headline"]
        body_text = offer["body_text"]
        why_now = offer["why_now"]
        context_snapshot = {
            "distance_m": distance_m,
            "busyness": busyness,
            "time": time_ctx,
            "weather": weather,
            "context_reasons": context_reasons,
            "score_components": context["score_components"],
            "creative_brief": context["creative_brief"],
            "neighbor_headlines": context["neighbor_headlines"],
            "merchant_threshold": threshold,
            "trigger_radius_m": trigger_radius,
            "requested_radius_m": body.radius_m,
            "context_signature": signature,
            "source": "backend_auto_rule",
            "offer_engine_version": OFFER_ENGINE_VERSION,
            "copy_source": "gemma",
            "tone": offer.get("tone"),
        }

        if existing_coupon_id is not None:
            coupon_id = existing_coupon_id
            await db.execute(
                """UPDATE coupons
                   SET headline=?, body_text=?, why_now=?, discount_pct=?, cashback_cents=?,
                       product_id=?, context_snapshot=?, expires_at=?, generated_at=datetime('now')
                   WHERE id=? AND status='active'""",
                (
                    headline,
                    body_text,
                    why_now,
                    discount_pct,
                    cashback_cents,
                    product["id"],
                    json.dumps(context_snapshot),
                    expires_at,
                    coupon_id,
                ),
            )
            updated_coupon_count += 1
        else:
            async with db.execute(
                """INSERT INTO coupons
                   (shop_id,user_id,headline,body_text,why_now,discount_pct,cashback_cents,
                    product_id,context_snapshot,qr_token,expires_at)
                   VALUES (?,?,?,?,?,?,?,?,?,?,?)""",
                (
                    shop["id"],
                    body.user_id,
                    headline,
                    body_text,
                    why_now,
                    discount_pct,
                    cashback_cents,
                    product["id"],
                    json.dumps(context_snapshot),
                    token,
                    expires_at,
                ),
            ) as cur:
                coupon_id = cur.lastrowid
            new_coupon_count += 1
        await db.commit()

        coupon = {
            "coupon_id": coupon_id,
            "updated": existing_coupon_id is not None,
            "shop_id": shop["id"],
            "shop_name": shop["name"],
            "headline": headline,
            "body_text": body_text,
            "why_now": why_now,
            "discount_pct": discount_pct,
            "cashback_cents": cashback_cents,
            "qr_token": token,
            "expires_at": expires_at,
        }
        created.append(coupon)
        generated_headlines.append(headline)

        if body.user_id:
            async with db.execute("SELECT expo_push_token FROM users WHERE id=?", (body.user_id,)) as cur:
                user = await cur.fetchone()
            await send_push(
                user["expo_push_token"] if user else None,
                f"New offer at {shop['name']}",
                headline,
                {"screen": "coupon", "coupon_id": str(coupon_id)},
            )

    return {"created": created, "count": len(created)}


@router.get("/validate/{token}")
async def validate_coupon(token: str):
    db = await get_db()
    async with db.execute(
        "SELECT c.*, s.name as shop_name, s.address, s.merchant_id "
        "FROM coupons c JOIN shops s ON c.shop_id=s.id WHERE c.qr_token=?",
        (token,),
    ) as cur:
        row = await cur.fetchone()

    # Keep old demo coupons redeemable after a local JWT_SECRET change.
    if not row and not verify_qr_token(token):
        raise HTTPException(400, "Invalid QR token")
    if not row:
        raise HTTPException(404, "Coupon not found")

    now = datetime.utcnow().isoformat()
    if row["status"] == "redeemed":
        raise HTTPException(409, "Already redeemed")
    if row["status"] == "expired" or row["expires_at"] < now:
        raise HTTPException(410, "Coupon expired")

    return {**dict(row), "valid": True}


class RedeemIn(BaseModel):
    token: str
    merchant_id: int


@router.post("/redeem")
async def redeem_coupon(body: RedeemIn, merchant: dict = Depends(require_merchant)):
    db = await get_db()
    async with db.execute(
        "SELECT c.*, s.merchant_id, s.category as shop_category, "
        "       u.stripe_account_id, "
        "       p.price_cents as product_price_cents, p.category as product_category "
        "FROM coupons c "
        "JOIN shops s ON c.shop_id=s.id "
        "LEFT JOIN users u ON c.user_id=u.id "
        "LEFT JOIN products p ON c.product_id=p.id "
        "WHERE c.qr_token=?",
        (body.token,),
    ) as cur:
        coupon = await cur.fetchone()

    # Keep old demo coupons redeemable after a local JWT_SECRET change.
    if not coupon and not verify_qr_token(body.token):
        raise HTTPException(400, "Invalid QR token")
    if not coupon:
        raise HTTPException(404, "Coupon not found")
    if coupon["status"] != "active":
        raise HTTPException(409, f"Coupon is {coupon['status']}")
    if coupon["merchant_id"] != body.merchant_id:
        raise HTTPException(403, "This coupon belongs to a different shop")

    now = datetime.utcnow().isoformat()
    if coupon["expires_at"] < now:
        await db.execute("UPDATE coupons SET status='expired' WHERE id=?", (coupon["id"],))
        await db.commit()
        raise HTTPException(410, "Coupon expired")

    # Check merchant wallet balance
    async with db.execute(
        "SELECT balance_cents FROM merchant_wallets WHERE merchant_id=?",
        (body.merchant_id,),
    ) as cur:
        wallet = await cur.fetchone()

    cashback = coupon["cashback_cents"]
    if not wallet or wallet["balance_cents"] < cashback:
        raise HTTPException(402, "Insufficient wallet balance")

    # Deduct from merchant wallet
    await db.execute(
        "UPDATE merchant_wallets SET balance_cents=balance_cents-?, updated_at=datetime('now') "
        "WHERE merchant_id=?",
        (cashback, body.merchant_id),
    )

    # Mark coupon redeemed
    await db.execute(
        "UPDATE coupons SET status='redeemed', redeemed_at=datetime('now') WHERE id=?",
        (coupon["id"],),
    )

    # Stripe transfer to consumer
    transfer_id = None
    if coupon["stripe_account_id"] and cashback > 0:
        transfer_id = await create_cashback_transfer(cashback, coupon["stripe_account_id"], coupon["id"])

    # Record transaction
    async with db.execute(
        """INSERT INTO transactions
           (coupon_id, shop_id, user_id, cashback_cents, stripe_transfer_id, status)
           VALUES (?,?,?,?,?,?)""",
        (
            coupon["id"],
            coupon["shop_id"],
            coupon["user_id"],
            cashback,
            transfer_id,
            "completed" if transfer_id else "pending",
        ),
    ) as cur:
        txn_id = cur.lastrowid

    # Record purchase event
    if coupon["user_id"]:
        await db.execute(
            """INSERT INTO purchase_events
               (user_id, shop_id, coupon_id, product_id, amount_cents,
                cashback_cents, discount_pct, source)
               VALUES (?,?,?,?,?,?,?,?)""",
            (
                coupon["user_id"],
                coupon["shop_id"],
                coupon["id"],
                coupon["product_id"],
                coupon["product_price_cents"] or 0,
                cashback,
                coupon["discount_pct"],
                "qr_redemption",
            ),
        )

    await db.commit()

    # Update user preferences with richer context
    if coupon["user_id"]:
        from datetime import datetime as _dt
        await update_after_redemption(
            coupon["user_id"],
            coupon["shop_category"],
            product_id=coupon["product_id"],
            product_category=coupon["product_category"],
            amount_cents=coupon["product_price_cents"] or 0,
            cashback_cents=cashback,
            discount_pct=coupon["discount_pct"],
            hour=_dt.utcnow().hour,
        )

    async with db.execute(
        "SELECT balance_cents FROM merchant_wallets WHERE merchant_id=?", (body.merchant_id,)
    ) as cur:
        new_wallet = await cur.fetchone()

    return {
        "success": True,
        "transaction_id": txn_id,
        "cashback_cents": cashback,
        "stripe_transfer_id": transfer_id,
        "new_wallet_balance": new_wallet["balance_cents"] if new_wallet else 0,
    }


@router.get("/user/{user_id}")
async def user_coupons(user_id: int):
    db = await get_db()
    async with db.execute(
        "SELECT c.*, s.name AS shop_name, p.name AS product_name "
        "FROM coupons c JOIN shops s ON c.shop_id=s.id "
        "LEFT JOIN products p ON c.product_id=p.id "
        "WHERE c.user_id=? ORDER BY c.generated_at DESC",
        (user_id,),
    ) as cur:
        rows = await cur.fetchall()
    return [dict(row) for row in rows]


@router.get("/user/{user_id}/history")
async def user_coupon_history(user_id: int, limit: int = 4):
    db = await get_db()
    limit = max(1, min(limit, 10))
    async with db.execute(
        "SELECT c.*, s.name AS shop_name, p.name AS product_name "
        "FROM coupons c JOIN shops s ON c.shop_id=s.id "
        "LEFT JOIN products p ON c.product_id=p.id "
        "WHERE c.user_id=? AND c.status IN ('redeemed', 'expired') "
        "ORDER BY COALESCE(c.redeemed_at, c.generated_at) DESC LIMIT ?",
        (user_id, limit),
    ) as cur:
        rows = await cur.fetchall()
    return [dict(row) for row in rows]


@router.get("/{coupon_id}")
async def coupon_detail(coupon_id: int):
    db = await get_db()
    async with db.execute(
        "SELECT c.*, s.name AS shop_name, s.category AS shop_category, s.address, p.name AS product_name "
        "FROM coupons c JOIN shops s ON c.shop_id=s.id "
        "LEFT JOIN products p ON c.product_id=p.id WHERE c.id=?",
        (coupon_id,),
    ) as cur:
        row = await cur.fetchone()
    if not row:
        raise HTTPException(404, "Coupon not found")
    return dict(row)
