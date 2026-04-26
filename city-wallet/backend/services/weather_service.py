import httpx
import time
from config import settings

_cache: dict = {}
_CACHE_TTL = 600  # 10 minutes


async def get_weather(lat: float, lng: float) -> dict:
    key = f"{round(lat,2)},{round(lng,2)}"
    now = time.time()
    if key in _cache and now - _cache[key]["ts"] < _CACHE_TTL:
        return _cache[key]["data"]

    if not settings.openweather_api_key:
        return {"temp": 14, "feels_like": 11, "condition": "overcast clouds", "icon": "04d"}

    url = "https://api.openweathermap.org/data/2.5/weather"
    params = {"lat": lat, "lon": lng, "appid": settings.openweather_api_key, "units": "metric"}
    async with httpx.AsyncClient(timeout=5) as client:
        r = await client.get(url, params=params)
        r.raise_for_status()
        data = r.json()

    result = {
        "temp": round(data["main"]["temp"]),
        "feels_like": round(data["main"]["feels_like"]),
        "condition": data["weather"][0]["description"],
        "icon": data["weather"][0]["icon"],
    }
    _cache[key] = {"ts": now, "data": result}
    return result
