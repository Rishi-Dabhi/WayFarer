"""
Local events service — Eventbrite Discovery API.

Get a private token at https://www.eventbrite.com/platform/api
Set EVENTBRITE_TOKEN in .env.

Returns an empty list when no token is configured. Raises on API errors
so failures are visible rather than silently returning stale or fake data.
"""

import httpx
import math
import time
from datetime import datetime, timezone

from config import settings

_CACHE: dict = {}
_CACHE_TTL = 1800  # 30 minutes

_EVENTBRITE_URL = "https://www.eventbriteapi.com/v3/events/search/"


def _haversine(lat1: float, lng1: float, lat2: float, lng2: float) -> float:
    R = 6_371_000
    p1, p2 = math.radians(lat1), math.radians(lat2)
    dp = math.radians(lat2 - lat1)
    dl = math.radians(lng2 - lng1)
    a = math.sin(dp / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(dl / 2) ** 2
    return 2 * R * math.asin(math.sqrt(a))


async def _eventbrite_events(lat: float, lng: float, radius_m: float) -> list[dict]:
    radius_km = max(1, round(radius_m / 1000))
    params = {
        "location.latitude": str(lat),
        "location.longitude": str(lng),
        "location.within": f"{radius_km}km",
        "expand": "venue",
        "sort_by": "date",
    }
    headers = {"Authorization": f"Bearer {settings.eventbrite_token}"}

    async with httpx.AsyncClient(timeout=8) as client:
        r = await client.get(_EVENTBRITE_URL, params=params, headers=headers)
        r.raise_for_status()
        data = r.json()

    raw_events = data.get("events", [])
    results = []
    for ev in raw_events:
        name = ev.get("name", {}).get("text") or ev.get("name", {}).get("html") or "Event"
        venue = ev.get("venue") or {}
        venue_lat = float(venue.get("latitude") or lat)
        venue_lng = float(venue.get("longitude") or lng)
        dist = round(_haversine(lat, lng, venue_lat, venue_lng))
        date_str = ev.get("start", {}).get("local", "")
        results.append({"name": name, "distance_m": dist, "date": date_str})

    return results[:3]


async def get_nearby_events(lat: float, lng: float, radius_m: float = 1000) -> list[dict]:
    if not settings.eventbrite_token:
        return []

    key = f"{round(lat, 2)},{round(lng, 2)},{int(radius_m)}"
    now = time.time()
    if key in _CACHE and now - _CACHE[key]["ts"] < _CACHE_TTL:
        return _CACHE[key]["data"]

    results = await _eventbrite_events(lat, lng, radius_m)
    _CACHE[key] = {"ts": now, "data": results}
    return results
