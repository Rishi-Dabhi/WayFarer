"""Seed demo data for the hackathon presentation."""
import json
from datetime import datetime, timedelta
from database import get_db
from services.qr_service import generate_qr_token
from passlib.context import CryptContext

_pwd = CryptContext(schemes=["bcrypt"], deprecated="auto")

# Stuttgart city centre coordinates
DEMO_LAT = 48.7784
DEMO_LNG = 9.1800


async def seed_if_empty():
    db = await get_db()
    async with db.execute("SELECT COUNT(*) as c FROM users") as cur:
        count = (await cur.fetchone())["c"]
    if count > 0:
        return  # Already seeded

    print("Seeding demo data...")

    # Merchant user
    async with db.execute(
        "INSERT INTO users (email, password_hash, role, name) VALUES (?,?,?,?)",
        ("merchant@demo.com", _pwd.hash("demo1234"), "merchant", "Café Kern"),
    ) as cur:
        merchant_id = cur.lastrowid

    await db.execute("INSERT INTO merchant_wallets (merchant_id, balance_cents) VALUES (?,?)", (merchant_id, 5000))

    # Consumer user
    async with db.execute(
        "INSERT INTO users (email, password_hash, role, name, stripe_account_id) VALUES (?,?,?,?,?)",
        ("user@demo.com", _pwd.hash("demo1234"), "consumer", "Mia Schmidt", ""),
    ) as cur:
        consumer_id = cur.lastrowid

    await db.execute(
        "INSERT INTO user_preferences (user_id, category_affinity, active_hours) VALUES (?,?,?)",
        (consumer_id, json.dumps({"cafe": 0.8, "retail": 0.3}), json.dumps(["12:00-14:00", "17:00-19:00"])),
    )

    # Shop — very close to demo coords
    async with db.execute(
        """INSERT INTO shops
           (merchant_id,name,description,category,latitude,longitude,address,
            target_quiet_hours,max_discount_pct,cashback_budget_per_coupon_cents,campaign_goal)
           VALUES (?,?,?,?,?,?,?,?,?,?,?)""",
        (
            merchant_id,
            "Café Kern",
            "Cosy independent café in the Altstadt, known for great espresso and homemade cakes",
            "cafe",
            DEMO_LAT + 0.0005,  # ~50m north
            DEMO_LNG + 0.0003,
            "Kirchstraße 4, Stuttgart Altstadt",
            json.dumps(["14:00-16:00", "09:00-11:00"]),
            20,
            200,
            "fill_quiet_hours",
        ),
    ) as cur:
        shop_id = cur.lastrowid

    # Second shop (retail)
    async with db.execute(
        """INSERT INTO shops
           (merchant_id,name,description,category,latitude,longitude,address,
            target_quiet_hours,max_discount_pct,cashback_budget_per_coupon_cents,campaign_goal)
           VALUES (?,?,?,?,?,?,?,?,?,?,?)""",
        (
            merchant_id,
            "Studio Kern Books",
            "Independent bookshop and stationery store next to the café",
            "retail",
            DEMO_LAT + 0.0008,
            DEMO_LNG - 0.0002,
            "Kirchstraße 6, Stuttgart Altstadt",
            json.dumps(["15:00-17:00"]),
            15,
            150,
            "clear_stock",
        ),
    ) as cur:
        shop2_id = cur.lastrowid

    # Products for Café Kern
    products = [
        ("Flat White", "Silky espresso with steamed milk", 380, "coffee", "normal"),
        ("Cappuccino", "Classic Italian foam coffee", 340, "coffee", "high"),
        ("Avocado Toast", "Sourdough with smashed avocado, chilli flakes", 890, "food", "normal"),
        ("Croissant", "Buttery fresh-baked pastry", 290, "food", "high"),
        ("Oat Latte", "Espresso with organic oat milk", 420, "coffee", "low"),
    ]
    product_ids = []
    for name, desc, price, cat, stock in products:
        async with db.execute(
            "INSERT INTO products (shop_id,name,description,price_cents,category,stock_level) VALUES (?,?,?,?,?,?)",
            (shop_id, name, desc, price, cat, stock),
        ) as cur:
            product_ids.append(cur.lastrowid)

    # Payone density — seed realistic pattern for the last 2 hours
    now = datetime.utcnow()
    for minutes_ago in range(120, 0, -5):
        ts = (now - timedelta(minutes=minutes_ago)).isoformat()
        hour = (now - timedelta(minutes=minutes_ago)).hour
        pattern = {9:3, 10:5, 11:8, 12:14, 13:16, 14:4, 15:3, 16:5, 17:9, 18:12, 19:10}
        count = pattern.get(hour, 3)
        await db.execute(
            "INSERT INTO payone_density (shop_id, txn_count, recorded_at) VALUES (?,?,?)",
            (shop_id, count, ts),
        )
        await db.execute(
            "INSERT INTO payone_density (shop_id, txn_count, recorded_at) VALUES (?,?,?)",
            (shop2_id, max(0, count - 2), ts),
        )

    # Pre-seed one active coupon for demo wallet
    token = generate_qr_token()
    expires = (datetime.utcnow() + timedelta(hours=2)).isoformat()
    context_snap = json.dumps({
        "weather": {"temp": 11, "feels_like": 8, "condition": "overcast clouds"},
        "time": {"period": "afternoon", "day_of_week": "Friday"},
        "nearby_shops": [{"name": "Café Kern", "busyness": "quiet"}],
    })
    await db.execute(
        """INSERT INTO coupons
           (shop_id,user_id,headline,body_text,why_now,discount_pct,cashback_cents,
            product_id,context_snapshot,qr_token,expires_at)
           VALUES (?,?,?,?,?,?,?,?,?,?,?)""",
        (
            shop_id, consumer_id,
            "Warm up. 85 metres away.",
            "It's grey and 11°C out there, and Café Kern has been unusually quiet all afternoon — "
            "which means a great seat and no queue. Your flat white is 15% off for the next 2 hours.",
            "Payone data shows only 3 transactions in the last 15 min (typical: 12). "
            "Created for this quiet Friday afternoon window.",
            15, 57,
            product_ids[0],
            context_snap, token, expires,
        ),
    )

    # Pre-seed one past transaction (for analytics demo)
    past_token = generate_qr_token()
    past_expires = (datetime.utcnow() - timedelta(hours=1)).isoformat()
    past_redeemed = (datetime.utcnow() - timedelta(minutes=45)).isoformat()
    async with db.execute(
        """INSERT INTO coupons
           (shop_id,user_id,headline,body_text,why_now,discount_pct,cashback_cents,
            product_id,context_snapshot,qr_token,status,expires_at,redeemed_at)
           VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)""",
        (
            shop_id, consumer_id,
            "Morning rush just ended. Grab a seat.",
            "The breakfast crowd has cleared and Café Kern is quiet — perfect time for a slow coffee.",
            "Post-morning-rush quiet window detected from Payone feed.",
            10, 38,
            product_ids[1],
            context_snap, past_token, "redeemed", past_expires, past_redeemed,
        ),
    ) as cur:
        past_coupon_id = cur.lastrowid

    await db.execute(
        "INSERT INTO transactions (coupon_id,shop_id,user_id,cashback_cents,status,redeemed_at) VALUES (?,?,?,?,?,?)",
        (past_coupon_id, shop_id, consumer_id, 38, "completed", past_redeemed),
    )

    await db.commit()
    print("Demo data seeded. merchant@demo.com / user@demo.com (password: demo1234)")
