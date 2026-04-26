import stripe
from config import settings

stripe.api_key = settings.stripe_secret_key


async def create_payment_intent(amount_cents: int, merchant_id: int) -> dict:
    intent = stripe.PaymentIntent.create(
        amount=amount_cents,
        currency="eur",
        metadata={"merchant_id": str(merchant_id), "purpose": "wallet_topup"},
        automatic_payment_methods={"enabled": True},
    )
    return {"client_secret": intent.client_secret, "payment_intent_id": intent.id}


async def create_cashback_transfer(amount_cents: int, stripe_account_id: str, coupon_id: int) -> str | None:
    """Transfer cashback from platform account to consumer's connected account."""
    if not stripe_account_id or not settings.stripe_secret_key:
        return None
    transfer = stripe.Transfer.create(
        amount=amount_cents,
        currency="eur",
        destination=stripe_account_id,
        metadata={"coupon_id": str(coupon_id), "purpose": "cashback"},
    )
    return transfer.id


async def create_express_account(email: str) -> str:
    """Create a Stripe Express account for a new consumer (test mode)."""
    if not settings.stripe_secret_key:
        return ""
    account = stripe.Account.create(
        type="express",
        country="DE",
        email=email,
        capabilities={"transfers": {"requested": True}},
    )
    return account.id
