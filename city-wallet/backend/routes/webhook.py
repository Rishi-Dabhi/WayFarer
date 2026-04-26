from fastapi import APIRouter, HTTPException, Request
import stripe

from config import settings
from database import get_db
from services.push_service import send_push

router = APIRouter(prefix="/api/webhooks", tags=["webhooks"])
stripe.api_key = settings.stripe_secret_key


@router.post("/stripe", include_in_schema=False)
async def stripe_webhook(request: Request):
    payload = await request.body()
    signature = request.headers.get("stripe-signature", "")

    if not settings.stripe_webhook_secret:
        raise HTTPException(500, "Stripe webhook secret is not configured")

    try:
        event = stripe.Webhook.construct_event(payload, signature, settings.stripe_webhook_secret)
    except Exception as exc:
        raise HTTPException(400, f"Invalid Stripe webhook: {exc}") from exc

    if event["type"] == "payment_intent.succeeded":
        payment_intent = event["data"]["object"]
        payment_intent_id = payment_intent["id"]

        db = await get_db()
        async with db.execute(
            "SELECT * FROM wallet_topups WHERE stripe_payment_intent=?",
            (payment_intent_id,),
        ) as cur:
            topup = await cur.fetchone()

        if topup and topup["status"] != "succeeded":
            await db.execute(
                "UPDATE wallet_topups SET status='succeeded' WHERE stripe_payment_intent=?",
                (payment_intent_id,),
            )
            await db.execute(
                "UPDATE merchant_wallets SET balance_cents=balance_cents+?, updated_at=datetime('now') WHERE merchant_id=?",
                (topup["amount_cents"], topup["merchant_id"]),
            )
            await db.commit()

            async with db.execute(
                "SELECT expo_push_token FROM users WHERE id=?",
                (topup["merchant_id"],),
            ) as cur:
                user = await cur.fetchone()
            amount = topup["amount_cents"] / 100
            await send_push(
                user["expo_push_token"] if user else None,
                "Wallet topped up",
                f"Your WayFarer balance increased by EUR {amount:.2f}.",
                {"screen": "merchant_wallet"},
            )

    return {"received": True}
