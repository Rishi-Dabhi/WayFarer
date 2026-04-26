"""
Bootstrap a full London demo dataset for WayFarer.

What this script does:
1. Queries OpenStreetMap in tiles across Greater London for real venues.
2. Registers those venues as WayFarer merchants and shops.
3. Generates plausible product catalogs and merchant descriptions.
4. Seeds busyness, coupons, redemptions, and analytics-friendly history.
5. Creates a synthetic consumer crowd with current map positions.

Examples:
    python bootstrap_london_demo.py --dry-run
    python bootstrap_london_demo.py --clear-generated --shop-limit 1200 --consumer-count 2500
"""

from __future__ import annotations

import argparse
import asyncio
import json
import math
import random
import re
from dataclasses import dataclass
from datetime import datetime, timedelta
from pathlib import Path

import aiosqlite
import httpx
from passlib.context import CryptContext

from config import settings
from services.qr_service import generate_qr_token

_pwd = CryptContext(schemes=["bcrypt"], deprecated="auto")

LONDON_BBOX = {
    "south": 51.2868,
    "west": -0.5103,
    "north": 51.6919,
    "east": 0.3340,
}

OVERPASS_URLS = [
    "https://overpass-api.de/api/interpreter",
    "https://overpass.osm.ch/api/interpreter",
    "https://overpass.openstreetmap.ru/api/interpreter",
]

_AMENITY_CATEGORY: dict[str, tuple[str, str]] = {
    "cafe": ("cafe", "cafe"),
    "restaurant": ("restaurant", "restaurant"),
    "bar": ("bar", "bar"),
    "pub": ("bar", "pub"),
    "fast_food": ("restaurant", "fast food spot"),
    "ice_cream": ("cafe", "ice cream shop"),
    "bakery": ("cafe", "bakery"),
    "food_court": ("restaurant", "food court venue"),
}

_SHOP_CATEGORY: dict[str, tuple[str, str]] = {
    "bakery": ("cafe", "bakery"),
    "convenience": ("retail", "convenience store"),
    "supermarket": ("retail", "supermarket"),
    "greengrocer": ("retail", "greengrocer"),
    "butcher": ("retail", "butcher"),
    "seafood": ("retail", "seafood shop"),
    "cheese": ("retail", "cheese shop"),
    "beverages": ("retail", "beverage shop"),
    "organic": ("retail", "organic grocery"),
    "clothes": ("retail", "clothing store"),
    "books": ("retail", "bookshop"),
    "gift": ("retail", "gift shop"),
    "florist": ("retail", "florist"),
    "jewellery": ("retail", "jewellery store"),
    "optician": ("retail", "optician"),
    "shoes": ("retail", "shoe store"),
    "sports": ("retail", "sports store"),
    "stationery": ("retail", "stationery store"),
    "deli": ("restaurant", "deli"),
}

_CAMPAIGN_GOAL_BY_CATEGORY = {
    "cafe": "fill_quiet_hours",
    "restaurant": "fill_quiet_hours",
    "bar": "new_customers",
    "retail": "clear_stock",
}

_QUIET_HOURS_BY_CATEGORY = {
    "cafe": ["09:00-11:00", "14:00-16:00"],
    "restaurant": ["15:00-17:00"],
    "bar": ["16:00-19:00"],
    "retail": ["14:00-16:00"],
}

