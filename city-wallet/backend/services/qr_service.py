import uuid
import hmac
import hashlib
from config import settings


def generate_qr_token(coupon_id: int | None = None) -> str:
    raw = str(uuid.uuid4())
    sig = hmac.new(settings.jwt_secret.encode(), raw.encode(), hashlib.sha256).hexdigest()[:8]  # type: ignore[attr-defined]
    return f"{raw}-{sig}"


def verify_qr_token(token: str) -> bool:
    parts = token.rsplit("-", 1)
    if len(parts) != 2:
        return False
    raw, sig = parts
    expected = hmac.new(settings.jwt_secret.encode(), raw.encode(), hashlib.sha256).hexdigest()[:8]  # type: ignore[attr-defined]
    return hmac.compare_digest(sig, expected)
