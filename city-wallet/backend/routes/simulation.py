from datetime import datetime, timedelta

from fastapi import APIRouter, Query

from database import get_db
from services.payone_simulator import haversine_m

router = APIRouter(prefix="/api/simulation", tags=["simulation"])


@router.get("/map-users")
async def map_users(
    lat: float = Query(...),
    lng: float = Query(...),
    radius: int = Query(1200, ge=50, le=20000),
    limit: int = Query(500, ge=1, le=5000),
    max_age_minutes: int = Query(30, ge=1, le=24 * 60),
):
    """
    Return synthetic consumer positions near the current map viewport.

    This is intended for demos and load visualisation only; these are not real
    consumer locations.
    """
    db = await get_db()
    cutoff = (datetime.utcnow() - timedelta(minutes=max_age_minutes)).isoformat()
    async with db.execute(
        """
        SELECT s.user_id, s.latitude, s.longitude, s.movement_state, s.anchor_shop_id,
               s.last_seen_at, u.name, sh.name AS anchor_shop_name
        FROM simulated_user_locations s
        JOIN users u ON u.id=s.user_id
        LEFT JOIN shops sh ON sh.id=s.anchor_shop_id
        WHERE s.is_active=1 AND s.last_seen_at>=?
        ORDER BY s.last_seen_at DESC
        LIMIT ?
        """,
        (cutoff, limit * 4),
    ) as cur:
        rows = await cur.fetchall()

    users = []
    movement_counts = {"static": 0, "walking": 0, "moving_fast": 0}
    for row in rows:
        distance_m = round(haversine_m(lat, lng, row["latitude"], row["longitude"]))
        if distance_m > radius:
            continue
        movement = row["movement_state"] or "walking"
        movement_counts[movement] = movement_counts.get(movement, 0) + 1
        users.append(
            {
                "user_id": row["user_id"],
                "name": row["name"],
                "lat": row["latitude"],
                "lng": row["longitude"],
                "distance_m": distance_m,
                "movement_state": movement,
                "anchor_shop_id": row["anchor_shop_id"],
                "anchor_shop_name": row["anchor_shop_name"],
                "last_seen_at": row["last_seen_at"],
            }
        )
        if len(users) >= limit:
            break

    users.sort(key=lambda user: user["distance_m"])
    return {
        "count": len(users),
        "movement_counts": movement_counts,
        "users": users,
    }