_BASE_PRODUCT_TEMPLATES: dict[str, list[tuple[str, str, int, int, str]]] = {
    "cafe": [
        ("Flat White", "drink", 340, 460, "House coffee made to order."),
        ("Cappuccino", "drink", 320, 440, "Classic espresso with steamed milk."),
        ("Iced Latte", "drink", 360, 490, "Cold espresso drink for warmer afternoons."),
        ("Croissant", "bakery", 250, 360, "Fresh pastry prepared for the morning rush."),
        ("Banana Bread", "bakery", 280, 420, "Popular counter bake for coffee pairings."),
    ],
    "bakery": [
        ("Sourdough Loaf", "bakery", 420, 650, "Daily baked bread from the front counter."),
        ("Pain au Chocolat", "bakery", 260, 390, "Classic laminated pastry."),
        ("Cinnamon Bun", "bakery", 300, 430, "Sweet pastry for coffee and takeaway orders."),
        ("Sandwich Deal", "food", 520, 790, "Quick lunch item prepared in-store."),
    ],
    "restaurant": [
        ("Lunch Special", "meal", 1090, 1590, "Fast-moving lunch menu favourite."),
        ("House Salad", "meal", 840, 1290, "Lighter option popular during midday traffic."),
        ("Pasta Bowl", "meal", 1140, 1690, "Warm main for afternoon and evening trade."),
        ("Soft Drink", "drink", 240, 360, "Cold drink add-on with strong attachment rate."),
    ],
    "fast_food": [
        ("Combo Meal", "meal", 790, 1190, "Main item with side and drink."),
        ("Fries", "side", 250, 420, "Reliable high-volume add-on."),
        ("Chicken Wrap", "meal", 590, 890, "Quick grab-and-go favourite."),
        ("Soft Drink", "drink", 220, 340, "Cold drink for bundled orders."),
    ],
    "bar": [
        ("House Beer", "drink", 480, 720, "Core draught choice for regulars."),
        ("Glass of Wine", "drink", 580, 890, "Popular evening choice."),
        ("Cocktail Special", "drink", 850, 1290, "Higher-margin special for quieter slots."),
        ("Bar Snack", "food", 340, 620, "Snack item ordered with drinks."),
    ],
    "pub": [
        ("Pint of Lager", "drink", 520, 760, "Classic pint for after-work trade."),
        ("Burger", "meal", 990, 1490, "Pub kitchen staple."),
        ("Chips", "side", 320, 480, "Easy add-on for food orders."),
        ("Soft Drink", "drink", 240, 360, "Alcohol-free option for mixed groups."),
    ],
    "supermarket": [
        ("Meal Deal", "grocery", 350, 550, "Grab-and-go lunch bundle."),
        ("Fresh Fruit Pot", "grocery", 180, 320, "Healthy convenience item."),
        ("Sparkling Water", "drink", 120, 220, "Fast-moving chilled drink."),
        ("Chocolate Bar", "snack", 90, 180, "Impulse checkout item."),
    ],
    "convenience": [
        ("Snack Bundle", "grocery", 250, 450, "Convenience bundle for quick trips."),
        ("Soft Drink", "drink", 120, 220, "Popular grab-and-go drink."),
        ("Phone Charger", "accessory", 790, 1290, "Higher-value urgent purchase item."),
        ("Travel Essentials", "grocery", 290, 540, "Useful top-up item for commuters."),
    ],
    "books": [
        ("Paperback Pick", "book", 799, 1499, "Popular fiction or non-fiction title."),
        ("Journal", "stationery", 450, 990, "Giftable desk or travel notebook."),
        ("Bookmark Set", "gift", 250, 540, "Small add-on at checkout."),
        ("Children's Book", "book", 699, 1299, "Family-friendly bestseller section."),
    ],
    "clothes": [
        ("T-Shirt", "apparel", 1299, 2499, "Core wardrobe item."),
        ("Hoodie", "apparel", 2499, 4499, "Higher-ticket featured item."),
        ("Socks", "apparel", 499, 1099, "Fast-moving add-on."),
        ("Cap", "accessory", 899, 1899, "Accessory near checkout or front display."),
    ],
    "florist": [
        ("Seasonal Bouquet", "flowers", 1499, 2999, "Fresh bouquet with strong gift appeal."),
        ("Small Posy", "flowers", 799, 1499, "Lower-ticket same-day pickup option."),
        ("House Plant", "plants", 999, 2499, "Indoor plant for repeat footfall."),
        ("Greeting Card", "gift", 250, 490, "Checkout add-on."),
    ],
    "gift": [
        ("Gift Box", "gift", 999, 2499, "Wrapped gift-ready item."),
        ("Scented Candle", "gift", 799, 1999, "Popular gifting product."),
        ("Ceramic Mug", "home", 699, 1499, "Giftable shelf staple."),
        ("Greeting Card", "gift", 220, 450, "High-margin checkout add-on."),
    ],
    "jewellery": [
        ("Silver Earrings", "accessory", 1999, 4999, "Popular entry-price jewellery piece."),
        ("Bracelet", "accessory", 1499, 3999, "Giftable accessory option."),
        ("Necklace", "accessory", 2499, 5999, "Featured display item."),
        ("Gift Pouch", "gift", 150, 300, "Packaging add-on."),
    ],
    "optician": [
        ("Sunglasses", "eyewear", 1999, 4999, "Front-of-store impulse accessory."),
        ("Cleaning Kit", "eyewear", 499, 999, "Low-ticket care item."),
        ("Reading Glasses", "eyewear", 999, 2499, "Accessible everyday eyewear."),
        ("Lens Cloth Pack", "eyewear", 250, 550, "Small add-on at checkout."),
    ],
    "shoes": [
        ("Trainers", "footwear", 2999, 6999, "Core footwear line."),
        ("Slip-Ons", "footwear", 2499, 5499, "Comfort-led bestseller."),
        ("Shoe Care Kit", "accessory", 599, 1299, "High-margin aftercare add-on."),
        ("Socks", "apparel", 499, 1099, "Checkout add-on."),
    ],
    "sports": [
        ("Water Bottle", "sports", 499, 1499, "Accessory for gym and commute."),
        ("Training Tee", "sports", 1499, 2999, "Core apparel item."),
        ("Resistance Band", "sports", 799, 1899, "Compact training accessory."),
        ("Cap", "sports", 999, 1999, "Impulse sportswear add-on."),
    ],
    "stationery": [
        ("Notebook", "stationery", 350, 890, "Everyday writing essential."),
        ("Pen Set", "stationery", 299, 799, "Desk accessory with gift appeal."),
        ("Desk Planner", "stationery", 650, 1490, "Popular work and study item."),
        ("Greeting Card", "gift", 220, 420, "Small checkout add-on."),
    ],
}

