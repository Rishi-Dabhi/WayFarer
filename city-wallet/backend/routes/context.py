from fastapi import APIRouter, Query
from services.context_aggregator import get_signals
from config import DEMO_CONTEXTS

router = APIRouter(prefix="/api/context", tags=["context"])


@router.get("/signals")
async def context_signals(
    lat: float = Query(...),
    lng: float = Query(...),
    radius: float = Query(600),
    demo: str | None = Query(None),
):
    override = DEMO_CONTEXTS.get(demo) if demo else None
    signals = await get_signals(lat, lng, radius, demo_override=override)
    return signals
