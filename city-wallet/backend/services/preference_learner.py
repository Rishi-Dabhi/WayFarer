import json
from database import get_db


async def update_after_redemption(user_id: int, shop_category: str) -> None:
    db = await get_db()
    async with db.execute(
        "SELECT category_affinity, active_hours FROM user_preferences WHERE user_id=?",
        (user_id,),
    ) as cur:
        row = await cur.fetchone()

    if not row:
        affinity = {}
        hours = []
    else:
        affinity = json.loads(row["category_affinity"] or "{}")
        hours = json.loads(row["active_hours"] or "[]")

    # Bump category weight by 0.1, cap at 1.0
    current = affinity.get(shop_category, 0.5)
    affinity[shop_category] = min(1.0, round(current + 0.1, 2))

    # Decay all other categories slightly
    for k in list(affinity.keys()):
        if k != shop_category:
            affinity[k] = max(0.0, round(affinity[k] - 0.02, 2))

    await db.execute(
        """INSERT INTO user_preferences (user_id, category_affinity, active_hours)
           VALUES (?,?,?)
           ON CONFLICT(user_id) DO UPDATE SET
             category_affinity=excluded.category_affinity,
             last_updated=datetime('now')""",
        (user_id, json.dumps(affinity), json.dumps(hours)),
    )
    await db.commit()


async def get_preferences(user_id: int) -> dict:
    db = await get_db()
    async with db.execute(
        "SELECT * FROM user_preferences WHERE user_id=?", (user_id,)
    ) as cur:
        row = await cur.fetchone()
    if not row:
        return {"category_affinity": {}, "preferred_discount_range": {"min": 10, "max": 25}, "active_hours": []}
    return {
        "category_affinity": json.loads(row["category_affinity"] or "{}"),
        "preferred_discount_range": json.loads(row["preferred_discount_range"] or '{"min":10,"max":25}'),
        "active_hours": json.loads(row["active_hours"] or "[]"),
    }
