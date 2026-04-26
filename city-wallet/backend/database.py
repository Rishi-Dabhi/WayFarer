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
    ):
        try:
            await db.execute(statement)
        except Exception:
            pass
    await db.commit()


async def close_db() -> None:
    global _db
    if _db:
        await _db.close()
        _db = None
