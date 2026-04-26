from datetime import datetime
from database import get_db
from services.weather_service import get_weather
from services.event_service import get_nearby_events
from services.osm_service import get_venue_density
from services.payone_simulator import get_shop_busyness, haversine_m


def _time_context() -> dict:
    now = datetime.now()
    h = now.hour
    if h < 6:
        period = "night"
    elif h < 11:
        period = "morning"
    elif h < 14:
        period = "lunch"
    elif h < 17:
        period = "afternoon"
    elif h < 20:
        period = "evening"
    else:
        period = "night"
    return {
        "hour": h,
        "period": period,
        "day_of_week": now.strftime("%A"),
    }


async def get_signals(
    lat: float,
    lng: float,
    radius_m: float = 600,
    demo_override: dict | None = None,
) -> dict:
    time_ctx = _time_context()

    if demo_override:
        weather = demo_override.get("weather", await get_weather(lat, lng))
        events = demo_override.get("events", await get_nearby_events(lat, lng, radius_m))
    else:
        weather, events = await _fetch_weather_and_events(lat, lng, radius_m)

    # OSM venue density — always real regardless of demo override (it's context, not an override)
    osm_density = await get_venue_density(lat, lng, radius_m)

    db = await get_db()
    async with db.execute(
        "SELECT id, name, category, latitude, longitude FROM shops WHERE is_active=1"
    ) as cur:
        all_shops = await cur.fetchall()

    nearby_shops = []
    for shop in all_shops:
        dist = haversine_m(lat, lng, shop["latitude"], shop["longitude"])
        if dist <= radius_m:
            if demo_override and "busyness_override" in demo_override:
                busyness = {
                    "txn_count_15min": demo_override.get("payone_txn_override", 3),
                    "typical": 12,
                    "level": demo_override["busyness_override"],
                }
            else:
                busyness = await get_shop_busyness(shop["id"])
            nearby_shops.append({
                "shop_id": shop["id"],
                "name": shop["name"],
                "category": shop["category"],
                "distance_m": round(dist),
                "busyness": busyness["level"],
                "txn_count_15min": busyness["txn_count_15min"],
                "typical_txn": busyness["typical"],
            })

    nearby_shops.sort(key=lambda s: s["distance_m"])

    return {
        "weather": weather,
        "time": time_ctx,
        "nearby_shops": nearby_shops,        # registered City Wallet merchants
        "local_events": events,              # Eventbrite / stub
        "osm_density": osm_density,          # real OSM venue count + closest venues
    }


async def _fetch_weather_and_events(lat: float, lng: float, radius_m: float):
    import asyncio
    weather, events = await asyncio.gather(
        get_weather(lat, lng),
        get_nearby_events(lat, lng, radius_m),
    )
    return weather, events


async def best_shop_for_offer(signals: dict) -> dict | None:
    """Pick the best registered shop to generate an offer for."""
    db = await get_db()
    candidates = [s for s in signals["nearby_shops"] if s["busyness"] != "busy"]
    if not candidates:
        candidates = signals["nearby_shops"]
    if not candidates:
        return None

    best = candidates[0]
    async with db.execute(
        "SELECT s.*, u.name as merchant_name FROM shops s JOIN users u ON s.merchant_id=u.id WHERE s.id=?",
        (best["shop_id"],),
    ) as cur:
        shop_row = await cur.fetchone()

    if not shop_row:
        return None

    async with db.execute(
        "SELECT * FROM products WHERE shop_id=? AND is_active=1 LIMIT 6",
        (best["shop_id"],),
    ) as cur:
        products = await cur.fetchall()

    return {
        "shop": dict(shop_row),
        "products": [dict(p) for p in products],
        "distance_m": best["distance_m"],
        "busyness": best,
    }
