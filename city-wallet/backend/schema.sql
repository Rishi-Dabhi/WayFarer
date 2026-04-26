CREATE TABLE IF NOT EXISTS users (
  id                  INTEGER PRIMARY KEY AUTOINCREMENT,
  email               TEXT UNIQUE NOT NULL,
  password_hash       TEXT NOT NULL,
  role                TEXT NOT NULL CHECK(role IN ('consumer','merchant')),
  name                TEXT,
  stripe_customer_id  TEXT,
  stripe_account_id   TEXT,
  expo_push_token     TEXT,
  created_at          TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS merchant_wallets (
  id              INTEGER PRIMARY KEY AUTOINCREMENT,
  merchant_id     INTEGER UNIQUE NOT NULL REFERENCES users(id),
  balance_cents   INTEGER NOT NULL DEFAULT 0,
  updated_at      TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS wallet_topups (
  id                    INTEGER PRIMARY KEY AUTOINCREMENT,
  merchant_id           INTEGER NOT NULL REFERENCES users(id),
  amount_cents          INTEGER NOT NULL,
  stripe_payment_intent TEXT,
  status                TEXT DEFAULT 'pending',
  created_at            TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS shops (
  id                               INTEGER PRIMARY KEY AUTOINCREMENT,
  merchant_id                      INTEGER NOT NULL REFERENCES users(id),
  name                             TEXT NOT NULL,
  description                      TEXT,
  category                         TEXT,
  latitude                         REAL NOT NULL,
  longitude                        REAL NOT NULL,
  address                          TEXT,
  target_quiet_hours               TEXT DEFAULT '["14:00-16:00"]',
  max_discount_pct                 INTEGER DEFAULT 20,
  cashback_budget_per_coupon_cents INTEGER DEFAULT 500,
  campaign_goal                    TEXT DEFAULT 'fill_quiet_hours',
  auto_coupon_enabled              INTEGER DEFAULT 1,
  auto_trigger_radius_m            INTEGER DEFAULT 200,
  quiet_threshold_ratio            REAL DEFAULT 0.6,
  coupon_frequency_minutes         INTEGER DEFAULT 60,
  is_active                        INTEGER DEFAULT 1
);

CREATE TABLE IF NOT EXISTS products (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  shop_id     INTEGER NOT NULL REFERENCES shops(id),
  name        TEXT NOT NULL,
  description TEXT,
  price_cents INTEGER NOT NULL,
  category    TEXT,
  stock_level TEXT CHECK(stock_level IN ('low','normal','high')) DEFAULT 'normal',
  is_active   INTEGER DEFAULT 1
);

CREATE TABLE IF NOT EXISTS coupons (
  id               INTEGER PRIMARY KEY AUTOINCREMENT,
  shop_id          INTEGER NOT NULL REFERENCES shops(id),
  user_id          INTEGER REFERENCES users(id),
  headline         TEXT NOT NULL,
  body_text        TEXT NOT NULL,
  why_now          TEXT NOT NULL,
  discount_pct     INTEGER NOT NULL,
  cashback_cents   INTEGER NOT NULL,
  product_id       INTEGER REFERENCES products(id),
  context_snapshot TEXT NOT NULL,
  qr_token         TEXT UNIQUE NOT NULL,
  status           TEXT DEFAULT 'active' CHECK(status IN ('active','redeemed','expired')),
  expires_at       TEXT NOT NULL,
  generated_at     TEXT DEFAULT (datetime('now')),
  redeemed_at      TEXT
);

CREATE TABLE IF NOT EXISTS transactions (
  id                    INTEGER PRIMARY KEY AUTOINCREMENT,
  coupon_id             INTEGER NOT NULL REFERENCES coupons(id),
  shop_id               INTEGER NOT NULL REFERENCES shops(id),
  user_id               INTEGER REFERENCES users(id),
  cashback_cents        INTEGER NOT NULL,
  stripe_transfer_id    TEXT,
  stripe_payment_intent TEXT,
  status                TEXT DEFAULT 'pending',
  redeemed_at           TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS user_preferences (
  id                       INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id                  INTEGER UNIQUE NOT NULL REFERENCES users(id),
  category_affinity        TEXT DEFAULT '{}',
  preferred_discount_range TEXT DEFAULT '{"min":10,"max":25}',
  active_hours             TEXT DEFAULT '[]',
  product_affinity         TEXT DEFAULT '{}',
  avg_spend_cents          INTEGER DEFAULT 0,
  purchase_count           INTEGER DEFAULT 0,
  last_updated             TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS purchase_events (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id        INTEGER REFERENCES users(id),
  shop_id        INTEGER NOT NULL REFERENCES shops(id),
  coupon_id      INTEGER NOT NULL REFERENCES coupons(id),
  product_id     INTEGER REFERENCES products(id),
  amount_cents   INTEGER NOT NULL DEFAULT 0,
  cashback_cents INTEGER NOT NULL DEFAULT 0,
  discount_pct   INTEGER NOT NULL DEFAULT 0,
  source         TEXT NOT NULL DEFAULT 'qr_redemption',
  basket_json    TEXT,
  purchased_at   TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS payone_density (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  shop_id     INTEGER NOT NULL REFERENCES shops(id),
  txn_count   INTEGER NOT NULL,
  recorded_at TEXT DEFAULT (datetime('now'))
);

CREATE TABLE IF NOT EXISTS shop_visits (
  id          INTEGER PRIMARY KEY AUTOINCREMENT,
  shop_id     INTEGER NOT NULL REFERENCES shops(id),
  user_id     INTEGER NOT NULL REFERENCES users(id),
  entered_at  TEXT DEFAULT (datetime('now')),
  visit_date  TEXT NOT NULL DEFAULT (date('now')),
  UNIQUE(shop_id, user_id, visit_date)
);

CREATE TABLE IF NOT EXISTS simulated_user_locations (
  id             INTEGER PRIMARY KEY AUTOINCREMENT,
  user_id        INTEGER UNIQUE NOT NULL REFERENCES users(id),
  latitude       REAL NOT NULL,
  longitude      REAL NOT NULL,
  movement_state TEXT DEFAULT 'walking' CHECK(movement_state IN ('static','walking','moving_fast')),
  anchor_shop_id INTEGER REFERENCES shops(id),
  last_seen_at   TEXT DEFAULT (datetime('now')),
  is_active      INTEGER DEFAULT 1
);

CREATE INDEX IF NOT EXISTS idx_coupons_token ON coupons(qr_token);
CREATE INDEX IF NOT EXISTS idx_coupons_user  ON coupons(user_id);
CREATE INDEX IF NOT EXISTS idx_payone_shop   ON payone_density(shop_id);
CREATE INDEX IF NOT EXISTS idx_payone_time   ON payone_density(recorded_at);
CREATE INDEX IF NOT EXISTS idx_shop_visits_shop_time ON shop_visits(shop_id, entered_at);
CREATE INDEX IF NOT EXISTS idx_shop_visits_user_time ON shop_visits(user_id, entered_at);
<<<<<<< Updated upstream
CREATE INDEX IF NOT EXISTS idx_purchase_events_user ON purchase_events(user_id);
CREATE INDEX IF NOT EXISTS idx_purchase_events_shop ON purchase_events(shop_id, purchased_at);
=======
CREATE INDEX IF NOT EXISTS idx_simulated_users_shop_time ON simulated_user_locations(anchor_shop_id, last_seen_at);
CREATE INDEX IF NOT EXISTS idx_simulated_users_last_seen ON simulated_user_locations(last_seen_at);
>>>>>>> Stashed changes
