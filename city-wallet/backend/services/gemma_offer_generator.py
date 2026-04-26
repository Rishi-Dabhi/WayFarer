import json
import re
from difflib import SequenceMatcher

import httpx

from config import settings


def _context_fit_score(context: dict) -> float:
    reasons = context.get("reasons") or []
    if not reasons:
        return 0.0
    score = 0.0
    for reason in reasons:
        if "lunch" in reason:
            score += 0.35
        elif "cold-weather" in reason or "shelter" in reason:
            score += 0.30
        elif "morning" in reason or "evening" in reason:
            score += 0.25
        else:
            score += 0.15
    return min(score, 1.0)


def _weighted_discount_pct(
    shop: dict,
    product: dict,
    distance_m: int,
    ratio: float,
    threshold: float,
    context: dict,
) -> int:
    max_discount = max(5, int(shop["max_discount_pct"] or 20))
    min_discount = min(5, max_discount)
    threshold = max(threshold, 0.1)

    quiet_pressure = max(0.0, min(1.0, (threshold - ratio) / threshold))
    if ratio > threshold:
        quiet_pressure = max(0.0, min(0.35, 1 - ratio))

    context_fit = _context_fit_score(context)
    urgency = context.get("urgency") or "normal"
    urgency_score = 1.0 if urgency == "high" else 0.55 if urgency == "fallback" else 0.35
    distance_score = 1 / (1 + (distance_m / 800))

    stock = (product.get("stock_level") or "normal").lower()
    stock_pressure = 0.25 if stock == "high" else -0.15 if stock == "low" else 0.0

    price_cents = max(int(product.get("price_cents") or 0), 1)
    cashback_budget = int(shop.get("cashback_budget_per_coupon_cents") or 0)
    budget_discount_cap = max(1, round(cashback_budget / price_cents * 100)) if cashback_budget else max_discount
    effective_max = max(min_discount, min(max_discount, budget_discount_cap))

    weighted = (
        0.40 * quiet_pressure
        + 0.25 * context_fit
        + 0.15 * urgency_score
        + 0.10 * distance_score
        + 0.10 * max(0.0, stock_pressure)
    )
    if stock_pressure < 0:
        weighted += stock_pressure

    discount = min_discount + weighted * (effective_max - min_discount)
    return max(min_discount, min(effective_max, round(discount)))


