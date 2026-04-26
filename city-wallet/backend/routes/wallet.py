from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from config import settings
from database import get_db
from middleware.auth import require_merchant
from services.stripe_service import create_payment_intent

router = APIRouter(prefix="/api/wallet", tags=["wallet"])


@router.get("/balance/{merchant_id}")
async def get_balance(merchant_id: int, merchant: dict = Depends(require_merchant)):
    db = await get_db()
    async with db.execute(
        "SELECT balance_cents, updated_at FROM merchant_wallets WHERE merchant_id=?",
        (merchant_id,),
    ) as cur:
        wallet = await cur.fetchone()
    if not wallet:
        raise HTTPException(404, "Wallet not found")

    async with db.execute(
        "SELECT amount_cents, status, created_at FROM wallet_topups "
        "WHERE merchant_id=? ORDER BY created_at DESC LIMIT 10",
        (merchant_id,),
    ) as cur:
        topups = await cur.fetchall()

    return {
        "balance_cents": wallet["balance_cents"],
        "updated_at": wallet["updated_at"],
        "topup_history": [dict(t) for t in topups],
    }


class TopUpIn(BaseModel):
    merchant_id: int
    amount_cents: int


@router.post("/topup")
async def initiate_topup(body: TopUpIn, merchant: dict = Depends(require_merchant)):
    if body.amount_cents < 100:
        raise HTTPException(400, "Minimum top-up is €1.00")

    result = await create_payment_intent(body.amount_cents, body.merchant_id)

    db = await get_db()
    await db.execute(
        "INSERT INTO wallet_topups (merchant_id, amount_cents, stripe_payment_intent, status) VALUES (?,?,?,'pending')",
        (body.merchant_id, body.amount_cents, result["payment_intent_id"]),
    )
    await db.commit()

    return {
        "client_secret": result["client_secret"],
        "payment_intent_id": result["payment_intent_id"],
        "amount_cents": body.amount_cents,
        "publishable_key": settings.stripe_publishable_key,
    }


class ConfirmIn(BaseModel):
    payment_intent_id: str


@router.post("/topup/confirm")
async def confirm_topup(body: ConfirmIn, merchant: dict = Depends(require_merchant)):
    db = await get_db()
    async with db.execute(
        "SELECT * FROM wallet_topups WHERE stripe_payment_intent=?",
        (body.payment_intent_id,),
    ) as cur:
        topup = await cur.fetchone()
    if not topup:
        raise HTTPException(404, "Top-up not found")
    if topup["status"] == "succeeded":
        return {"already_applied": True}

    await db.execute(
        "UPDATE wallet_topups SET status='succeeded' WHERE stripe_payment_intent=?",
        (body.payment_intent_id,),
    )
    await db.execute(
        "UPDATE merchant_wallets SET balance_cents=balance_cents+?, updated_at=datetime('now') "
        "WHERE merchant_id=?",
        (topup["amount_cents"], topup["merchant_id"]),
    )
    await db.commit()

    async with db.execute(
        "SELECT balance_cents FROM merchant_wallets WHERE merchant_id=?",
        (topup["merchant_id"],),
    ) as cur:
        wallet = await cur.fetchone()

    return {"success": True, "new_balance_cents": wallet["balance_cents"] if wallet else 0}
