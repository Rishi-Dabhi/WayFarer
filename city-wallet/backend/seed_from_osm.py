"""
Pre-demo shop registration from OSM data.

Queries OpenStreetMap for real nearby venues and registers them as
fully-configured merchants in the City Wallet database — including
a merchant wallet with €50 balance so cashback works immediately.

Usage:
    python seed_from_osm.py                          # Stuttgart centre (default)
    python seed_from_osm.py --lat 48.778 --lng 9.180 --radius 400
    python seed_from_osm.py --lat 48.778 --lng 9.180 --dry-run

Run this 5-10 minutes before your demo. Re-running is safe — existing
shops (matched by OSM ID) are skipped.
"""

import asyncio
import argparse
import json
import re
import aiosqlite
from passlib.context import CryptContext
from services.osm_service import get_nearby_pois
from config import settings

_pwd = CryptContext(schemes=["bcrypt"], deprecated="auto")

# Default products per category — used when OSM has no product info
_DEFAULT_PRODUCTS: dict[str, list[dict]] = {
    "cafe": [
        {"name": "Flat White", "price_cents": 380, "stock_level": "normal"},
        {"name": "Cappuccino", "price_cents": 340, "stock_level": "high"},
        {"name": "Croissant", "price_cents": 290, "stock_level": "high"},
        {"name": "Oat Latte", "price_cents": 420, "stock_level": "normal"},
    ],
    "restaurant": [
        {"name": "Lunch Special", "price_cents": 1290, "stock_level": "normal"},
        {"name": "House Salad", "price_cents": 890, "stock_level": "high"},
        {"name": "Sparkling Water", "price_cents": 280, "stock_level": "high"},
    ],
    "bar": [
        {"name": "House Beer", "price_cents": 480, "stock_level": "normal"},
        {"name": "Glass of Wine", "price_cents": 590, "stock_level": "normal"},
        {"name": "Soft Drink", "price_cents": 280, "stock_level": "high"},
    ],
    "retail": [
        {"name": "Featured Item", "price_cents": 1990, "stock_level": "normal"},
        {"name": "Gift Voucher", "price_cents": 2500, "stock_level": "low"},
    ],
}

_CAMPAIGN_GOAL_BY_CATEGORY: dict[str, str] = {
    "cafe": "fill_quiet_hours",
    "restaurant": "fill_quiet_hours",
    "bar": "new_customers",
    "retail": "clear_stock",
}

_QUIET_HOURS_BY_CATEGORY: dict[str, list[str]] = {
    "cafe": ["09:00-11:00", "14:00-16:00"],
    "restaurant": ["15:00-17:00"],
    "bar": ["16:00-19:00"],
    "retail": ["14:00-16:00"],
}


def _slug(name: str) -> str:
    return re.sub(r"[^a-z0-9]", "", name.lower())[:20]


async def seed(lat: float, lng: float, radius_m: float, dry_run: bool) -> None:
    pois = await get_nearby_pois(lat, lng, radius_m)
    if not pois:
        print("No OSM POIs found. Check your coordinates or increase --radius.")
        print("Try a larger radius, for example:")
        print(f"  python seed_from_osm.py --lat {lat} --lng {lng} --radius 1500 --dry-run")
        print("If that still returns nothing, Overpass may be temporarily unavailable.")
        return

    print(f"\nFound {len(pois)} venues within {int(radius_m)}m of ({lat}, {lng})\n")

    db = await aiosqlite.connect(settings.database_url)
    db.row_factory = aiosqlite.Row
    await db.execute("PRAGMA foreign_keys=ON")

    # Ensure schema exists
    from pathlib import Path
    schema = (Path(__file__).parent / "schema.sql").read_text()
    await db.executescript(schema)
    await db.commit()

    registered = 0
    skipped = 0

    for poi in pois:
        osm_id = poi["osm_id"]
        name = poi["name"]
        category = poi["category"]
        email = f"osm_{_slug(name)}_{osm_id}@citywallet.demo"

        # Check if already registered (by email to avoid duplicates on re-run)
        async with db.execute("SELECT id FROM users WHERE email=?", (email,)) as cur:
            existing = await cur.fetchone()
        if existing:
            print(f"  SKIP  {name:35s} (already registered)")
            skipped += 1
            continue

        address = poi.get("address", "").strip() or poi.get("name", "")
        products = _DEFAULT_PRODUCTS.get(category, _DEFAULT_PRODUCTS["retail"])
        quiet_hours = _QUIET_HOURS_BY_CATEGORY.get(category, ["14:00-16:00"])
        campaign_goal = _CAMPAIGN_GOAL_BY_CATEGORY.get(category, "fill_quiet_hours")

        if dry_run:
            print(
                f"  DRY   {name:35s} [{category:10s}] {poi['distance_m']:4d}m  "
                f"{len(products)} products"
            )
            registered += 1
            continue

        # Create merchant user
        async with db.execute(
            "INSERT INTO users (email, password_hash, role, name) VALUES (?,?,?,?)",
            (email, _pwd.hash("demo1234"), "merchant", name),
        ) as cur:
            merchant_id = cur.lastrowid

        # Merchant wallet — €50 starting balance so cashback works on day 1
        await db.execute(
            "INSERT INTO merchant_wallets (merchant_id, balance_cents) VALUES (?,?)",
            (merchant_id, 5000),
        )

        # Shop
        async with db.execute(
            """INSERT INTO shops
               (merchant_id, name, description, category, latitude, longitude, address,
                target_quiet_hours, max_discount_pct, cashback_budget_per_coupon_cents,
                campaign_goal)
               VALUES (?,?,?,?,?,?,?,?,?,?,?)""",
            (
                merchant_id,
                name,
                f"Local {category} in {address or 'the city centre'}",
                category,
                poi["lat"],
                poi["lng"],
                address,
                json.dumps(quiet_hours),
                20,
                300,
                campaign_goal,
            ),
        ) as cur:
            shop_id = cur.lastrowid

        # Default products
        for p in products:
            await db.execute(
                "INSERT INTO products (shop_id, name, price_cents, category, stock_level) VALUES (?,?,?,?,?)",
                (shop_id, p["name"], p["price_cents"], category, p["stock_level"]),
            )

        await db.commit()
        print(
            f"  OK    {name:35s} [{category:10s}] {poi['distance_m']:4d}m  "
            f"login: {email} / demo1234"
        )
        registered += 1

    await db.close()

    action = "Would register" if dry_run else "Registered"
    print(f"\n{action} {registered} shops, skipped {skipped} existing.\n")
    if not dry_run and registered > 0:
        print("These shops are now live in City Wallet.")
        print("Their merchant accounts all use password: demo1234\n")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Seed City Wallet with real OSM shops")
    parser.add_argument("--lat", type=float, default=48.7784, help="Demo latitude")
    parser.add_argument("--lng", type=float, default=9.1800, help="Demo longitude")
    parser.add_argument("--radius", type=float, default=1000, help="Search radius in metres")
    parser.add_argument("--dry-run", action="store_true", help="Preview without writing to DB")
    args = parser.parse_args()

    asyncio.run(seed(args.lat, args.lng, args.radius, args.dry_run))
