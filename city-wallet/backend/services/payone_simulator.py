import math
import random
from datetime import datetime, timedelta
from database import get_db


def _typical_txn_for_hour(hour: int) -> int:
    """Simulated 'normal' transaction count for a given hour."""
    pattern = {
        0: 0, 1: 0, 2: 0, 3: 0, 4: 0, 5: 0, 6: 1, 7: 3,
        8: 6, 9: 8, 10: 10, 11: 14, 12: 20, 13: 18, 14: 8,
        15: 6, 16: 7, 17: 12, 18: 16, 19: 14, 20: 10, 21: 6,
        22: 3, 23: 1,
    }
    return pattern.get(hour, 5)


def _busyness_level(recent: int, typical: int) -> str:
    if typical == 0:
        return "quiet"
    ratio = recent / typical
    if ratio < 0.4:
        return "quiet"
    if ratio < 1.3:
        return "normal"
    return "busy"


async def get_shop_busyness(shop_id: int) -> dict:
    db = await get_db()
    cutoff = (datetime.utcnow() - timedelta(minutes=15)).isoformat()
    async with db.execute(
        "SELECT COALESCE(SUM(txn_count),0) as total FROM payone_density "
        "WHERE shop_id=? AND recorded_at>=?",
        (shop_id, cutoff),
    ) as cur:
        row = await cur.fetchone()
    recent = row["total"] if row else 0

    hour = datetime.now().hour
    typical = _typical_txn_for_hour(hour)
    level = _busyness_level(recent, typical)
    return {"txn_count_15min": recent, "typical": typical, "level": level}


async def update_density(shop_id: int) -> None:
    """Called by background task every 5 minutes to simulate Payone data."""
    hour = datetime.now().hour
    typical = _typical_txn_for_hour(hour)
    # Add some realistic noise
    count = max(0, int(typical * random.uniform(0.3, 1.4)))
    db = await get_db()
    await db.execute(
        "INSERT INTO payone_density (shop_id, txn_count) VALUES (?,?)",
        (shop_id, count),
    )
    # Keep only last 2 hours of rows
    cutoff = (datetime.utcnow() - timedelta(hours=2)).isoformat()
    await db.execute("DELETE FROM payone_density WHERE shop_id=? AND recorded_at<?", (shop_id, cutoff))
    await db.commit()


def haversine_m(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    R = 6371000
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp = math.radians(lat2 - lat1)
    dl = math.radians(lng2 - lng1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * R * math.asin(math.sqrt(a))
