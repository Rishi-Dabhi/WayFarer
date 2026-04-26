"""
OpenStreetMap Overpass API wrapper.

Used for two purposes:
  1. Enriching context signals with a real venue density count (how many
     cafés/shops are physically nearby — regardless of whether they're
     registered in City Wallet).
  2. The seed_from_osm.py script queries this to auto-register real local
     shops before a demo.

No API key required — Overpass is fully free and open.
"""

import httpx
import time
import math

_CACHE: dict = {}
_CACHE_TTL = 900  # 15 minutes — POIs don't move

OVERPASS_URLS = [
    "https://overpass-api.de/api/interpreter",
    "https://overpass.osm.ch/api/interpreter",
    "https://overpass.openstreetmap.ru/api/interpreter",
]

# OSM amenity/shop tags we care about, mapped to our internal category names
_AMENITY_CATEGORY: dict[str, str] = {
    "cafe": "cafe",
    "restaurant": "restaurant",
    "bar": "bar",
    "pub": "bar",
    "fast_food": "restaurant",
    "ice_cream": "cafe",
    "bakery": "cafe",
    "food_court": "restaurant",
}
_SHOP_CATEGORY: dict[str, str] = {
    "bakery": "cafe",
    "deli": "restaurant",
    "convenience": "retail",
    "supermarket": "retail",
    "clothes": "retail",
    "books": "retail",
    "gift": "retail",
    "florist": "retail",
    "jewellery": "retail",
    "optician": "retail",
    "shoes": "retail",
    "sports": "retail",
    "stationery": "retail",
}

_AMENITY_FILTER = "|".join(_AMENITY_CATEGORY.keys())
_SHOP_FILTER = "|".join(_SHOP_CATEGORY.keys())


def _build_query(lat: float, lng: float, radius_m: float) -> str:
    return f"""
[out:json][timeout:15];
(
  nwr["amenity"~"^({_AMENITY_FILTER})$"]["name"](around:{int(radius_m)},{lat},{lng});
  nwr["shop"~"^({_SHOP_FILTER})$"]["name"](around:{int(radius_m)},{lat},{lng});
);
out center;
""".strip()


def _haversine(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    R = 6_371_000
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp = math.radians(lat2 - lat1)
    dl = math.radians(lng2 - lng1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * R * math.asin(math.sqrt(a))


def _osm_to_poi(element: dict, user_lat: float, user_lng: float) -> dict:
    tags = element.get("tags", {})
    center = element.get("center", {})
    lat = element.get("lat", center.get("lat", 0.0))
    lng = element.get("lon", center.get("lon", 0.0))
    amenity = tags.get("amenity", "")
    shop = tags.get("shop", "")
    category = _AMENITY_CATEGORY.get(amenity) or _SHOP_CATEGORY.get(shop, "retail")
    return {
        "osm_id": element.get("id"),
        "name": tags.get("name", "Unnamed"),
        "category": category,
        "lat": lat,
        "lng": lng,
        "address": tags.get("addr:street", "") + " " + tags.get("addr:housenumber", ""),
        "opening_hours": tags.get("opening_hours", ""),
        "distance_m": round(_haversine(user_lat, user_lng, lat, lng)),
    }


async def get_nearby_pois(lat: float, lng: float, radius_m: float = 600) -> list[dict]:
    """Return real nearby venues from OSM, sorted by distance."""
    key = f"{round(lat, 3)},{round(lng, 3)},{int(radius_m)}"
    now = time.time()
    if key in _CACHE and now - _CACHE[key]["ts"] < _CACHE_TTL:
        return _CACHE[key]["data"]

    query = _build_query(lat, lng, radius_m)
    elements = []
    last_error = None
    async with httpx.AsyncClient(timeout=20) as client:
        for url in OVERPASS_URLS:
            try:
                r = await client.post(url, data={"data": query})
                r.raise_for_status()
                elements = r.json().get("elements", [])
                if elements:
                    break
            except Exception as exc:
                last_error = exc

    if not elements and last_error:
        print(f"OSM Overpass warning: {last_error}")

    pois = [
        _osm_to_poi(e, lat, lng)
        for e in elements
        if e.get("tags", {}).get("name")  # skip unnamed nodes
    ]
    pois.sort(key=lambda p: p["distance_m"])

    _CACHE[key] = {"ts": now, "data": pois}
    return pois


async def get_venue_density(lat: float, lng: float, radius_m: float = 600) -> dict:
    """Summarise nearby venue counts by category — used as a context signal."""
    pois = await get_nearby_pois(lat, lng, radius_m)
    counts: dict[str, int] = {}
    for p in pois:
        counts[p["category"]] = counts.get(p["category"], 0) + 1
    return {
        "total": len(pois),
        "by_category": counts,
        "closest": pois[:3],  # top 3 for UI display
    }
