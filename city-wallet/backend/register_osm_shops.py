"""
Register real nearby venues from OpenStreetMap as WayFarer shops.

This creates WayFarer merchant/shop/product rows for real OSM venues near
the coordinates you provide. It does not create demo consumers or coupons.

Usage:
    python register_osm_shops.py --lat 51.505 --lng -0.090 --radius 1200 --dry-run
    python register_osm_shops.py --lat 51.505 --lng -0.090 --radius 1200 --limit 25
"""

import argparse
import asyncio
import json
import re
from datetime import datetime
from pathlib import Path

import aiosqlite
from passlib.context import CryptContext

from config import settings
from services.osm_service import get_nearby_pois

_pwd = CryptContext(schemes=["bcrypt"], deprecated="auto")

_PRODUCTS_BY_CATEGORY: dict[str, list[dict[str, object]]] = {
    "cafe": [
        {"name": "Coffee", "price_cents": 350, "stock_level": "normal"},
        {"name": "Tea", "price_cents": 300, "stock_level": "normal"},
        {"name": "Pastry", "price_cents": 325, "stock_level": "high"},
    ],
    "restaurant": [
        {"name": "Lunch Item", "price_cents": 1200, "stock_level": "normal"},
        {"name": "Side", "price_cents": 450, "stock_level": "high"},
        {"name": "Drink", "price_cents": 300, "stock_level": "high"},
    ],
    "bar": [
        {"name": "House Drink", "price_cents": 600, "stock_level": "normal"},
        {"name": "Snack", "price_cents": 500, "stock_level": "normal"},
    ],
    "retail": [
        {"name": "Featured Item", "price_cents": 1500, "stock_level": "normal"},
        {"name": "Small Item", "price_cents": 500, "stock_level": "high"},
    ],
}

_QUIET_HOURS_BY_CATEGORY: dict[str, list[str]] = {
    "cafe": ["09:00-11:00", "14:00-16:00"],
    "restaurant": ["15:00-17:00"],
    "bar": ["16:00-19:00"],
    "retail": ["14:00-16:00"],
}


