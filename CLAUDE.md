# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

Hackathon prototype for the **DSV-Gruppe Generative City Wallet** challenge (HackNation v5). Consumers discover nearby merchants on a Mapbox map and receive AI-generated context-aware coupons; merchants scan QR codes to redeem coupons and deduct cashback from their Stripe-backed wallet.

All application code lives under `city-wallet/`. There is also a `city-wallet/CLAUDE.md` with product-direction notes and implementation constraints — read it before making architectural changes.

## Tech Stack

- **Backend**: FastAPI + SQLite (via `aiosqlite`), targeting MongoDB migration
- **Mobile**: Expo React Native (SDK 52) with Expo Router v4, Mapbox (`@rnmapbox/maps`)
- **AI**: Claude Sonnet 4.6 with prompt caching for server-side offer generation; on-device Gemma 3 1B (`llama.rn`) as a secondary path
- **Payments**: Stripe test mode — wallet top-ups credited via webhooks, not client confirmation

## Development Commands

### Backend

```bash
cd city-wallet/backend
cp .env.example .env          # fill in API keys
pip install -r requirements.txt
uvicorn main:app --reload --port 8000
```

Seed real local shops from OpenStreetMap before a demo:
```bash
python seed_from_osm.py --lat 48.778 --lng 9.180 --radius 400
# preview without writing:
python seed_from_osm.py --lat 48.778 --lng 9.180 --radius 400 --dry-run
```

The DB and demo accounts (`user@demo.com` / `merchant@demo.com`, password `demo1234`) are auto-seeded on first startup via `seed.py`.

For Stripe webhooks during local testing:
```bash
stripe listen --forward-to localhost:8000/api/webhooks/stripe
# copy the printed whsec_... value into .env STRIPE_WEBHOOK_SECRET
```

### Mobile

```bash
cd city-wallet/mobile
cp .env.example .env          # set EXPO_PUBLIC_API_URL, Mapbox token, Stripe PK
npm install
npx expo run:android          # emulator (uses localhost bridge automatically)
npx expo start --dev-client   # after native build
```

For a physical device, set `EXPO_PUBLIC_API_URL=http://<YOUR_LAN_IP>:8000` before starting.

## Architecture

### Backend layout (`city-wallet/backend/`)

| Path | Purpose |
|---|---|
| `main.py` | FastAPI app entry; lifespan handles DB init |
| `routes/` | One file per resource: `auth`, `context`, `offers`, `coupons`, `shops`, `merchants`, `products`, `wallet`, `analytics`, `webhook` |
| `services/offer_generator.py` | Core AI engine — async SSE streaming to Claude Sonnet 4.6, cache_control on system prompt, returns parsed JSON coupon |
| `services/context_aggregator.py` | Merges weather + OSM density + Eventbrite events + Payone transaction sim into context signals |
| `services/osm_service.py` | Overpass API wrapper with 15-min cache and fallback URLs |
| `services/payone_simulator.py` | Rolling 15-min transaction count per shop (busyness signal) |
| `seed_from_osm.py` | Pre-demo bootstrap: creates merchant accounts, shops, products, wallets for real OSM POIs |
| `schema.sql` | Full DB schema reference |

Offers are generated server-side via `POST /api/offers/generate` which streams SSE back to the client. Wallet top-ups flow through Stripe: client calls `/api/wallet/topup` → Stripe Payment Intent → webhook at `/api/webhooks/stripe` credits the balance.

### Mobile layout (`city-wallet/mobile/`)

| Path | Purpose |
|---|---|
| `app/(auth)/` | Login / register screens |
| `app/(consumer)/` | Map home, shop detail, offer/coupon detail, Gemma download |
| `app/(merchant)/` | Dashboard, QR scanner, wallet, products, campaign, analytics |
| `hooks/useLocation.ts` | Foreground + background location with movement-aware throttling |
| `hooks/useContextSignals.ts` | Polls `/api/context/signals`; manages demo mode fallback |
| `hooks/useOfferStream.ts` | SSE parser for streaming offer generation |
| `hooks/useGemma.ts` | On-device inference wrapper with server fallback |
| `services/api.ts` | Axios client with JWT Bearer injection |
| `services/gemmaService.ts` | `llama.rn` wrapper for Gemma 3 1B GGUF |
| `constants/config.ts` | Central place for env var reads |

The consumer home (`app/(consumer)/index.tsx`) renders a Mapbox `MapView` with shop pins and coupon-count badges. Navigation is file-based via Expo Router; deep-link scheme is `citywallet://`.

### Context signal flow

```
useLocation (foreground + background TaskManager)
    → useContextSignals → GET /api/context/signals
        → context_aggregator: weather + OSM density + events + Payone sim
            → offer_generator → Claude Sonnet 4.6 (SSE)
                → coupon saved → Expo push notification
```

## Key Constraints (from city-wallet/CLAUDE.md)

- Do not remove or bypass `useLocation` — it uses `watchPositionAsync`, background `TaskManager`, and movement-aware throttling.
- Do not store raw user location history; store generated offer context snapshots only.
- Keep all fallback paths working — demo must function without Eventbrite, OpenWeather, Mapbox, Stripe webhook, or Gemma credentials.
- OSM POIs are not automatically valid merchants; run `seed_from_osm.py` before any live demo.
- Wallet top-ups must be credited via Stripe webhook, not client-side confirmation.

## Environment Variables

**Backend** (`.env.example` → `.env`):
- `ANTHROPIC_API_KEY` — Claude API
- `OPENWEATHER_API_KEY` — live weather
- `EVENTBRITE_TOKEN` — event discovery
- `STRIPE_SECRET_KEY`, `STRIPE_PUBLISHABLE_KEY`, `STRIPE_WEBHOOK_SECRET`
- `JWT_SECRET` — token signing
- `DATABASE_URL` — SQLite path (default `./city_wallet.db`)

**Mobile** (`.env.example` → `.env`):
- `EXPO_PUBLIC_API_URL` — backend base URL
- `EXPO_PUBLIC_STRIPE_PK` — Stripe publishable key
- `EXPO_PUBLIC_MAPBOX_TOKEN` — Mapbox access token
- `GEMMA_MODEL_URL` — HuggingFace GGUF download URL