_FIRST_NAMES = [
    "Mia", "Noah", "Amelia", "Leo", "Ivy", "Oliver", "Ava", "Arthur", "Ella", "Oscar",
    "Grace", "Freddie", "Sofia", "Theo", "Lily", "Harry", "Evie", "George", "Ruby", "Jack",
]

_LAST_NAMES = [
    "Taylor", "Morgan", "Patel", "Khan", "Wilson", "Bennett", "Walker", "Green", "Foster", "Murphy",
    "Hall", "Cooper", "Ali", "Ward", "Baker", "Turner", "Brooks", "Campbell", "Long", "Morris",
]


@dataclass(slots=True)
class Poi:
    osm_key: str
    osm_id: int
    name: str
    category: str
    subtype: str
    subtype_label: str
    lat: float
    lng: float
    address: str
    description: str
    opening_hours: str
    website: str
    phone: str
    postcode: str
    tile_index: int = 0


def _slug(value: str) -> str:
    return re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-")[:40] or "shop"


def _seeded_rng(seed_value: str) -> random.Random:
    return random.Random(seed_value)


def _meters_to_lat(meters: float) -> float:
    return meters / 111_320


def _meters_to_lng(meters: float, lat: float) -> float:
    return meters / (111_320 * max(math.cos(math.radians(lat)), 0.2))


def _offset_point(lat: float, lng: float, radius_m: float, rng: random.Random) -> tuple[float, float]:
    distance = rng.uniform(10, radius_m)
    bearing = rng.uniform(0, 2 * math.pi)
    return (
        lat + _meters_to_lat(math.cos(bearing) * distance),
        lng + _meters_to_lng(math.sin(bearing) * distance, lat),
    )


def _address_from_tags(tags: dict) -> str:
    parts = [
        " ".join(part for part in [tags.get("addr:housenumber"), tags.get("addr:street")] if part),
        tags.get("addr:suburb"),
        tags.get("addr:postcode"),
        tags.get("addr:city") or "London",
    ]
    address = ", ".join(part for part in parts if part)
    return address or "Address from OpenStreetMap unavailable"


def _shop_meta(tags: dict) -> tuple[str, str, str]:
    amenity = str(tags.get("amenity") or "")
    shop = str(tags.get("shop") or "")
    if amenity in _AMENITY_CATEGORY:
        category, subtype_label = _AMENITY_CATEGORY[amenity]
        return category, amenity, subtype_label
    if shop in _SHOP_CATEGORY:
        category, subtype_label = _SHOP_CATEGORY[shop]
        return category, shop, subtype_label
    return "retail", shop or amenity or "retail", "local shop"


def _shop_description(name: str, subtype_label: str, tags: dict, address: str) -> str:
    cues: list[str] = []
    cuisine = str(tags.get("cuisine") or "").replace(";", ", ")
    if cuisine:
        cues.append(f"Known for {cuisine}.")
    if tags.get("brand"):
        cues.append(f"Operating under the {tags['brand']} brand.")
    if tags.get("opening_hours"):
        cues.append(f"OSM hours: {tags['opening_hours']}.")
    if tags.get("website"):
        cues.append("Website available for more details.")
    if tags.get("wheelchair") == "yes":
        cues.append("Wheelchair-accessible entrance listed in OpenStreetMap.")
    lead = f"{name} is a real London {subtype_label} near {address}."
    return " ".join([lead, *cues[:3]]).strip()


_GROCERY_SUBTYPES = {
    "supermarket",
    "convenience",
    "greengrocer",
    "butcher",
    "seafood",
    "cheese",
    "beverages",
    "organic",
    "deli",
}


def _poi_priority(poi: Poi) -> tuple[int, str]:
    score = 0
    if poi.category == "restaurant":
        score += 120
    elif poi.category == "cafe":
        score += 110
    elif poi.subtype in _GROCERY_SUBTYPES:
        score += 105
    elif poi.category == "retail":
        score += 40
    elif poi.category == "bar":
        score += 20

    if poi.address != "Address from OpenStreetMap unavailable":
        score += 6
    if poi.postcode:
        score += 3
    if poi.opening_hours:
        score += 1
    return score, poi.name.lower()


