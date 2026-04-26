from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from datetime import datetime, timedelta
from database import get_db
from middleware.auth import require_merchant
from services.stripe_service import create_cashback_transfer
from services.preference_learner import update_after_redemption
from services.qr_service import generate_qr_token, verify_qr_token
from services.push_service import send_push
from services.payone_simulator import get_shop_busyness, haversine_m

router = APIRouter(prefix="/api/coupons", tags=["coupons"])


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


@router.post("")
async def create_coupon(body: CouponCreateIn):
    """Persist a device-generated offer and mint the signed QR token."""
    db = await get_db()
    expires_at = (datetime.utcnow() + timedelta(minutes=body.expires_minutes)).isoformat()
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
            __import__("json").dumps(body.context_snapshot),
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

    return {"coupon_id": coupon_id, "id": coupon_id, "qr_token": token, "expires_at": expires_at}


@router.post("/auto-nearby")
async def auto_nearby_coupons(body: AutoNearbyIn):
    """Backend-owned automatic coupon creation based on merchant thresholds."""
    db = await get_db()
    async with db.execute(
        """SELECT * FROM shops
           WHERE is_active=1 AND COALESCE(auto_coupon_enabled,1)=1"""
    ) as cur:
        shops = await cur.fetchall()

    created = []
    now = datetime.utcnow()

    for shop in shops:
        distance_m = round(haversine_m(body.lat, body.lng, shop["latitude"], shop["longitude"]))
        trigger_radius = shop["auto_trigger_radius_m"] or 200
        if distance_m > min(trigger_radius, body.radius_m):
            continue

        busyness = await get_shop_busyness(shop["id"])
        typical = max(busyness.get("typical", 1), 1)
        ratio = busyness.get("txn_count_15min", 0) / typical
        threshold = shop["quiet_threshold_ratio"] or 0.6
        if ratio > threshold:
            continue

        frequency_minutes = shop["coupon_frequency_minutes"] or 60
        cutoff = (now - timedelta(minutes=frequency_minutes)).strftime("%Y-%m-%d %H:%M:%S")
        if body.user_id:
            async with db.execute(
                """SELECT id FROM coupons
                   WHERE shop_id=? AND user_id=? AND generated_at>=?
                   LIMIT 1""",
                (shop["id"], body.user_id, cutoff),
            ) as cur:
                existing = await cur.fetchone()
            if existing:
                continue

        async with db.execute(
            "SELECT * FROM products WHERE shop_id=? AND is_active=1 ORDER BY stock_level DESC, id LIMIT 1",
            (shop["id"],),
        ) as cur:
            product = await cur.fetchone()
        if not product:
            continue

        discount_pct = min(shop["max_discount_pct"] or 15, 20)
        cashback_cents = min(
            round(product["price_cents"] * discount_pct / 100),
            shop["cashback_budget_per_coupon_cents"] or 300,
        )
        expires_minutes = 60
        expires_at = (now + timedelta(minutes=expires_minutes)).isoformat()
        token = generate_qr_token()
        headline = f"{shop['name']} nearby reward"
        body_text = (
            f"You are {distance_m}m from {shop['name']} and it is quiet right now. "
            f"Redeem this offer at the counter for instant cashback."
        )
        why_now = (
            f"Created automatically because live Payone-style activity is at "
            f"{ratio:.0%} of typical demand, below the merchant threshold of {threshold:.0%}."
        )
        context_snapshot = {
            "distance_m": distance_m,
            "busyness": busyness,
            "merchant_threshold": threshold,
            "trigger_radius_m": trigger_radius,
            "source": "backend_auto_rule",
        }

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
                __import__("json").dumps(context_snapshot),
                token,
                expires_at,
            ),
        ) as cur:
            coupon_id = cur.lastrowid
        await db.commit()

        coupon = {
            "id": coupon_id,
            "coupon_id": coupon_id,
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
    if not verify_qr_token(token):
        raise HTTPException(400, "Invalid QR token")

    db = await get_db()
    async with db.execute(
        "SELECT c.*, s.name as shop_name, s.address, s.merchant_id "
        "FROM coupons c JOIN shops s ON c.shop_id=s.id WHERE c.qr_token=?",
        (token,),
    ) as cur:
        row = await cur.fetchone()

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
    if not verify_qr_token(body.token):
        raise HTTPException(400, "Invalid QR token")

    db = await get_db()
    async with db.execute(
        "SELECT c.*, s.merchant_id, s.category as shop_category, "
        "       u.stripe_account_id "
        "FROM coupons c "
        "JOIN shops s ON c.shop_id=s.id "
        "LEFT JOIN users u ON c.user_id=u.id "
        "WHERE c.qr_token=?",
        (body.token,),
    ) as cur:
        coupon = await cur.fetchone()

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

    await db.commit()

    # Update user preferences
    if coupon["user_id"]:
        await update_after_redemption(coupon["user_id"], coupon["shop_category"])

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
        "SELECT c.*, s.name AS shop_name FROM coupons c JOIN shops s ON c.shop_id=s.id "
        "WHERE c.user_id=? ORDER BY c.generated_at DESC",
        (user_id,),
    ) as cur:
        rows = await cur.fetchall()
    return [dict(row) for row in rows]


@router.get("/{coupon_id}")
async def coupon_detail(coupon_id: int):
    db = await get_db()
    async with db.execute(
        "SELECT c.*, s.name AS shop_name, s.category AS shop_category, s.address "
        "FROM coupons c JOIN shops s ON c.shop_id=s.id WHERE c.id=?",
        (coupon_id,),
    ) as cur:
        row = await cur.fetchone()
    if not row:
        raise HTTPException(404, "Coupon not found")
    return dict(row)
