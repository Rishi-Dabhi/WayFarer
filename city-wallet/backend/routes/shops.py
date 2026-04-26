from fastapi import APIRouter, HTTPException, Query, Depends
from pydantic import BaseModel
from database import get_db
from services.payone_simulator import get_shop_busyness, haversine_m
from middleware.auth import get_current_user

router = APIRouter(prefix="/api/shops", tags=["shops"])


class VisitPingIn(BaseModel):
    lat: float
    lng: float
    radius_m: int = 40


@router.post("/visit-ping")
async def visit_ping(body: VisitPingIn, user: dict = Depends(get_current_user)):
    """
    Record a store visit when an authenticated consumer walks into a shop radius.
    One visit is counted per user/shop/day to avoid inflation from frequent GPS updates.
    """
    if user.get("role") != "consumer":
        raise HTTPException(403, "Consumer access required")

    radius_m = max(10, min(body.radius_m, 150))
    db = await get_db()
    async with db.execute(
        "SELECT id, latitude, longitude FROM shops WHERE is_active=1"
    ) as cur:
        rows = await cur.fetchall()

    nearby_ids: list[int] = []
    for row in rows:
        distance_m = haversine_m(body.lat, body.lng, row["latitude"], row["longitude"])
        if distance_m <= radius_m:
            nearby_ids.append(row["id"])
            await db.execute(
                "INSERT OR IGNORE INTO shop_visits (shop_id, user_id) VALUES (?, ?)",
                (row["id"], int(user["sub"])),
            )

    await db.commit()
    return {"recorded_visits": len(nearby_ids), "nearby_shop_ids": nearby_ids}


@router.get("/map")
async def map_shops(
    lat: float = Query(...),
    lng: float = Query(...),
    radius: int = Query(600),
    user_id: int | None = Query(None),
):
    """Return registered WayFarer shops for the consumer map."""
    db = await get_db()
    async with db.execute(
        "SELECT id, name, description, category, latitude, longitude, address FROM shops WHERE is_active=1"
    ) as cur:
        rows = await cur.fetchall()

    shops = []
    for row in rows:
        distance_m = round(haversine_m(lat, lng, row["latitude"], row["longitude"]))
        has_user_offer = False
        if user_id is not None:
            async with db.execute(
                """SELECT id
                   FROM coupons
                   WHERE shop_id=? AND user_id=?
                     AND status='active' AND expires_at > datetime('now')
                   LIMIT 1""",
                (row["id"], user_id),
            ) as cur:
                has_user_offer = await cur.fetchone() is not None
        if distance_m > radius and not has_user_offer:
            continue

        busyness = await get_shop_busyness(row["id"])
        async with db.execute(
            "SELECT COUNT(*) AS count FROM coupons WHERE shop_id=? AND status='active' AND expires_at > datetime('now')",
            (row["id"],),
        ) as cur:
            count_row = await cur.fetchone()
        async with db.execute(
            """SELECT c.*, p.name AS product_name
               FROM coupons c
               LEFT JOIN products p ON c.product_id=p.id
               WHERE c.shop_id=? AND c.status='active' AND c.expires_at > datetime('now')
               ORDER BY c.expires_at ASC
               LIMIT 1""",
            (row["id"],),
        ) as cur:
            coupon_rows = await cur.fetchall()

        shops.append(
            {
                "id": row["id"],
                "_id": str(row["id"]),
                "name": row["name"],
                "description": row["description"],
                "category": row["category"],
                "lat": row["latitude"],
                "lng": row["longitude"],
                "address": row["address"],
                "distance_m": distance_m,
                "active_coupon_count": min(count_row["count"] if count_row else 0, 1),
                "active_coupons": [dict(coupon) for coupon in coupon_rows],
                "busyness": busyness.get("level", "normal"),
                "txn_count_15min": busyness["txn_count_15min"],
            }
        )

    shops.sort(key=lambda s: (s["distance_m"], -s["active_coupon_count"]))
    return shops


@router.get("/{shop_id}")
async def shop_detail(shop_id: int):
    db = await get_db()
    async with db.execute("SELECT * FROM shops WHERE id=?", (shop_id,)) as cur:
        shop = await cur.fetchone()
    if not shop:
        raise HTTPException(404, "Shop not found")

    async with db.execute(
        "SELECT * FROM products WHERE shop_id=? AND is_active=1 ORDER BY name",
        (shop_id,),
    ) as cur:
        products = await cur.fetchall()

    async with db.execute(
        """SELECT c.*, p.name AS product_name
           FROM coupons c
           LEFT JOIN products p ON c.product_id=p.id
           WHERE c.shop_id=? AND c.status='active' AND c.expires_at > datetime('now')
           ORDER BY c.expires_at ASC
           LIMIT 1""",
        (shop_id,),
    ) as cur:
        coupons = await cur.fetchall()

    busyness = await get_shop_busyness(shop_id)
    return {
        "shop": dict(shop),
        "products": [dict(p) for p in products],
        "active_coupons": [dict(c) for c in coupons],
        "active_coupon_count": min(len(coupons), 1),
        "busyness": busyness,
    }
