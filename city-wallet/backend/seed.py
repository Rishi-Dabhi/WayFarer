"""Seed demo data for the hackathon presentation."""
import json
import random
from datetime import datetime, timedelta
from database import get_db
from services.qr_service import generate_qr_token
from passlib.context import CryptContext

_pwd = CryptContext(schemes=["bcrypt"], deprecated="auto")
_rng = random.Random(42)  # deterministic so every fresh DB looks the same

DEMO_LAT = 48.7784
DEMO_LNG = 9.1800


# ─── coupon templates ────────────────────────────────────────────────────────
# (headline, why_now, discount_pct, product_index 0-4)
_TEMPLATES = [
    ("Warm up. 85 metres away.",            "Cold weather + quiet period detected.",         15, 0),
    ("Morning rush just ended. Grab a seat.","Post-rush quiet window.",                       10, 1),
    ("Quiet afternoon. Perfect for focus.", "Low Payone txn count for 45 min.",              12, 4),
    ("Lunch crowd cleared — best seats free.","Lunch rush ended, capacity drops.",            18, 2),
    ("Today's pastries still fresh.",       "High croissant stock, low foot traffic.",       12, 3),
    ("Cold outside. Hot inside.",           "Sub-10 °C weather, café warm.",                 15, 0),
    ("Beat the afternoon slump.",           "14:00 quiet hour triggered.",                   10, 1),
    ("Your oat latte at a friendlier price.","Quiet Tuesday afternoon.",                     12, 4),
    ("11 °C and grey — toast time.",        "Rain + cold weather combo.",                    18, 2),
    ("One croissant away from a better day.","Morning stock clearing.",                      10, 3),
    ("Start the day right, 3 minutes walk.","Early morning quiet period.",                   12, 0),
    ("That mid-morning moment.",            "Between breakfast and lunch rush.",              15, 1),
    ("Recharge before the commute.",        "Evening peak approaching.",                     10, 0),
    ("Friday afternoon treat.",             "End-of-week quiet slot.",                       18, 2),
    ("Rainy day? We've got your back.",     "Precipitation + low traffic.",                  15, 4),
]

# Product index → weight (Flat White most popular)
_PRODUCT_WEIGHTS = [0.38, 0.24, 0.18, 0.12, 0.08]

# Unique visitors per day for days 13 → 0 (today) ago
_DAILY_VISITORS = [3, 4, 5, 4, 7, 8, 6, 10, 11, 9, 13, 12, 15, 8]

# Coupons per day for days 13 → 0 ago
_DAILY_COUPONS  = [6, 7, 8, 7, 10, 12, 9, 14, 15, 12, 17, 16, 18, 12]

# Hourly slots for today's coupons (makes the bar chart look realistic)
_TODAY_HOURS = [8, 9, 9, 10, 10, 10, 11, 11, 12, 12, 12, 13]  # 12 coupons

_CTX = json.dumps({
    "weather": {"temp": 11, "feels_like": 8, "condition": "overcast clouds"},
    "time": {"period": "afternoon", "day_of_week": "Friday"},
    "source": "backend_auto_rule",
    "offer_engine_version": 4,
})