def _balanced_select_pois(pois: list[Poi], shop_limit: int | None) -> list[Poi]:
    buckets: dict[int, list[Poi]] = {}
    for poi in pois:
        buckets.setdefault(poi.tile_index, []).append(poi)

    for tile_index, bucket in buckets.items():
        bucket.sort(key=lambda poi: (-_poi_priority(poi)[0], _poi_priority(poi)[1]))
        buckets[tile_index] = bucket

    tile_order = sorted(buckets.keys())
    selected: list[Poi] = []
    target = shop_limit if shop_limit is not None else sum(len(bucket) for bucket in buckets.values())

    while len(selected) < target:
        progressed = False
        for tile_index in tile_order:
            bucket = buckets[tile_index]
            if not bucket:
                continue
            selected.append(bucket.pop(0))
            progressed = True
            if len(selected) >= target:
                break
        if not progressed:
            break

    return selected


def _build_bbox_query(south: float, west: float, north: float, east: float) -> str:
    amenity_filter = "|".join(_AMENITY_CATEGORY.keys())
    shop_filter = "|".join(_SHOP_CATEGORY.keys())
    return f"""
[out:json][timeout:90];
(
  nwr["amenity"~"^({amenity_filter})$"]["name"]({south},{west},{north},{east});
  nwr["shop"~"^({shop_filter})$"]["name"]({south},{west},{north},{east});
);
out center tags;
""".strip()


def _tile_bounds(step_lat: float, step_lng: float) -> list[tuple[float, float, float, float]]:
    bounds = []
    lat = LONDON_BBOX["south"]
    while lat < LONDON_BBOX["north"]:
        next_lat = min(lat + step_lat, LONDON_BBOX["north"])
        lng = LONDON_BBOX["west"]
        while lng < LONDON_BBOX["east"]:
            next_lng = min(lng + step_lng, LONDON_BBOX["east"])
            bounds.append((lat, lng, next_lat, next_lng))
            lng = next_lng
        lat = next_lat
    return bounds


async def _fetch_tile(client: httpx.AsyncClient, south: float, west: float, north: float, east: float) -> list[dict]:
    query = _build_bbox_query(south, west, north, east)
    last_error: Exception | None = None
    for url in OVERPASS_URLS:
        try:
            response = await client.post(url, data={"data": query})
            response.raise_for_status()
            return response.json().get("elements", [])
        except Exception as exc:  # pragma: no cover
            last_error = exc
    if last_error:
        raise last_error
    return []


def _poi_from_element(element: dict) -> Poi | None:
    tags = element.get("tags", {})
    name = str(tags.get("name") or "").strip()
    if not name:
        return None
    center = element.get("center", {})
    lat = element.get("lat", center.get("lat"))
    lng = element.get("lon", center.get("lon"))
    if lat is None or lng is None:
        return None
    category, subtype, subtype_label = _shop_meta(tags)
    address = _address_from_tags(tags)
    osm_type = str(element.get("type") or "node")
    osm_id = int(element.get("id"))
    return Poi(
        osm_key=f"{osm_type}:{osm_id}",
        osm_id=osm_id,
        name=name,
        category=category,
        subtype=subtype,
        subtype_label=subtype_label,
        lat=float(lat),
        lng=float(lng),
        address=address,
        description=_shop_description(name, subtype_label, tags, address),
        opening_hours=str(tags.get("opening_hours") or ""),
        website=str(tags.get("website") or tags.get("contact:website") or ""),
        phone=str(tags.get("phone") or tags.get("contact:phone") or ""),
        postcode=str(tags.get("addr:postcode") or ""),
    )


async def collect_london_pois(step_lat: float, step_lng: float, shop_limit: int | None) -> list[Poi]:
    tiles = _tile_bounds(step_lat, step_lng)
    deduped: dict[str, Poi] = {}
    headers = {"User-Agent": "CityWalletHackathon/1.0"}
    async with httpx.AsyncClient(timeout=120, headers=headers) as client:
        for index, (south, west, north, east) in enumerate(tiles, start=1):
            elements = await _fetch_tile(client, south, west, north, east)
            print(f"Tile {index}/{len(tiles)} -> {len(elements)} raw venues")
            for element in elements:
                poi = _poi_from_element(element)
                if poi is not None:
                    poi.tile_index = index
                    deduped[poi.osm_key] = poi
    pois = _balanced_select_pois(list(deduped.values()), shop_limit)
    preferred = sum(1 for poi in pois if poi.category in {"restaurant", "cafe"} or poi.subtype in _GROCERY_SUBTYPES)
    print(f"Selected {len(pois)} venues across {len({poi.tile_index for poi in pois})} London tiles.")
    print(f"Preferred mix (restaurants/cafes/grocery): {preferred}/{len(pois)}")
    return pois


def _product_templates(subtype: str, category: str) -> list[tuple[str, str, int, int, str]]:
    if subtype in _BASE_PRODUCT_TEMPLATES:
        return _BASE_PRODUCT_TEMPLATES[subtype]
    return _BASE_PRODUCT_TEMPLATES[category]


