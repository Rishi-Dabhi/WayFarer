import json
from fastapi import APIRouter, HTTPException, Depends
from pydantic import BaseModel
from database import get_db
from middleware.auth import require_merchant, get_current_user

router = APIRouter(prefix="/api/merchants", tags=["merchants"])


class ShopIn(BaseModel):
    name: str
    description: str = ""
    category: str = "cafe"
    latitude: float
    longitude: float
    address: str = ""
    target_quiet_hours: list[str] = ["14:00-16:00"]
    max_discount_pct: int = 20
    cashback_budget_per_coupon_cents: int = 500
    campaign_goal: str = "fill_quiet_hours"
    auto_coupon_enabled: int = 1
    auto_trigger_radius_m: int = 200
    quiet_threshold_ratio: float = 0.6
    coupon_frequency_minutes: int = 60


class ShopUpdate(BaseModel):
    name: str | None = None
    description: str | None = None
    category: str | None = None
    address: str | None = None
    target_quiet_hours: list[str] | None = None
    max_discount_pct: int | None = None
    cashback_budget_per_coupon_cents: int | None = None
    campaign_goal: str | None = None
    auto_coupon_enabled: int | None = None
    auto_trigger_radius_m: int | None = None
    quiet_threshold_ratio: float | None = None
    coupon_frequency_minutes: int | None = None
    is_active: int | None = None


@router.post("/shop")
async def create_shop(body: ShopIn, merchant: dict = Depends(require_merchant)):
    db = await get_db()
    async with db.execute(
        """INSERT INTO shops
           (merchant_id,name,description,category,latitude,longitude,address,
            target_quiet_hours,max_discount_pct,cashback_budget_per_coupon_cents,campaign_goal,
            auto_coupon_enabled,auto_trigger_radius_m,quiet_threshold_ratio,coupon_frequency_minutes)
           VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?,?)""",
        (
            int(merchant["sub"]),
            body.name, body.description, body.category,
            body.latitude, body.longitude, body.address,
            json.dumps(body.target_quiet_hours),
            body.max_discount_pct, body.cashback_budget_per_coupon_cents, body.campaign_goal,
            body.auto_coupon_enabled, body.auto_trigger_radius_m,
            body.quiet_threshold_ratio, body.coupon_frequency_minutes,
        ),
    ) as cur:
        shop_id = cur.lastrowid
    await db.commit()
    return {"id": shop_id, **body.model_dump()}


@router.get("/shop/{merchant_id}")
async def get_shop(merchant_id: int, user: dict = Depends(get_current_user)):
    db = await get_db()
    async with db.execute(
        "SELECT * FROM shops WHERE merchant_id=?", (merchant_id,)
    ) as cur:
        rows = await cur.fetchall()
    return [dict(r) for r in rows]


@router.put("/shop/{shop_id}")
async def update_shop(shop_id: int, body: ShopUpdate, merchant: dict = Depends(require_merchant)):
    db = await get_db()
    raw = body.model_dump(exclude_none=True)
    if "target_quiet_hours" in raw:
        raw["target_quiet_hours"] = json.dumps(raw["target_quiet_hours"])
    if not raw:
        raise HTTPException(400, "No fields to update")
    set_clause = ", ".join(f"{k}=?" for k in raw)
    await db.execute(
        f"UPDATE shops SET {set_clause} WHERE id=?",
        (*raw.values(), shop_id),
    )
    await db.commit()
    return {"updated": True}
