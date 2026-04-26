import json
from database import get_db


async def update_after_redemption(
    user_id: int,
    shop_category: str,
    product_id: int | None = None,
    product_category: str | None = None,
    amount_cents: int = 0,
    cashback_cents: int = 0,
    discount_pct: int = 0,
    hour: int | None = None,
) -> None:
    db = await get_db()
    async with db.execute(
        "SELECT category_affinity, preferred_discount_range, active_hours, "
        "product_affinity, avg_spend_cents, purchase_count "
        "FROM user_preferences WHERE user_id=?",
        (user_id,),
    ) as cur:
        row = await cur.fetchone()

    if not row:
        affinity = {}
        discount_range = {"min": 10, "max": 25}
        hours: list[int] = []
        product_affinity = {}
        avg_spend = 0
        purchase_count = 0
    else:
        affinity = json.loads(row["category_affinity"] or "{}")
        discount_range = json.loads(row["preferred_discount_range"] or '{"min":10,"max":25}')
        hours = json.loads(row["active_hours"] or "[]")
        product_affinity = json.loads(row["product_affinity"] or "{}")
        avg_spend = row["avg_spend_cents"] or 0
        purchase_count = row["purchase_count"] or 0

    # Category affinity: bump redeemed category, decay others
    for cat in (c for c in [shop_category, product_category] if c):
        current = affinity.get(cat, 0.5)
        affinity[cat] = min(1.0, round(current + 0.1, 2))
    for k in list(affinity.keys()):
        if k not in (shop_category, product_category):
            affinity[k] = max(0.0, round(affinity[k] - 0.02, 2))

    # Product affinity: bump redeemed product, decay others
    if product_id is not None:
        key = str(product_id)
        current = product_affinity.get(key, 0.3)
        product_affinity[key] = min(1.0, round(current + 0.15, 2))
        for k in list(product_affinity.keys()):
            if k != key:
                product_affinity[k] = max(0.0, round(product_affinity[k] - 0.02, 2))

    # Active hours: track which hours the user redeems
    if hour is not None and hour not in hours:
        hours.append(hour)
    hours = sorted(set(hours))

    # Preferred discount range: drift toward seen discounts
    if discount_pct > 0:
        d_min = discount_range.get("min", 10)
        d_max = discount_range.get("max", 25)
        discount_range["min"] = round(d_min * 0.85 + discount_pct * 0.15, 1)
        discount_range["max"] = round(d_max * 0.85 + discount_pct * 0.15, 1)

    # Running average spend
    if amount_cents > 0:
        purchase_count += 1
        avg_spend = round((avg_spend * (purchase_count - 1) + amount_cents) / purchase_count)

    await db.execute(
        """INSERT INTO user_preferences
           (user_id, category_affinity, preferred_discount_range, active_hours,
            product_affinity, avg_spend_cents, purchase_count)
           VALUES (?,?,?,?,?,?,?)
           ON CONFLICT(user_id) DO UPDATE SET
             category_affinity=excluded.category_affinity,
             preferred_discount_range=excluded.preferred_discount_range,
             active_hours=excluded.active_hours,
             product_affinity=excluded.product_affinity,
             avg_spend_cents=excluded.avg_spend_cents,
             purchase_count=excluded.purchase_count,
             last_updated=datetime('now')""",
        (
            user_id,
            json.dumps(affinity),
            json.dumps(discount_range),
            json.dumps(hours),
            json.dumps(product_affinity),
            avg_spend,
            purchase_count,
        ),
    )
    await db.commit()


async def get_preferences(user_id: int) -> dict:
    db = await get_db()
    async with db.execute(
        "SELECT * FROM user_preferences WHERE user_id=?", (user_id,)
    ) as cur:
        row = await cur.fetchone()
    if not row:
        return {
            "category_affinity": {},
            "preferred_discount_range": {"min": 10, "max": 25},
            "active_hours": [],
            "product_affinity": {},
            "avg_spend_cents": 0,
            "purchase_count": 0,
        }
    return {
        "category_affinity": json.loads(row["category_affinity"] or "{}"),
        "preferred_discount_range": json.loads(row["preferred_discount_range"] or '{"min":10,"max":25}'),
        "active_hours": json.loads(row["active_hours"] or "[]"),
        "product_affinity": json.loads(row["product_affinity"] or "{}"),
        "avg_spend_cents": row["avg_spend_cents"] or 0,
        "purchase_count": row["purchase_count"] or 0,
    }