def _situation(
    shop: dict,
    product: dict,
    distance_m: int,
    ratio: float,
    threshold: float,
    context: dict,
) -> dict:
    weather = context.get("weather") or {}
    time_ctx = context.get("time") or {}
    reasons = context.get("reasons") or []
    period = time_ctx.get("period") or "now"
    temp = weather.get("feels_like", weather.get("temp"))
    condition = (weather.get("condition") or "").lower()
    product_text = f"{product['name']} {product.get('category') or ''}".lower()
    max_discount = shop["max_discount_pct"] or 20
    weighted_discount = _weighted_discount_pct(shop, product, distance_m, ratio, threshold, context)

    urgency = context.get("urgency") or "normal"
    if ratio <= threshold * 0.5:
        urgency = "high"
    elif distance_m > 1200:
        urgency = "fallback"

    discount = weighted_discount
    expires = 60
    tone = "warm"
    angle = "nearby"

    if urgency == "high":
        discount += 2
        expires = 30
        tone = "urgent"
        angle = "quiet-time"
    elif urgency == "fallback":
        discount += 1
        expires = 60
        tone = "calm"
        angle = "worth-the-walk"
    else:
        expires = 45

    if period == "lunch":
        angle = "lunch"
        discount += 1
    elif period == "morning":
        angle = "morning"
    elif period == "afternoon":
        angle = "afternoon"
    elif period == "evening":
        angle = "evening"

    if isinstance(temp, (int, float)) and temp <= 10:
        if "coffee" in product_text or "tea" in product_text or shop["category"] == "cafe":
            angle = "warm-up"
            discount += 1
    elif isinstance(temp, (int, float)) and temp >= 22:
        if any(term in product_text for term in ("cold", "iced", "drink", "salad", "ice")):
            angle = "cool-down"
            discount += 1

    if any(term in condition for term in ("rain", "drizzle", "snow", "wind")):
        angle = "shelter"
        expires = min(expires, 45)

    if "cold-weather fit" in reasons:
        angle = "warm-up"
    elif "lunch fit" in reasons:
        angle = "lunch"

    stable_variation = ((int(shop["id"]) * 3 + int(product["id"]) + int(distance_m // 100)) % 5) - 2
    if urgency == "high":
        stable_variation = max(0, stable_variation)
    discount += stable_variation

    return {
        "angle": angle,
        "discount_pct": max(5, min(discount, max_discount)),
        "expires_minutes": expires,
        "tone": tone,
    }


def _fallback_offer(
    shop: dict,
    product: dict,
    distance_m: int,
    busyness: dict,
    ratio: float,
    threshold: float,
    context: dict | None = None,
) -> dict:
    discount_pct = min(shop["max_discount_pct"] or 15, 20)
    cashback_cents = min(
        round(product["price_cents"] * discount_pct / 100),
        shop["cashback_budget_per_coupon_cents"] or 300,
    )
    context = context or {}
    situation = _situation(shop, product, distance_m, ratio, threshold, context)
    time_period = context.get("time", {}).get("period")
    weather = context.get("weather") or {}
    reasons = context.get("reasons") or []
    weather_phrase = ""
    if weather.get("condition"):
        weather_phrase = f" with {weather['condition']} outside"
    moment = f" during {time_period}" if time_period else " right now"
    angle = situation["angle"]
    headline_by_angle = {
        "warm-up": f"Warm up at {shop['name']}",
        "lunch": f"Lunch nearby at {shop['name']}",
        "morning": f"Morning stop at {shop['name']}",
        "afternoon": f"Afternoon lift at {shop['name']}",
        "evening": f"Evening offer at {shop['name']}",
        "shelter": f"Shelter stop at {shop['name']}",
        "quiet-time": f"Quiet-time reward at {shop['name']}",
        "worth-the-walk": f"Worth the walk: {shop['name']}",
    }
    headline = headline_by_angle.get(angle, f"{shop['name']} nearby reward")
    discount_pct = situation["discount_pct"]
    cashback_cents = min(
        round(product["price_cents"] * discount_pct / 100),
        shop["cashback_budget_per_coupon_cents"] or 300,
    )
    reason_text = ", ".join(reasons) if reasons else "local context"
    return {
        "headline": headline,
        "body_text": (
            f"{product['name']} fits the moment{moment}{weather_phrase}. "
            f"You are {distance_m}m away, and this offer is ready now."
        ),
        "why_now": (
            f"Created because live activity is at {ratio:.0%} of typical demand, "
            f"with {reason_text} considered."
        ),
        "discount_pct": discount_pct,
        "cashback_cents": cashback_cents,
        "expires_minutes": situation["expires_minutes"],
        "tone": situation["tone"],
    }


def _prompt(
    shop: dict,
    product: dict,
    distance_m: int,
    busyness: dict,
    ratio: float,
    threshold: float,
    context: dict | None = None,
) -> str:
    max_discount = shop["max_discount_pct"] or 20
    max_cashback = shop["cashback_budget_per_coupon_cents"] or 300
    product_price = product["price_cents"]
    context = context or {}
    weather = context.get("weather") or {}
    time_ctx = context.get("time") or {}
    creative = context.get("creative_brief") or {}
    neighbor_headlines = context.get("neighbor_headlines") or []
    forbidden_openers = context.get("forbidden_openers") or []
    rejected_headlines = context.get("rejected_headlines") or []
    revision_instruction = context.get("revision_instruction") or ""
    context_reasons = ", ".join(context.get("reasons") or []) or "live local context"
    fallback = _situation(shop, product, distance_m, ratio, threshold, context)
    if weather.get("available") is False:
        weather_line = f"Weather context: unavailable ({weather.get('reason', 'unknown')})"
    else:
        weather_line = (
            f"Weather context: {weather.get('temp', 'unknown')}C, "
            f"feels like {weather.get('feels_like', 'unknown')}C, "
            f"{weather.get('condition', 'unknown')}"
        )
    return f"""
You are City Wallet's creative local offer designer.
Write ONE useful, vivid, playful coupon for this exact moment.
Be artistic and surprising without becoming confusing.
Return JSON only. No markdown.

Shop: {shop['name']}
Category: {shop['category']}
Address: {shop.get('address') or 'nearby'}
Product: {product['name']} at {product['price_cents'] / 100:.2f}
Distance from user: {distance_m}m
Time context: {time_ctx.get('period', 'unknown')} on {time_ctx.get('day_of_week', 'unknown')} at {time_ctx.get('hour', 'unknown')}:00
{weather_line}
Why this shop/product ranked well: {context_reasons}
Creative lane: {creative.get('name', 'open')}
Headline style: {creative.get('headline_style', 'specific to this merchant and product')}
Must include or clearly imply: {creative.get('must_include', product['name'])}
Avoid these words/patterns for this card: {creative.get('avoid', 'generic offer language')}
Distinctness rule: {creative.get('distinctness', 'make it different from nearby cards')}
Shop-name rule: {creative.get('shop_name_policy', 'use the shop name naturally')}
Neighbor headlines already generated: {', '.join(neighbor_headlines) or 'none yet'}
Do not start with these openers: {', '.join(forbidden_openers) or 'none'}
Rejected drafts from you: {', '.join(rejected_headlines) or 'none'}
Revision instruction: {revision_instruction or 'none'}
Backend fallback if you cannot decide: {fallback['discount_pct']}% off, expires in {fallback['expires_minutes']} minutes, tone {fallback['tone']}
Current demand: {busyness['txn_count_15min']} transactions in 15 minutes
Typical demand this hour: {busyness['typical']}
Demand ratio: {ratio:.2f}
Merchant threshold: {threshold:.2f}
Max discount: {max_discount}%
Max cashback cents: {max_cashback}
Product price cents: {product_price}

Rules:
- Do not sound spammy, corporate, or generic.
- Headline max 7 words.
- Body max 2 short sentences. It can be charming, witty, sensory, or cinematic.
- Explain why now using a natural mix of distance, quietness, time, and weather.
- Do not force weather/time into the copy if it would feel awkward.
- You decide the offer mechanic and emphasis: percentage-led, cashback-led, urgent quiet-time, warm-up, lunch rescue, rainy shelter, worth-the-walk, etc.
- Make the discount and expiry feel earned by the context, not copied from a template.
- Use the product, weather, time, busyness, and distance to make this offer specific.
- Follow the creative lane. Nearby cards are shown side by side, so avoid repeating the same headline structure.
- Do not start every headline with the day, time period, weather, or the same phrase.
- If neighbor headlines are listed, your headline must use a different rhythm, first words, and image.
- Do not use near-synonyms of a repeated phrase just to dodge the rule. "Fuel" and "Refuel" count as the same idea.
- Spread attention across product, place, quietness, value, weather, distance, and mood. Do not put the same context signal first every time.
- If a draft was rejected, do not preserve its structure. Change the metaphor, first words, and emotional angle.
- Have fun with the language: metaphors, tiny stories, local mood, sensory detail, gentle humor.
- Make each coupon feel like a little invitation, not an advert.
- Prefer concrete images over generic words like deal, offer, reward, fuel, refuel, treat.
- discount_pct must be an integer from 0 to {max_discount}. Use 0 only if cashback is the main incentive.
- cashback_cents must be <= {max_cashback}. Use it creatively but keep it plausible for the product price.
- expires_minutes must be 30, 45, or 60.
- If the shop is unusually quiet, a stronger or shorter-lived offer can make sense.
- If the context match is strong but demand is normal, prefer a tasteful moderate offer.
- If the user is far away, only make it compelling if the offer is genuinely worth the trip.
- Cashback should usually be derived from the product price, discount, and merchant budget, not a repeated flat value.

Return exactly these JSON keys with your chosen values:
{{
  "headline": "...",
  "body_text": "...",
  "why_now": "...",
  "discount_pct": <integer>,
  "cashback_cents": <integer>,
  "expires_minutes": <30 or 45 or 60>,
  "tone": "<warm, urgent, playful, or calm>"
}}
""".strip()


def _coerce_offer(
    raw: dict,
    shop: dict,
    product: dict,
    distance_m: int,
    ratio: float,
    threshold: float,
    context: dict | None = None,
) -> dict:
    max_discount = shop["max_discount_pct"] or 20
    max_cashback = shop["cashback_budget_per_coupon_cents"] or 300
    price = product["price_cents"]
    context = context or {}
    suggested_discount = _weighted_discount_pct(shop, product, distance_m, ratio, threshold, context)

    discount = int(raw.get("discount_pct") or suggested_discount)
    discount = max(0, min(discount, max_discount))

    cashback = int(raw.get("cashback_cents") or round(price * discount / 100))
    cashback = max(0, min(cashback, max_cashback))
    if discount == 0 and cashback == 0:
        discount = suggested_discount
        cashback = min(round(price * discount / 100), max_cashback)

    expires = int(raw.get("expires_minutes") or 45)
    if expires not in (30, 45, 60):
        expires = 45

    headline = str(raw.get("headline") or f"{shop['name']} reward").strip()
    body_text = str(raw.get("body_text") or "A nearby quiet-time offer is ready for you.").strip()
    why_now = str(raw.get("why_now") or "Generated from live location and quietness signals.").strip()

    return {
        "headline": headline[:80],
        "body_text": body_text[:240],
        "why_now": why_now[:240],
        "discount_pct": discount,
        "cashback_cents": cashback,
        "expires_minutes": expires,
        "tone": str(raw.get("tone") or "warm")[:24],
    }


def _headline_tokens(headline: str) -> list[str]:
    return [
        token
        for token in re.sub(r"[^a-z0-9 ]", " ", headline.lower()).split()
        if token not in {"the", "a", "an", "at", "with", "your", "for", "on", "in", "and", "of"}
    ]


def _too_similar(headline: str, neighbors: list[str], forbidden_openers: list[str]) -> bool:
    normalized = " ".join(_headline_tokens(headline))
    words = normalized.split()
    opener2 = " ".join(words[:2])
    opener3 = " ".join(words[:3])
    if opener2 in forbidden_openers or opener3 in forbidden_openers:
        return True

    repeated_ideas = {"fuel", "refuel", "sun", "sunday", "morning", "rainy", "cloud", "cloudy", "shelter"}
    headline_ideas = set(words) & repeated_ideas
    for neighbor in neighbors:
        neighbor_normalized = " ".join(_headline_tokens(neighbor))
        if SequenceMatcher(None, normalized, neighbor_normalized).ratio() >= 0.58:
            return True
        neighbor_ideas = set(neighbor_normalized.split()) & repeated_ideas
        if len(headline_ideas & neighbor_ideas) >= 2:
            return True
    return False


async def generate_coupon_copy(
    shop: dict,
    product: dict,
    distance_m: int,
    busyness: dict,
    ratio: float,
    threshold: float,
    context: dict | None = None,
) -> dict:
    fallback = _fallback_offer(shop, product, distance_m, busyness, ratio, threshold, context)
    if not settings.gemma_enabled:
        return fallback

    context = dict(context or {})
    rejected_headlines: list[str] = []
    for attempt in range(2):
        try:
            async with httpx.AsyncClient(timeout=12) as client:
                response = await client.post(
                    f"{settings.gemma_base_url.rstrip('/')}/api/generate",
                    json={
                        "model": settings.gemma_model,
                        "prompt": _prompt(shop, product, distance_m, busyness, ratio, threshold, context),
                        "stream": False,
                        "options": {"temperature": 0.75, "num_predict": 320},
                    },
                )
                response.raise_for_status()
            text = response.json().get("response", "")
            match = re.search(r"\{[\s\S]*\}", text)
            if not match:
                return fallback
            offer = _coerce_offer(json.loads(match.group(0)), shop, product, distance_m, ratio, threshold, context)
        except Exception:
            return fallback

        if not _too_similar(
            offer["headline"],
            context.get("neighbor_headlines") or [],
            context.get("forbidden_openers") or [],
        ):
            return offer

        rejected_headlines.append(offer["headline"])
        context["rejected_headlines"] = rejected_headlines
        context["revision_instruction"] = (
            "Your last headline sounded too similar to nearby cards. "
            "Rewrite from a different angle: lead with product, value, quietness, or place; "
            "do not lead with weather, Sunday, morning, fuel/refuel, clouds, or shelter."
        )

    return offer
