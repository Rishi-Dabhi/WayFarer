from fastapi import APIRouter, Depends
from database import get_db
from middleware.auth import require_merchant
import json

router = APIRouter(prefix="/api/analytics", tags=["analytics"])


@router.get("/merchant/{shop_id}")
async def merchant_analytics(shop_id: int, merchant: dict = Depends(require_merchant)):
    db = await get_db()

    async with db.execute(
        "SELECT COUNT(*) as total FROM coupons WHERE shop_id=? AND date(generated_at)=date('now')",
        (shop_id,),
    ) as cur:
        gen_today = (await cur.fetchone())["total"]

    async with db.execute(
        "SELECT COUNT(*) as total FROM coupons WHERE shop_id=? AND status='redeemed' AND date(redeemed_at)=date('now')",
        (shop_id,),
    ) as cur:
        red_today = (await cur.fetchone())["total"]

    async with db.execute(
        "SELECT COUNT(*) as total FROM coupons WHERE shop_id=?",
        (shop_id,),
    ) as cur:
        gen_all = (await cur.fetchone())["total"]

    async with db.execute(
        "SELECT COUNT(*) as total FROM coupons WHERE shop_id=? AND status='redeemed'",
        (shop_id,),
    ) as cur:
        red_all = (await cur.fetchone())["total"]

    redemption_rate = round(red_all / gen_all * 100, 1) if gen_all > 0 else 0

    async with db.execute(
        "SELECT COALESCE(AVG(discount_pct),0) as avg FROM coupons WHERE shop_id=? AND status='redeemed'",
        (shop_id,),
    ) as cur:
        avg_discount = round((await cur.fetchone())["avg"], 1)

    async with db.execute(
        "SELECT COALESCE(SUM(cashback_cents),0) as total FROM transactions WHERE shop_id=? AND date(redeemed_at)=date('now')",
        (shop_id,),
    ) as cur:
        wallet_spent_today = (await cur.fetchone())["total"]

    async with db.execute(
        "SELECT COALESCE(SUM(cashback_cents),0) as total FROM transactions WHERE shop_id=?",
        (shop_id,),
    ) as cur:
        wallet_spent_total = (await cur.fetchone())["total"]

    # Coupons by hour (last 24h)
    async with db.execute(
        "SELECT strftime('%H',generated_at) as hour, COUNT(*) as count "
        "FROM coupons WHERE shop_id=? AND generated_at>=datetime('now','-1 day') "
        "GROUP BY hour ORDER BY hour",
        (shop_id,),
    ) as cur:
        by_hour = [{"hour": int(r["hour"]), "count": r["count"]} for r in await cur.fetchall()]

    # Top products
    async with db.execute(
        "SELECT p.name, COUNT(*) as redemptions "
        "FROM coupons c JOIN products p ON c.product_id=p.id "
        "WHERE c.shop_id=? AND c.status='redeemed' "
        "GROUP BY p.id ORDER BY redemptions DESC LIMIT 5",
        (shop_id,),
    ) as cur:
        top_products = [dict(r) for r in await cur.fetchall()]

    # Recent redemptions
    async with db.execute(
        "SELECT c.headline, c.cashback_cents, c.redeemed_at, c.discount_pct "
        "FROM coupons c WHERE c.shop_id=? AND c.status='redeemed' "
        "ORDER BY c.redeemed_at DESC LIMIT 8",
        (shop_id,),
    ) as cur:
        recent = [dict(r) for r in await cur.fetchall()]

    return {
        "coupons_generated_today": gen_today,
        "redemptions_today": red_today,
        "coupons_generated_total": gen_all,
        "redemptions_total": red_all,
        "redemption_rate_pct": redemption_rate,
        "avg_discount_pct": avg_discount,
        "wallet_spent_today_cents": wallet_spent_today,
        "wallet_spent_total_cents": wallet_spent_total,
        "coupons_by_hour": by_hour,
        "top_products": top_products,
        "recent_redemptions": recent,
    }