def _build_products(poi: Poi) -> list[dict]:
    rng = _seeded_rng(poi.osm_key)
    products = []
    templates = _product_templates(poi.subtype, poi.category)[:4]
    for name, product_category, low, high, description in templates:
        price_cents = int(round(rng.randint(low, high) / 10.0) * 10)
        stock_level = rng.choices(["low", "normal", "high"], weights=[1, 5, 3], k=1)[0]
        products.append(
            {
                "name": name,
                "description": f"{description} Selected for {poi.name}.",
                "price_cents": price_cents,
                "category": product_category,
                "stock_level": stock_level,
            }
        )
    if poi.subtype == "books" and "children" in poi.name.lower():
        products[0]["name"] = "Children's Bestseller"
    return products


async def _prepare_db() -> aiosqlite.Connection:
    db = await aiosqlite.connect(settings.database_url)
    db.row_factory = aiosqlite.Row
    await db.execute("PRAGMA foreign_keys=ON")
    await db.executescript((Path(__file__).parent / "schema.sql").read_text())
    await db.commit()
    return db


async def _clear_generated_data(db: aiosqlite.Connection) -> None:
    merchant_pattern = "london-shop-%@citywallet.local"
    consumer_pattern = "crowd-user-%@citywallet.local"

    async with db.execute(
        "SELECT id FROM users WHERE email LIKE ? OR email LIKE ?",
        (merchant_pattern, consumer_pattern),
    ) as cur:
        generated_users = [row["id"] for row in await cur.fetchall()]

    if not generated_users:
        print("No previously generated London demo rows found.")
        return

    placeholders = ",".join("?" for _ in generated_users)
    async with db.execute(f"SELECT id FROM shops WHERE merchant_id IN ({placeholders})", generated_users) as cur:
        shop_ids = [row["id"] for row in await cur.fetchall()]

    if shop_ids:
        shop_placeholders = ",".join("?" for _ in shop_ids)
        await db.execute(f"DELETE FROM simulated_user_locations WHERE anchor_shop_id IN ({shop_placeholders})", shop_ids)
        await db.execute(f"DELETE FROM payone_density WHERE shop_id IN ({shop_placeholders})", shop_ids)
        await db.execute(f"DELETE FROM transactions WHERE shop_id IN ({shop_placeholders})", shop_ids)
        await db.execute(f"DELETE FROM coupons WHERE shop_id IN ({shop_placeholders})", shop_ids)
        await db.execute(f"DELETE FROM products WHERE shop_id IN ({shop_placeholders})", shop_ids)
        await db.execute(f"DELETE FROM shop_visits WHERE shop_id IN ({shop_placeholders})", shop_ids)
        await db.execute(f"DELETE FROM shops WHERE id IN ({shop_placeholders})", shop_ids)

    await db.execute(f"DELETE FROM simulated_user_locations WHERE user_id IN ({placeholders})", generated_users)
    await db.execute(f"DELETE FROM transactions WHERE user_id IN ({placeholders})", generated_users)
    await db.execute(f"DELETE FROM coupons WHERE user_id IN ({placeholders})", generated_users)
    await db.execute(f"DELETE FROM shop_visits WHERE user_id IN ({placeholders})", generated_users)
    await db.execute(f"DELETE FROM user_preferences WHERE user_id IN ({placeholders})", generated_users)
    await db.execute(f"DELETE FROM merchant_wallets WHERE merchant_id IN ({placeholders})", generated_users)
    await db.execute(f"DELETE FROM users WHERE id IN ({placeholders})", generated_users)
    await db.commit()
    print(f"Cleared {len(generated_users)} generated users and related demo rows.")


async def _seed_payone_history(db: aiosqlite.Connection, shop_id: int, poi: Poi) -> None:
    rng = _seeded_rng(f"payone:{poi.osm_key}")
    now = datetime.utcnow()
    base_by_category = {"cafe": 4, "restaurant": 7, "bar": 5, "retail": 3}
    base = base_by_category.get(poi.category, 3)
    for minutes_ago in range(115, -1, -5):
        ts = (now - timedelta(minutes=minutes_ago)).isoformat()
        local_hour = (datetime.now() - timedelta(minutes=minutes_ago)).hour
        hour_bias = 1.0
        if poi.category == "cafe" and 7 <= local_hour <= 10:
            hour_bias = 1.8
        elif poi.category == "restaurant" and 11 <= local_hour <= 14:
            hour_bias = 2.0
        elif poi.category == "bar" and 17 <= local_hour <= 22:
            hour_bias = 2.1
        elif poi.category == "retail" and 12 <= local_hour <= 18:
            hour_bias = 1.5
        count = max(0, int(round(base * hour_bias * rng.uniform(0.4, 1.4))))
        await db.execute(
            "INSERT INTO payone_density (shop_id, txn_count, recorded_at) VALUES (?,?,?)",
            (shop_id, count, ts),
        )


