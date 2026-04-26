import httpx

EXPO_PUSH_URL = "https://exp.host/--/api/v2/push/send"


async def send_push(token: str | None, title: str, body: str, data: dict | None = None) -> bool:
    if not token:
        return False

    payload = {
        "to": token,
        "sound": "default",
        "title": title,
        "body": body,
        "data": data or {},
    }

    try:
        async with httpx.AsyncClient(timeout=8) as client:
            response = await client.post(EXPO_PUSH_URL, json=payload)
            response.raise_for_status()
        return True
    except Exception:
        return False

