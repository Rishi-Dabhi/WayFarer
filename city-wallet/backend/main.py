import asyncio
from contextlib import asynccontextmanager
from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from database import init_db, close_db, get_db
from config import settings
from routes import auth, context, offers, coupons, products, merchants, wallet, analytics, shops, webhook
from services.payone_simulator import update_density


async def _payone_background():
    """Update simulated Payone density for all shops every 5 minutes."""
    await asyncio.sleep(10)  # wait for DB init
    while True:
        try:
            db = await get_db()
            async with db.execute("SELECT id FROM shops WHERE is_active=1") as cur:
                shops = await cur.fetchall()
            for shop in shops:
                await update_density(shop["id"])
        except Exception:
            pass
        await asyncio.sleep(300)  # 5 minutes


@asynccontextmanager
async def lifespan(app: FastAPI):
    await init_db()

    if settings.seed_demo_data:
        from seed import seed_if_empty
        await seed_if_empty()

    task = asyncio.create_task(_payone_background())
    yield
    task.cancel()
    await close_db()


app = FastAPI(title="City Wallet API", version="1.0.0", lifespan=lifespan)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(context.router)
app.include_router(offers.router)
app.include_router(coupons.router)
app.include_router(products.router)
app.include_router(merchants.router)
app.include_router(wallet.router)
app.include_router(analytics.router)
app.include_router(shops.router)
app.include_router(webhook.router)


@app.get("/health")
async def health():
    return {"status": "ok"}
