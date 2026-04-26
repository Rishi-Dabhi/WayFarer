from fastapi import APIRouter, HTTPException, Depends, Query
from pydantic import BaseModel
from database import get_db
from middleware.auth import require_merchant

router = APIRouter(prefix="/api/products", tags=["products"])


class ProductIn(BaseModel):
    shop_id: int
    name: str
    description: str = ""
    price_cents: int
    category: str = ""
    stock_level: str = "normal"


@router.get("")
async def list_products(shop_id: int = Query(...)):
    db = await get_db()
    async with db.execute(
        "SELECT * FROM products WHERE shop_id=? AND is_active=1 ORDER BY name", (shop_id,)
    ) as cur:
        rows = await cur.fetchall()
    return [dict(r) for r in rows]


@router.post("")
async def create_product(body: ProductIn, merchant: dict = Depends(require_merchant)):
    db = await get_db()
    async with db.execute(
        "INSERT INTO products (shop_id,name,description,price_cents,category,stock_level) VALUES (?,?,?,?,?,?)",
        (body.shop_id, body.name, body.description, body.price_cents, body.category, body.stock_level),
    ) as cur:
        pid = cur.lastrowid
    await db.commit()
    return {"id": pid, **body.model_dump()}


class ProductUpdate(BaseModel):
    name: str | None = None
    description: str | None = None
    price_cents: int | None = None
    stock_level: str | None = None
    is_active: int | None = None


@router.put("/{product_id}")
async def update_product(product_id: int, body: ProductUpdate, merchant: dict = Depends(require_merchant)):
    db = await get_db()
    fields = {k: v for k, v in body.model_dump().items() if v is not None}
    if not fields:
        raise HTTPException(400, "No fields to update")
    set_clause = ", ".join(f"{k}=?" for k in fields)
    await db.execute(
        f"UPDATE products SET {set_clause} WHERE id=?",
        (*fields.values(), product_id),
    )
    await db.commit()
    return {"updated": True}


@router.delete("/{product_id}")
async def delete_product(product_id: int, merchant: dict = Depends(require_merchant)):
    db = await get_db()
    await db.execute("UPDATE products SET is_active=0 WHERE id=?", (product_id,))
    await db.commit()
    return {"deleted": True}
