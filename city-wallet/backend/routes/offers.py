import json
from datetime import datetime, timedelta
from fastapi import APIRouter, HTTPException, Query
from fastapi.responses import StreamingResponse
from database import get_db
from services.context_aggregator import get_signals, best_shop_for_offer
from services.offer_generator import generate_offer_stream
from services.preference_learner import get_preferences
from services.qr_service import generate_qr_token
from config import DEMO_CONTEXTS

router = APIRouter(prefix="/api/offers", tags=["offers"])


@router.post("/generate")
async def generate_offer(
    user_lat: float = Query(...),
    user_lng: float = Query(...),
    user_id: int | None = Query(None),
    demo: str | None = Query(None),
):
    override = DEMO_CONTEXTS.get(demo) if demo else None
    signals = await get_signals(user_lat, user_lng, demo_override=override)
    shop_data = await best_shop_for_offer(signals)
    prefs = await get_preferences(user_id) if user_id else {}

    async def event_stream():
        yield f"data: {json.dumps({'type': 'context', 'payload': signals})}\n\n"

        if not shop_data:
            yield f"data: {json.dumps({'type': 'error', 'payload': {'message': 'No nearby shops found'}})}\n\n"
            return

        offer_data: dict = {}
        async for chunk in generate_offer_stream(
            shop=shop_data["shop"],
            products=shop_data["products"],
            signals=signals,
            prefs=prefs,
            distance_m=shop_data["distance_m"],
            busyness=shop_data["busyness"],
        ):
            if '"type": "offer_data"' in chunk:
                raw = json.loads(chunk.removeprefix("data: ").strip())
                offer_data = raw["payload"]
            yield chunk

        # Persist the coupon
        if offer_data:
            db = await get_db()
            shop = shop_data["shop"]
            token = generate_qr_token()
            expires_at = (datetime.utcnow() + timedelta(minutes=offer_data.get("expires_minutes", 60))).isoformat()

            product_id = None
            if offer_data.get("product_name"):
                for p in shop_data["products"]:
                    if p["name"].lower() == offer_data["product_name"].lower():
                        product_id = p["id"]
                        break

            async with db.execute(
                """INSERT INTO coupons
                   (shop_id, user_id, headline, body_text, why_now, discount_pct,
                    cashback_cents, product_id, context_snapshot, qr_token, expires_at)
                   VALUES (?,?,?,?,?,?,?,?,?,?,?)""",
                (
                    shop["id"],
                    user_id,
                    offer_data.get("headline", ""),
                    offer_data.get("body_text", ""),
                    offer_data.get("why_now", ""),
                    offer_data.get("discount_pct", 10),
                    offer_data.get("cashback_cents", 0),
                    product_id,
                    json.dumps(signals),
                    token,
                    expires_at,
                ),
            ) as cur:
                coupon_id = cur.lastrowid
            await db.commit()

            coupon = {
                "id": coupon_id,
                "qr_token": token,
                "shop_name": shop["name"],
                "shop_id": shop["id"],
                "expires_at": expires_at,
                **offer_data,
            }
            yield f"data: {json.dumps({'type': 'offer', 'payload': coupon})}\n\n"

    return StreamingResponse(event_stream(), media_type="text/event-stream")


@router.get("/{coupon_id}")
async def get_offer(coupon_id: int):
    db = await get_db()
    async with db.execute(
        "SELECT c.*, s.name as shop_name, s.address, s.category FROM coupons c "
        "JOIN shops s ON c.shop_id=s.id WHERE c.id=?",
        (coupon_id,),
    ) as cur:
        row = await cur.fetchone()
    if not row:
        raise HTTPException(404, "Coupon not found")
    return dict(row)


@router.get("/user/{user_id}")
async def get_user_offers(user_id: int):
    db = await get_db()
    async with db.execute(
        "SELECT c.*, s.name as shop_name, s.address FROM coupons c "
        "JOIN shops s ON c.shop_id=s.id "
        "WHERE c.user_id=? ORDER BY c.generated_at DESC LIMIT 20",
        (user_id,),
    ) as cur:
        rows = await cur.fetchall()
    return [dict(r) for r in rows]