def _slug(value: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", value.lower()).strip("-")
    return slug[:40] or "shop"


def _address(poi: dict) -> str:
    address = (poi.get("address") or "").strip()
    return address if address else "Address from OpenStreetMap unavailable"


def _is_open_now(opening_hours: str, now: datetime | None = None) -> bool:
    """Small parser for common OSM opening_hours values.

    OSM opening_hours is a rich format; this supports the common cases we need
    for demo seeding and treats unknown formats as closed when --open-now is set.
    """
    value = opening_hours.strip()
    if not value:
        return False
    if value == "24/7":
        return True
    if "off" in value.lower():
        return False

    now = now or datetime.now()
    day = now.weekday()
    current_minutes = now.hour * 60 + now.minute
    day_names = ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
    day_name = day_names[day]

    for part in value.split(";"):
        part = part.strip()
        if not part or "off" in part.lower():
            continue

        day_ok = True
        time_part = part
        if " " in part:
            day_part, time_part = part.split(" ", 1)
            days: set[str] = set()
            for token in day_part.split(","):
                token = token.strip()
                if "-" in token:
                    start, end = token.split("-", 1)
                    if start in day_names and end in day_names:
                        start_i = day_names.index(start)
                        end_i = day_names.index(end)
                        if start_i <= end_i:
                            days.update(day_names[start_i : end_i + 1])
                        else:
                            days.update(day_names[start_i:] + day_names[: end_i + 1])
                elif token in day_names:
                    days.add(token)
            day_ok = not days or day_name in days

        if not day_ok:
            continue

        for time_range in time_part.split(","):
            match = re.fullmatch(r"(\d{1,2}):(\d{2})-(\d{1,2}):(\d{2})", time_range.strip())
            if not match:
                continue
            start_h, start_m, end_h, end_m = map(int, match.groups())
            start = start_h * 60 + start_m
            end = end_h * 60 + end_m
            if start <= end and start <= current_minutes <= end:
                return True
            if start > end and (current_minutes >= start or current_minutes <= end):
                return True

    return False


async def _prepare_db() -> aiosqlite.Connection:
    db = await aiosqlite.connect(settings.database_url)
    db.row_factory = aiosqlite.Row
    await db.execute("PRAGMA foreign_keys=ON")
    await db.executescript((Path(__file__).parent / "schema.sql").read_text())
    await db.commit()
    return db


async def register_shops(
    lat: float,
    lng: float,
    radius: float,
    limit: int,
    dry_run: bool,
    wallet_eur: float,
    merchant_password: str,
    open_now: bool,
    clear_osm: bool,
) -> None:
    candidates = await get_nearby_pois(lat, lng, radius, limit=max(limit * 4, 80))
    if open_now:
        candidates = [poi for poi in candidates if _is_open_now(str(poi.get("opening_hours") or ""))]
    pois = candidates[:limit]
    if not pois:
        print("No matching OSM venues found. Try increasing --radius or omit --open-now.")
        return

    print(f"Found {len(pois)} venues near ({lat}, {lng}) within {int(radius)}m.")
    db = await _prepare_db()

    if clear_osm and not dry_run:
        async with db.execute("SELECT id FROM users WHERE email LIKE 'osm-%@citywallet.local'") as cur:
            merchant_rows = await cur.fetchall()
        merchant_ids = [row["id"] for row in merchant_rows]
        if merchant_ids:
            placeholders = ",".join("?" for _ in merchant_ids)
            async with db.execute(f"SELECT id FROM shops WHERE merchant_id IN ({placeholders})", merchant_ids) as cur:
                shop_rows = await cur.fetchall()
            shop_ids = [row["id"] for row in shop_rows]
            if shop_ids:
                shop_placeholders = ",".join("?" for _ in shop_ids)
                await db.execute(f"DELETE FROM payone_density WHERE shop_id IN ({shop_placeholders})", shop_ids)
                await db.execute(f"DELETE FROM transactions WHERE shop_id IN ({shop_placeholders})", shop_ids)
                await db.execute(f"DELETE FROM coupons WHERE shop_id IN ({shop_placeholders})", shop_ids)
                await db.execute(f"DELETE FROM products WHERE shop_id IN ({shop_placeholders})", shop_ids)
                await db.execute(f"DELETE FROM shops WHERE id IN ({shop_placeholders})", shop_ids)
            await db.execute(f"DELETE FROM merchant_wallets WHERE merchant_id IN ({placeholders})", merchant_ids)
            await db.execute(f"DELETE FROM users WHERE id IN ({placeholders})", merchant_ids)
            await db.commit()
            print(f"Cleared {len(merchant_ids)} existing OSM merchant accounts.")

    registered = 0
    skipped = 0
    for poi in pois:
        name = poi["name"]
        category = poi["category"]
        email = f"osm-{poi['osm_id']}-{_slug(name)}@citywallet.local"

        async with db.execute("SELECT id FROM users WHERE email=?", (email,)) as cur:
            existing = await cur.fetchone()
        if existing:
            print(f"SKIP  {name} ({poi['distance_m']}m) already registered")
            skipped += 1
            continue

        products = _PRODUCTS_BY_CATEGORY.get(category, _PRODUCTS_BY_CATEGORY["retail"])
        if dry_run:
            hours = poi.get("opening_hours") or "unknown hours"
            print(f"DRY   {name} [{category}] {poi['distance_m']}m ({hours})")
            registered += 1
            continue

        async with db.execute(
            "INSERT INTO users (email, password_hash, role, name) VALUES (?,?,?,?)",
            (email, _pwd.hash(merchant_password), "merchant", name),
        ) as cur:
            merchant_id = cur.lastrowid

        await db.execute(
            "INSERT INTO merchant_wallets (merchant_id, balance_cents) VALUES (?,?)",
            (merchant_id, round(wallet_eur * 100)),
        )

        async with db.execute(
            """INSERT INTO shops
               (merchant_id, name, description, category, latitude, longitude, address,
                target_quiet_hours, max_discount_pct, cashback_budget_per_coupon_cents,
                campaign_goal, auto_coupon_enabled, auto_trigger_radius_m)
               VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)""",
            (
                merchant_id,
                name,
                f"Real OpenStreetMap venue registered near your current location.",
                category,
                poi["lat"],
                poi["lng"],
                _address(poi),
                json.dumps(_QUIET_HOURS_BY_CATEGORY.get(category, ["14:00-16:00"])),
                20,
                300,
                "fill_quiet_hours",
                1,
                min(round(radius), 2000),
            ),
        ) as cur:
            shop_id = cur.lastrowid

        for product in products:
            await db.execute(
                "INSERT INTO products (shop_id, name, price_cents, category, stock_level) VALUES (?,?,?,?,?)",
                (
                    shop_id,
                    product["name"],
                    product["price_cents"],
                    category,
                    product["stock_level"],
                ),
            )

        await db.commit()
        hours = poi.get("opening_hours") or "unknown hours"
        print(f"OK    {name} [{category}] {poi['distance_m']}m ({hours})")
        registered += 1

    await db.close()
    action = "Would register" if dry_run else "Registered"
    print(f"{action} {registered}; skipped {skipped}.")


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description="Register real nearby OSM shops in WayFarer")
    parser.add_argument("--lat", type=float, required=True, help="Latitude near your current location")
    parser.add_argument("--lng", type=float, required=True, help="Longitude near your current location")
    parser.add_argument("--radius", type=float, default=1200, help="Search radius in metres")
    parser.add_argument("--limit", type=int, default=30, help="Maximum shops to register")
    parser.add_argument("--wallet-eur", type=float, default=50, help="Initial merchant wallet balance")
    parser.add_argument("--merchant-password", default="changeme123", help="Password for generated merchant accounts")
    parser.add_argument("--open-now", action="store_true", help="Only register venues OSM says are open right now")
    parser.add_argument("--clear-osm", action="store_true", help="Delete previously generated OSM shops before registering")
    parser.add_argument("--dry-run", action="store_true", help="Preview venues without writing to the DB")
    args = parser.parse_args()

    asyncio.run(
        register_shops(
            lat=args.lat,
            lng=args.lng,
            radius=args.radius,
            limit=args.limit,
            dry_run=args.dry_run,
            wallet_eur=args.wallet_eur,
            merchant_password=args.merchant_password,
            open_now=args.open_now,
            clear_osm=args.clear_osm,
        )
    )
