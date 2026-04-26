from fastapi import APIRouter, HTTPException, Query
from database import get_db
from services.payone_simulator import get_shop_busyness, haversine_m

router = APIRouter(prefix="/api/shops", tags=["shops"])


@router.get("/map")
async def map_shops(
    lat: float = Query(...),
    lng: float = Query(...),
    radius: int = Query(600),
):
    """Return registered City Wallet shops for the consumer map."""
    db = await get_db()
    async with db.execute(
        "SELECT id, name, description, category, latitude, longitude, address FROM shops WHERE is_active=1"
    ) as cur:
        rows = await cur.fetchall()

    shops = []
    for row in rows:
        distance_m = round(haversine_m(lat, lng, row["latitude"], row["longitude"]))
        if distance_m > radius:
            continue

        busyness = await get_shop_busyness(row["id"])
        async with db.execute(
            "SELECT COUNT(*) AS count FROM coupons WHERE shop_id=? AND status='active' AND expires_at > datetime('now')",
            (row["id"],),
        ) as cur:
            count_row = await cur.fetchone()

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
                "active_coupon_count": count_row["count"] if count_row else 0,
                "busyness": busyness.get("busyness") or busyness.get("level", "normal"),
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
        "SELECT * FROM coupons WHERE shop_id=? AND status='active' AND expires_at > datetime('now') ORDER BY expires_at ASC",
        (shop_id,),
    ) as cur:
        coupons = await cur.fetchall()

    busyness = await get_shop_busyness(shop_id)
    return {
        "shop": dict(shop),
        "products": [dict(p) for p in products],
        "active_coupons": [dict(c) for c in coupons],
        "busyness": busyness,
    }