async def seed_if_empty() -> None:
    db = await get_db()
    async with db.execute("SELECT COUNT(*) as c FROM users") as cur:
        if (await cur.fetchone())["c"] > 0:
            return

    print("Seeding demo data…")
    now = datetime.utcnow()

    # ── merchant ─────────────────────────────────────────────────────────────
    async with db.execute(
        "INSERT INTO users (email,password_hash,role,name) VALUES (?,?,?,?)",
        ("merchant@demo.com", _pwd.hash("demo1234"), "merchant", "Café Kern"),
    ) as cur:
        merchant_id = cur.lastrowid

    # ── consumers ────────────────────────────────────────────────────────────
    async with db.execute(
        "INSERT INTO users (email,password_hash,role,name,stripe_account_id) VALUES (?,?,?,?,?)",
        ("user@demo.com", _pwd.hash("demo1234"), "consumer", "Mia Schmidt", ""),
    ) as cur:
        primary_consumer = cur.lastrowid

    await db.execute(
        "INSERT INTO user_preferences (user_id,category_affinity,active_hours) VALUES (?,?,?)",
        (primary_consumer, json.dumps({"cafe": 0.8, "retail": 0.3}), json.dumps([9, 12, 17])),
    )

    _extra_names = [
        ("Lena Bauer", "lena"), ("Jonas Weber", "jonas"), ("Sophie Klein", "sophie"),
        ("Lukas Müller", "lukas"), ("Hannah Fischer", "hannah"), ("Tobias Wagner", "tobias"),
        ("Emma Schulz", "emma"), ("Felix Braun", "felix"), ("Laura Hoffmann", "laura"),
        ("Max Schröder", "max"),
    ]
    consumer_ids = [primary_consumer]
    for full_name, short in _extra_names:
        async with db.execute(
            "INSERT INTO users (email,password_hash,role,name) VALUES (?,?,?,?)",
            (f"{short}@demo.com", _pwd.hash("demo1234"), "consumer", full_name),
        ) as cur:
            consumer_ids.append(cur.lastrowid)

    # ── wallet (rich enough for demo) ────────────────────────────────────────
    await db.execute(
        "INSERT INTO merchant_wallets (merchant_id,balance_cents) VALUES (?,?)",
        (merchant_id, 50000),  # €500
    )
    for days_ago, amount_cents, pi in [
        (12, 20000, "pi_demo_a"), (5, 15000, "pi_demo_b"), (1, 20000, "pi_demo_c"),
    ]:
        ts = (now - timedelta(days=days_ago)).isoformat()
        await db.execute(
            "INSERT INTO wallet_topups (merchant_id,amount_cents,stripe_payment_intent,status,created_at)"
            " VALUES (?,?,?,'succeeded',?)",
            (merchant_id, amount_cents, pi, ts),
        )

    # ── shops ────────────────────────────────────────────────────────────────
    async with db.execute(
        """INSERT INTO shops
           (merchant_id,name,description,category,latitude,longitude,address,
            target_quiet_hours,max_discount_pct,cashback_budget_per_coupon_cents,campaign_goal)
           VALUES (?,?,?,?,?,?,?,?,?,?,?)""",
        (
            merchant_id, "Café Kern",
            "Cosy independent café in the Altstadt, known for great espresso and homemade cakes.",
            "cafe", DEMO_LAT + 0.0005, DEMO_LNG + 0.0003,
            "Kirchstraße 4, Stuttgart Altstadt",
            json.dumps(["14:00-16:00", "09:00-11:00"]), 20, 200, "fill_quiet_hours",
        ),
    ) as cur:
        shop_id = cur.lastrowid

    async with db.execute(
        """INSERT INTO shops
           (merchant_id,name,description,category,latitude,longitude,address,
            target_quiet_hours,max_discount_pct,cashback_budget_per_coupon_cents,campaign_goal)
           VALUES (?,?,?,?,?,?,?,?,?,?,?)""",
        (
            merchant_id, "Studio Kern Books",
            "Independent bookshop and stationery store next to the café.",
            "retail", DEMO_LAT + 0.0008, DEMO_LNG - 0.0002,
            "Kirchstraße 6, Stuttgart Altstadt",
            json.dumps(["15:00-17:00"]), 15, 150, "clear_stock",
        ),
    ) as cur:
        shop2_id = cur.lastrowid

    # ── products ─────────────────────────────────────────────────────────────
    _product_defs = [
        ("Flat White",    "Silky espresso with steamed milk",               380, "coffee", "normal"),
        ("Cappuccino",    "Classic Italian foam coffee",                     340, "coffee", "high"),
        ("Avocado Toast", "Sourdough with smashed avocado, chilli flakes",  890, "food",   "normal"),
        ("Croissant",     "Buttery fresh-baked pastry",                      290, "food",   "high"),
        ("Oat Latte",     "Espresso with organic oat milk",                  420, "coffee", "low"),
    ]
    product_ids: list[int] = []
    product_prices: list[int] = []
    for name, desc, price, cat, stock in _product_defs:
        async with db.execute(
            "INSERT INTO products (shop_id,name,description,price_cents,category,stock_level)"
            " VALUES (?,?,?,?,?,?)",
            (shop_id, name, desc, price, cat, stock),
        ) as cur:
            product_ids.append(cur.lastrowid)
            product_prices.append(price)

    # ── payone density (busyness signal for last 2 h) ────────────────────────
    for mins_ago in range(120, 0, -5):
        ts = (now - timedelta(minutes=mins_ago)).isoformat()
        hour = (now - timedelta(minutes=mins_ago)).hour
        pattern = {9:3,10:5,11:8,12:14,13:16,14:4,15:3,16:5,17:9,18:12,19:10}
        count = pattern.get(hour, 3)
        await db.execute(
            "INSERT INTO payone_density (shop_id,txn_count,recorded_at) VALUES (?,?,?)",
            (shop_id, count, ts),
        )
        await db.execute(
            "INSERT INTO payone_density (shop_id,txn_count,recorded_at) VALUES (?,?,?)",
            (shop2_id, max(0, count - 2), ts),
        )

    # ── historical data: days 13 → 1 ago ────────────────────────────────────
    total_cashback_paid = 0

    for day_idx, days_ago in enumerate(range(13, 0, -1)):
        day_dt = (now - timedelta(days=days_ago)).replace(
            hour=0, minute=0, second=0, microsecond=0
        )
        date_str = day_dt.strftime("%Y-%m-%d")
        num_visitors = _DAILY_VISITORS[day_idx]
        num_coupons  = _DAILY_COUPONS[day_idx]

        # Shop visits for this day
        day_consumers = _rng.sample(consumer_ids, min(num_visitors, len(consumer_ids)))
        for uid in day_consumers:
            vh = _rng.choice([9,10,11,12,13,14,15,16,17,18])
            vm = _rng.randint(0, 59)
            visit_ts = day_dt.replace(hour=vh, minute=vm)
            await db.execute(
                "INSERT OR IGNORE INTO shop_visits (shop_id,user_id,entered_at,visit_date)"
                " VALUES (?,?,?,?)",
                (shop_id, uid, visit_ts.isoformat(), date_str),
            )

        # Coupons for this day
        for _ in range(num_coupons):
            tmpl = _rng.choices(_TEMPLATES, k=1)[0]
            headline, why_now, discount_pct, prod_idx = tmpl
            prod_idx = _rng.choices(range(len(product_ids)), weights=_PRODUCT_WEIGHTS)[0]
            pid = product_ids[prod_idx]
            price = product_prices[prod_idx]
            cashback = round(price * discount_pct / 100)

            gen_hour = _rng.choice([8,9,9,10,10,11,12,12,13,14,15,16,17])
            gen_ts   = day_dt.replace(hour=gen_hour, minute=_rng.randint(0,59))
            exp_ts   = (gen_ts + timedelta(hours=2)).isoformat()
            uid      = _rng.choice(consumer_ids)
            redeemed = _rng.random() < 0.44  # 44 % redemption rate

            if redeemed:
                red_ts = (gen_ts + timedelta(minutes=_rng.randint(10, 90))).isoformat()
                async with db.execute(
                    """INSERT INTO coupons
                       (shop_id,user_id,headline,body_text,why_now,discount_pct,cashback_cents,
                        product_id,context_snapshot,qr_token,status,expires_at,generated_at,redeemed_at)
                       VALUES (?,?,?,?,?,?,?,?,?,?,'redeemed',?,?,?)""",
                    (shop_id, uid, headline,
                     f"Get {discount_pct}% off your {_product_defs[prod_idx][0]} at Café Kern.",
                     why_now, discount_pct, cashback, pid, _CTX,
                     generate_qr_token(), exp_ts, gen_ts.isoformat(), red_ts),
                ) as cur:
                    cid = cur.lastrowid
                await db.execute(
                    "INSERT INTO transactions (coupon_id,shop_id,user_id,cashback_cents,status,redeemed_at)"
                    " VALUES (?,?,?,?,'completed',?)",
                    (cid, shop_id, uid, cashback, red_ts),
                )
                # Also record purchase event
                await db.execute(
                    """INSERT INTO purchase_events
                       (user_id,shop_id,coupon_id,product_id,amount_cents,cashback_cents,discount_pct,source,purchased_at)
                       VALUES (?,?,?,?,?,?,?,'qr_redemption',?)""",
                    (uid, shop_id, cid, pid, price, cashback, discount_pct, red_ts),
                )
                total_cashback_paid += cashback
            else:
                status = "expired" if days_ago > 0 else "active"
                await db.execute(
                    """INSERT INTO coupons
                       (shop_id,user_id,headline,body_text,why_now,discount_pct,cashback_cents,
                        product_id,context_snapshot,qr_token,status,expires_at,generated_at)
                       VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)""",
                    (shop_id, uid, headline,
                     f"Get {discount_pct}% off your {_product_defs[prod_idx][0]} at Café Kern.",
                     why_now, discount_pct, cashback, pid, _CTX,
                     generate_qr_token(), status, exp_ts, gen_ts.isoformat()),
                )

    # ── today's coupons (with realistic hourly spread) ────────────────────────
    today = now.replace(hour=0, minute=0, second=0, microsecond=0)
    date_str_today = today.strftime("%Y-%m-%d")

    # Visits today
    today_visitors = _rng.sample(consumer_ids, min(_DAILY_VISITORS[-1], len(consumer_ids)))
    for uid in today_visitors:
        vh = _rng.choice([8, 9, 10, 11, 12, 13])
        visit_ts = today.replace(hour=vh, minute=_rng.randint(0, 59))
        await db.execute(
            "INSERT OR IGNORE INTO shop_visits (shop_id,user_id,entered_at,visit_date) VALUES (?,?,?,?)",
            (shop_id, uid, visit_ts.isoformat(), date_str_today),
        )

    redeemed_today = 0
    for i, gen_hour in enumerate(_TODAY_HOURS):
        tmpl = _TEMPLATES[i % len(_TEMPLATES)]
        headline, why_now, discount_pct, _ = tmpl
        prod_idx = _rng.choices(range(len(product_ids)), weights=_PRODUCT_WEIGHTS)[0]
        pid = product_ids[prod_idx]
        price = product_prices[prod_idx]
        cashback = round(price * discount_pct / 100)

        gen_ts = today.replace(hour=gen_hour, minute=_rng.randint(5, 55))
        exp_ts = (gen_ts + timedelta(hours=2)).isoformat()
        uid = _rng.choice(consumer_ids)

        # First 5 are redeemed (gives nice "5 redemptions today")
        if i < 5:
            red_ts = (gen_ts + timedelta(minutes=_rng.randint(8, 60))).isoformat()
            async with db.execute(
                """INSERT INTO coupons
                   (shop_id,user_id,headline,body_text,why_now,discount_pct,cashback_cents,
                    product_id,context_snapshot,qr_token,status,expires_at,generated_at,redeemed_at)
                   VALUES (?,?,?,?,?,?,?,?,?,?,'redeemed',?,?,?)""",
                (shop_id, uid, headline,
                 f"Get {discount_pct}% off your {_product_defs[prod_idx][0]} at Café Kern.",
                 why_now, discount_pct, cashback, pid, _CTX,
                 generate_qr_token(), exp_ts, gen_ts.isoformat(), red_ts),
            ) as cur:
                cid = cur.lastrowid
            await db.execute(
                "INSERT INTO transactions (coupon_id,shop_id,user_id,cashback_cents,status,redeemed_at)"
                " VALUES (?,?,?,?,'completed',?)",
                (cid, shop_id, uid, cashback, red_ts),
            )
            await db.execute(
                """INSERT INTO purchase_events
                   (user_id,shop_id,coupon_id,product_id,amount_cents,cashback_cents,discount_pct,source,purchased_at)
                   VALUES (?,?,?,?,?,?,?,'qr_redemption',?)""",
                (uid, shop_id, cid, pid, price, cashback, discount_pct, red_ts),
            )
            total_cashback_paid += cashback
            redeemed_today += 1
        else:
            # Active coupons for today
            async with db.execute(
                """INSERT INTO coupons
                   (shop_id,user_id,headline,body_text,why_now,discount_pct,cashback_cents,
                    product_id,context_snapshot,qr_token,status,expires_at,generated_at)
                   VALUES (?,?,?,?,?,?,?,?,?,?,'active',?,?)""",
                (shop_id, uid, headline,
                 f"Get {discount_pct}% off your {_product_defs[prod_idx][0]} at Café Kern.",
                 why_now, discount_pct, cashback, pid, _CTX,
                 generate_qr_token(), exp_ts, gen_ts.isoformat()),
            ) as cur:
                cid = cur.lastrowid

    # ── one pre-built active coupon for the demo consumer wallet ────────────
    token = generate_qr_token()
    expires = (now + timedelta(hours=2)).isoformat()
    await db.execute(
        """INSERT INTO coupons
           (shop_id,user_id,headline,body_text,why_now,discount_pct,cashback_cents,
            product_id,context_snapshot,qr_token,status,expires_at,generated_at)
           VALUES (?,?,?,?,?,?,?,?,?,?,'active',?,?)""",
        (
            shop_id, primary_consumer,
            "Warm up. 85 metres away.",
            "It's grey and 11 °C out there, and Café Kern has been unusually quiet all afternoon — "
            "which means a great seat and no queue. Your flat white is 15% off for the next 2 hours.",
            "Payone data shows only 3 transactions in the last 15 min (typical: 12). "
            "Created for this quiet Friday afternoon window.",
            15, 57,
            product_ids[0], _CTX, token, expires, now.isoformat(),
        ),
    )

    await db.commit()
    print(
        f"Demo data seeded — merchant@demo.com / user@demo.com (pw: demo1234)\n"
        f"  Shop visits: {sum(_DAILY_VISITORS)} across 14 days\n"
        f"  Coupons: {sum(_DAILY_COUPONS) + len(_TODAY_HOURS) + 1} total\n"
        f"  Total cashback paid: €{total_cashback_paid / 100:.2f}"
    )