async def _maybe_seed_shop_coupons(
    db: aiosqlite.Connection,
    shop_id: int,
    merchant_id: int,
    poi: Poi,
    product_ids: list[int],
) -> None:
    rng = _seeded_rng(f"coupon:{poi.osm_key}")
    if rng.random() > 0.38 or not product_ids:
        return

    expires_at = (datetime.utcnow() + timedelta(minutes=rng.randint(45, 180))).isoformat()
    discount_pct = rng.choice([10, 12, 15, 18, 20])
    cashback_cents = rng.choice([60, 90, 120, 150, 180, 220])
    context_snapshot = {
        "source": "london_bootstrap",
        "merchant_id": merchant_id,
        "shop_category": poi.category,
        "shop_subtype": poi.subtype,
        "why": "Seeded live offer so the London map shows active coupons on day one.",
    }
    await db.execute(
        """INSERT INTO coupons
           (shop_id, user_id, headline, body_text, why_now, discount_pct, cashback_cents,
            product_id, context_snapshot, qr_token, expires_at)
           VALUES (?,?,?,?,?,?,?,?,?,?,?)""",
        (
            shop_id,
            None,
            f"{poi.name}: save {discount_pct}% right now",
            f"Live seeded offer for {poi.name} to make the London map feel populated from the start.",
            "This shop was bootstrapped with an active offer for demo visibility.",
            discount_pct,
            cashback_cents,
            product_ids[0],
            json.dumps(context_snapshot),
            generate_qr_token(),
            expires_at,
        ),
    )


async def register_london_shops(db: aiosqlite.Connection, pois: list[Poi], wallet_cents: int) -> list[dict]:
    shops: list[dict] = []
    for index, poi in enumerate(pois, start=1):
        email = f"london-shop-{poi.osm_id}-{_slug(poi.name)}@citywallet.local"
        async with db.execute("SELECT id FROM users WHERE email=?", (email,)) as cur:
            existing = await cur.fetchone()
        if existing:
            continue

        async with db.execute(
            "INSERT INTO users (email, password_hash, role, name) VALUES (?,?,?,?)",
            (email, _pwd.hash("demo1234"), "merchant", poi.name),
        ) as cur:
            merchant_id = cur.lastrowid

        await db.execute(
            "INSERT INTO merchant_wallets (merchant_id, balance_cents) VALUES (?,?)",
            (merchant_id, wallet_cents),
        )

        async with db.execute(
            """INSERT INTO shops
               (merchant_id, name, description, category, latitude, longitude, address,
                target_quiet_hours, max_discount_pct, cashback_budget_per_coupon_cents,
                campaign_goal, auto_coupon_enabled, auto_trigger_radius_m, quiet_threshold_ratio,
                coupon_frequency_minutes, is_active)
               VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
            (
                merchant_id,
                poi.name,
                poi.description,
                poi.category,
                poi.lat,
                poi.lng,
                poi.address,
                json.dumps(_QUIET_HOURS_BY_CATEGORY.get(poi.category, ["14:00-16:00"])),
                20,
                300,
                _CAMPAIGN_GOAL_BY_CATEGORY.get(poi.category, "fill_quiet_hours"),
                1,
                300,
                0.7 if poi.category in ("cafe", "restaurant") else 0.6,
                45,
                1,
            ),
        ) as cur:
            shop_id = cur.lastrowid

        product_ids: list[int] = []
        for product in _build_products(poi):
            async with db.execute(
                "INSERT INTO products (shop_id, name, description, price_cents, category, stock_level) VALUES (?,?,?,?,?,?)",
                (
                    shop_id,
                    product["name"],
                    product["description"],
                    product["price_cents"],
                    product["category"],
                    product["stock_level"],
                ),
            ) as cur:
                product_ids.append(cur.lastrowid)

        await _seed_payone_history(db, shop_id, poi)
        await _maybe_seed_shop_coupons(db, shop_id, merchant_id, poi, product_ids)
        await db.commit()

        shops.append(
            {
                "id": shop_id,
                "merchant_id": merchant_id,
                "name": poi.name,
                "category": poi.category,
                "subtype": poi.subtype,
                "lat": poi.lat,
                "lng": poi.lng,
                "product_ids": product_ids,
            }
        )
        if index % 50 == 0:
            print(f"Registered {index} shops...")
    return shops


def _consumer_name(index: int, rng: random.Random) -> str:
    return f"{_FIRST_NAMES[index % len(_FIRST_NAMES)]} {rng.choice(_LAST_NAMES)}"


def _category_affinity(primary: str, secondary: str) -> dict[str, float]:
    affinities = {"cafe": 0.2, "restaurant": 0.2, "bar": 0.1, "retail": 0.2}
    affinities[primary] = 0.85
    affinities[secondary] = max(affinities.get(secondary, 0.2), 0.55)
    return affinities


async def _seed_historical_user_activity(
    db: aiosqlite.Connection,
    user_id: int,
    preferred_shops: list[dict],
    rng: random.Random,
) -> tuple[int, int]:
    visits_created = 0
    redemptions_created = 0
    now = datetime.utcnow()

    for _ in range(rng.randint(3, 10)):
        shop = rng.choice(preferred_shops)
        days_ago = rng.randint(0, 13)
        minutes_ago = rng.randint(0, 23 * 60)
        entered_at = now - timedelta(days=days_ago, minutes=minutes_ago)
        visit_date = entered_at.date().isoformat()
        await db.execute(
            """INSERT OR IGNORE INTO shop_visits (shop_id, user_id, entered_at, visit_date)
               VALUES (?,?,?,?)""",
            (shop["id"], user_id, entered_at.isoformat(), visit_date),
        )
        visits_created += 1

    for _ in range(rng.randint(0, 3)):
        shop = rng.choice(preferred_shops)
        if not shop["product_ids"]:
            continue
        generated_at = now - timedelta(days=rng.randint(1, 10), minutes=rng.randint(20, 600))
        redeemed_at = generated_at + timedelta(minutes=rng.randint(15, 120))
        discount_pct = rng.choice([10, 12, 15, 18])
        cashback_cents = rng.choice([45, 60, 90, 120, 150])
        async with db.execute(
            """INSERT INTO coupons
               (shop_id, user_id, headline, body_text, why_now, discount_pct, cashback_cents,
                product_id, context_snapshot, qr_token, status, expires_at, generated_at, redeemed_at)
               VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
            (
                shop["id"],
                user_id,
                f"{shop['name']} offer redeemed",
                "Synthetic redemption generated for London demo analytics.",
                "Seeded crowd activity to make merchant analytics non-empty.",
                discount_pct,
                cashback_cents,
                rng.choice(shop["product_ids"]),
                json.dumps({"source": "london_bootstrap", "kind": "redeemed_history"}),
                generate_qr_token(),
                "redeemed",
                (generated_at + timedelta(hours=3)).isoformat(),
                generated_at.isoformat(),
                redeemed_at.isoformat(),
            ),
        ) as cur:
            coupon_id = cur.lastrowid

        await db.execute(
            """INSERT INTO transactions
               (coupon_id, shop_id, user_id, cashback_cents, status, redeemed_at)
               VALUES (?,?,?,?,?,?)""",
            (
                coupon_id,
                shop["id"],
                user_id,
                cashback_cents,
                "completed",
                redeemed_at.isoformat(),
            ),
        )
        redemptions_created += 1
    return visits_created, redemptions_created


