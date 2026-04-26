import aiosqlite
from pathlib import Path
from config import settings

SCHEMA_PATH = Path(__file__).parent / "schema.sql"

_db: aiosqlite.Connection | None = None


async def get_db() -> aiosqlite.Connection:
    global _db
    if _db is None:
        _db = await aiosqlite.connect(settings.database_url)
        _db.row_factory = aiosqlite.Row
        await _db.execute("PRAGMA journal_mode=WAL")
        await _db.execute("PRAGMA foreign_keys=ON")
    return _db


async def init_db() -> None:
    db = await get_db()
    schema = SCHEMA_PATH.read_text()
    await db.executescript(schema)
    try:
        await db.execute("ALTER TABLE users ADD COLUMN expo_push_token TEXT")
    except Exception:
        pass
    for statement in (
        "ALTER TABLE shops ADD COLUMN auto_coupon_enabled INTEGER DEFAULT 1",
        "ALTER TABLE shops ADD COLUMN auto_trigger_radius_m INTEGER DEFAULT 200",
        "ALTER TABLE shops ADD COLUMN quiet_threshold_ratio REAL DEFAULT 0.6",
        "ALTER TABLE shops ADD COLUMN coupon_frequency_minutes INTEGER DEFAULT 60",
        "ALTER TABLE user_preferences ADD COLUMN product_affinity TEXT DEFAULT '{}'",
        "ALTER TABLE user_preferences ADD COLUMN avg_spend_cents INTEGER DEFAULT 0",
        "ALTER TABLE user_preferences ADD COLUMN purchase_count INTEGER DEFAULT 0",
    ):
        try:
            await db.execute(statement)
        except Exception:
            pass
    await db.execute(
        """
        CREATE TABLE IF NOT EXISTS simulated_user_locations (
          id             INTEGER PRIMARY KEY AUTOINCREMENT,
          user_id        INTEGER UNIQUE NOT NULL REFERENCES users(id),
          latitude       REAL NOT NULL,
          longitude      REAL NOT NULL,
          movement_state TEXT DEFAULT 'walking' CHECK(movement_state IN ('static','walking','moving_fast')),
          anchor_shop_id INTEGER REFERENCES shops(id),
          last_seen_at   TEXT DEFAULT (datetime('now')),
          is_active      INTEGER DEFAULT 1
        )
        """
    )
    await db.execute(
        "CREATE INDEX IF NOT EXISTS idx_simulated_users_shop_time ON simulated_user_locations(anchor_shop_id, last_seen_at)"
    )
    await db.execute(
        "CREATE INDEX IF NOT EXISTS idx_simulated_users_last_seen ON simulated_user_locations(last_seen_at)"
    )
    await db.commit()


async def close_db() -> None:
    global _db
    if _db:
        await _db.close()
        _db = None
