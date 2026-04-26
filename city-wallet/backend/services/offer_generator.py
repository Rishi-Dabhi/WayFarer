import json
import anthropic
from config import settings

SYSTEM_PROMPT = """You are the offer engine for City Wallet, a hyper-local AI wallet for inner-city merchants.
You generate ONE specific, emotionally resonant offer for a real person in a real moment.
This is not a coupon template. The offer must feel like it was written for this exact person,
at this exact location, at this exact second.

Rules:
- The headline must be understood in 3 seconds. Max 8 words. No jargon.
- The body_text must feel human and warm. 2-3 sentences. Reference the weather or time naturally.
- The discount must be within the merchant's stated maximum.
- The why_now must explain in one sentence exactly which context signals triggered this offer.
  Mention the Payone transaction data specifically (e.g. "unusually quiet with only X transactions in 15 min").
- Return valid JSON only. No preamble, no markdown, no explanation."""


def _build_prompt(shop: dict, products: list[dict], signals: dict, prefs: dict, distance_m: int, busyness: dict) -> str:
    product_lines = "\n".join(
        f"- {p['name']}: €{p['price_cents']/100:.2f} (stock: {p['stock_level']})"
        for p in products[:5]
    ) or "- General menu items"

    top_cats = sorted(prefs.get("category_affinity", {}).items(), key=lambda x: -x[1])
    top_cats_str = ", ".join(c for c, _ in top_cats[:3]) or "general"

    import json as _json
    quiet_hours = _json.loads(shop.get("target_quiet_hours") or "[]")

    return f"""Generate one offer for this exact moment:

SHOP: {shop['name']} ({shop['category']}) — {shop.get('description', 'Local shop')}
ADDRESS: {shop.get('address', 'City centre')}
MERCHANT GOAL: {shop.get('campaign_goal', 'fill_quiet_hours')} | MAX DISCOUNT: {shop['max_discount_pct']}%
TARGET QUIET HOURS: {', '.join(quiet_hours) or 'any time'}
MAX CASHBACK BUDGET: €{shop['cashback_budget_per_coupon_cents']/100:.2f} per redemption

CONTEXT RIGHT NOW:
- Weather: {signals['weather']['temp']}°C, {signals['weather']['condition']} \
(feels like {signals['weather']['feels_like']}°C)
- Time: {signals['time']['period']} on {signals['time']['day_of_week']} ({signals['time']['hour']}:00)
- Shop is {busyness['level']} right now
  (Payone data: {busyness['txn_count_15min']} transactions in last 15 min, \
typical for this hour: {busyness['typical']})
- Distance from user: {distance_m}m
- Nearby events: {', '.join(e['name'] for e in signals.get('local_events', [])) or 'none'}

AVAILABLE PRODUCTS:
{product_lines}

USER PROFILE:
- Responds well to: {top_cats_str}
- Preferred discount range: {prefs.get('preferred_discount_range', {}).get('min', 10)}–{prefs.get('preferred_discount_range', {}).get('max', 25)}%

Return JSON in this exact shape:
{{
  "headline": "string (max 8 words, punchy, present-tense)",
  "body_text": "string (2-3 sentences, emotionally resonant, references context naturally)",
  "discount_pct": number (integer, within merchant max),
  "cashback_cents": number (integer, discount applied to cheapest relevant product, max {shop['cashback_budget_per_coupon_cents']}),
  "product_name": "string or null",
  "why_now": "string (1 sentence referencing Payone data and weather/time)",
  "expires_minutes": number,
  "tone": "warm | urgent | playful | calm"
}}"""


async def generate_offer_stream(
    shop: dict,
    products: list[dict],
    signals: dict,
    prefs: dict,
    distance_m: int,
    busyness: dict,
):
    """
    Async generator yielding SSE-formatted strings.
    Yields context, thinking, streamed tokens, then the parsed offer.
    """
    client = anthropic.AsyncAnthropic(api_key=settings.anthropic_api_key)
    prompt = _build_prompt(shop, products, signals, prefs, distance_m, busyness)

    yield f"data: {json.dumps({'type': 'thinking', 'payload': {'message': 'Analysing your context...'}})}\n\n"

    full_text = ""
    async with client.messages.stream(
        model="claude-sonnet-4-6",
        max_tokens=450,
        system=[
            {
                "type": "text",
                "text": SYSTEM_PROMPT,
                "cache_control": {"type": "ephemeral"},
            }
        ],
        messages=[{"role": "user", "content": prompt}],
    ) as stream:
        async for text in stream.text_stream:
            full_text += text
            yield f"data: {json.dumps({'type': 'token', 'payload': {'text': text}})}\n\n"

    # Parse and store
    try:
        offer_data = json.loads(full_text.strip())
    except json.JSONDecodeError:
        import re
        m = re.search(r"\{.*\}", full_text, re.DOTALL)
        offer_data = json.loads(m.group()) if m else {}

    yield f"data: {json.dumps({'type': 'offer_data', 'payload': offer_data})}\n\n"
    yield f"data: {json.dumps({'type': 'done'})}\n\n"