async def seed_consumers(
    db: aiosqlite.Connection,
    shops: list[dict],
    consumer_count: int,
) -> dict[str, int]:
    if not shops or consumer_count <= 0:
        return {"consumers": 0, "map_users": 0, "visits": 0, "redemptions": 0}

    await db.execute("DELETE FROM simulated_user_locations")
    category_buckets: dict[str, list[dict]] = {}
    for shop in shops:
        category_buckets.setdefault(shop["category"], []).append(shop)

    categories = [category for category in category_buckets if category_buckets[category]]
    visits = 0
    redemptions = 0

    for index in range(consumer_count):
        rng = _seeded_rng(f"consumer:{index}")
        primary = rng.choice(categories)
        secondary_choices = [category for category in categories if category != primary] or categories
        secondary = rng.choice(secondary_choices)
        anchor = rng.choice(category_buckets[primary])
        current_shop = rng.choice(category_buckets[primary] if rng.random() < 0.7 else shops)
        movement_state = rng.choices(["static", "walking", "moving_fast"], weights=[3, 8, 2], k=1)[0]
        current_radius = 25 if movement_state == "static" else 120 if movement_state == "walking" else 260
        lat, lng = _offset_point(current_shop["lat"], current_shop["lng"], current_radius, rng)
        email = f"crowd-user-{index:05d}@citywallet.local"

        async with db.execute("SELECT id FROM users WHERE email=?", (email,)) as cur:
            existing = await cur.fetchone()
        if existing:
            user_id = existing["id"]
        else:
            async with db.execute(
                "INSERT INTO users (email, password_hash, role, name) VALUES (?,?,?,?)",
                (email, _pwd.hash("demo1234"), "consumer", _consumer_name(index, rng)),
            ) as cur:
                user_id = cur.lastrowid

        await db.execute(
            """INSERT INTO user_preferences (user_id, category_affinity, preferred_discount_range, active_hours)
               VALUES (?,?,?,?)
               ON CONFLICT(user_id) DO UPDATE SET
                   category_affinity=excluded.category_affinity,
                   preferred_discount_range=excluded.preferred_discount_range,
                   active_hours=excluded.active_hours,
                   last_updated=datetime('now')""",
            (
                user_id,
                json.dumps(_category_affinity(primary, secondary)),
                json.dumps({"min": 10, "max": rng.choice([20, 25, 30])}),
                json.dumps(rng.sample(["07:00-09:00", "12:00-14:00", "17:00-19:00", "19:00-21:00"], k=2)),
            ),
        )

        await db.execute(
            """INSERT INTO simulated_user_locations (user_id, latitude, longitude, movement_state, anchor_shop_id, last_seen_at, is_active)
               VALUES (?,?,?,?,?,?,?)
               ON CONFLICT(user_id) DO UPDATE SET
                   latitude=excluded.latitude,
                   longitude=excluded.longitude,
                   movement_state=excluded.movement_state,
                   anchor_shop_id=excluded.anchor_shop_id,
                   last_seen_at=excluded.last_seen_at,
                   is_active=excluded.is_active""",
            (user_id, lat, lng, movement_state, current_shop["id"], datetime.utcnow().isoformat(), 1),
        )

        preferred_shops = [anchor]
        primary_shops = category_buckets.get(primary, [])
        if len(primary_shops) > 1:
            preferred_shops.extend(rng.sample(primary_shops, k=min(3, len(primary_shops))))
        user_visits, user_redemptions = await _seed_historical_user_activity(db, user_id, preferred_shops, rng)
        visits += user_visits
        redemptions += user_redemptions

        if rng.random() < 0.22 and current_shop["product_ids"]:
            discount_pct = rng.choice([10, 12, 15, 18, 20])
            await db.execute(
                """INSERT INTO coupons
                   (shop_id, user_id, headline, body_text, why_now, discount_pct, cashback_cents,
                    product_id, context_snapshot, qr_token, expires_at)
                   VALUES (?,?,?,?,?,?,?,?,?,?,?)""",
                (
                    current_shop["id"],
                    user_id,
                    f"{discount_pct}% off near {current_shop['name']}",
                    "Synthetic live coupon for a simulated London consumer.",
                    "User is currently close to the shop according to the crowd simulator.",
                    discount_pct,
                    rng.choice([50, 80, 120, 150]),
                    rng.choice(current_shop["product_ids"]),
                    json.dumps({"source": "london_bootstrap", "kind": "active_simulated_user"}),
                    generate_qr_token(),
                    (datetime.utcnow() + timedelta(minutes=rng.randint(30, 120))).isoformat(),
                ),
            )

        if (index + 1) % 200 == 0:
            await db.commit()
            print(f"Seeded {index + 1} simulated consumers...")

    await db.commit()
    return {"consumers": consumer_count, "map_users": consumer_count, "visits": visits, "redemptions": redemptions}


async def run(args: argparse.Namespace) -> None:
    pois = await collect_london_pois(args.tile_step_lat, args.tile_step_lng, args.shop_limit)
    print(f"Collected {len(pois)} unique London venues from OSM.")
    if args.dry_run:
        for poi in pois[:10]:
            print(f"DRY  {poi.name} [{poi.category}/{poi.subtype}] - {poi.address}")
        return

    db = await _prepare_db()
    try:
        if args.clear_generated:
            await _clear_generated_data(db)

        await register_london_shops(db, pois, args.wallet_cents)
        async with db.execute(
            "SELECT id, merchant_id, name, category, latitude, longitude FROM shops WHERE merchant_id IN (SELECT id FROM users WHERE email LIKE 'london-shop-%@citywallet.local')"
        ) as cur:
            existing_rows = await cur.fetchall()
        shops = [
            {
                "id": row["id"],
                "merchant_id": row["merchant_id"],
                "name": row["name"],
                "category": row["category"],
                "lat": row["latitude"],
                "lng": row["longitude"],
                "product_ids": [],
            }
            for row in existing_rows
        ]
        for shop in shops:
            async with db.execute("SELECT id FROM products WHERE shop_id=?", (shop["id"],)) as cur:
                shop["product_ids"] = [row["id"] for row in await cur.fetchall()]

        crowd = await seed_consumers(db, shops, args.consumer_count)
        print(
            f"London demo ready: {len(shops)} shops, {crowd['consumers']} consumers, "
            f"{crowd['visits']} visits, {crowd['redemptions']} redemptions."
        )
        print("Generated logins use password: demo1234")
    finally:
        await db.close()


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(description="Seed London shops and a simulated crowd for WayFarer")
    parser.add_argument("--shop-limit", type=int, default=1200, help="Maximum number of London shops to register")
    parser.add_argument("--consumer-count", type=int, default=1800, help="Number of synthetic consumers to create")
    parser.add_argument("--wallet-cents", type=int, default=15000, help="Initial merchant wallet balance in cents")
    parser.add_argument("--tile-step-lat", type=float, default=0.045, help="Latitude size per OSM tile")
    parser.add_argument("--tile-step-lng", type=float, default=0.060, help="Longitude size per OSM tile")
    parser.add_argument("--clear-generated", action="store_true", help="Delete previously generated London demo data first")
    parser.add_argument("--dry-run", action="store_true", help="Fetch and preview OSM venues without writing to the database")
    return parser.parse_args()


if __name__ == "__main__":
    asyncio.run(run(parse_args()))
