# City Wallet

Hackathon prototype for a generative city wallet: consumers see nearby shops on a map, coupons are created automatically from live context and merchant campaign thresholds, and merchants redeem QR coupons with cashback deducted from their wallet.

## Current Demo Stack

- Backend: FastAPI + SQLite for the local hackathon demo
- Mobile: Expo React Native, Expo Go compatible
- Map: `react-native-maps`
- Context: foreground location, weather, OSM/Eventbrite fallbacks, simulated Payone footfall
- Payments: Stripe test-mode shape with Expo Go fallback for wallet top-up

MongoDB, native Mapbox, native Stripe sheet, and on-device Gemma are documented in [PLAN.md](city-wallet/PLAN.md) as the fuller architecture, but the current runnable demo favors Expo Go reliability.

## Quick Start

Backend:

```bash
cd city-wallet/backend
cp .env.example .env
pip install -r requirements.txt
python seed_from_osm.py
uvicorn main:app --reload --port 8000
```

Mobile:

```bash
cd city-wallet/mobile
cp .env.example .env
npm install
npx expo start -c
```

For Android emulator, set this in `mobile/.env`:

```env
EXPO_PUBLIC_API_URL=http://10.0.2.2:8000
```

For a physical phone, use your machine LAN IP instead.

## Demo Logins

- Consumer: `user@demo.com` / `demo1234`
- Merchant: `merchant@demo.com` / `demo1234`

## More Docs

- [Setup Guide](city-wallet/SETUP.md)
- [Implementation Plan](city-wallet/PLAN.md)
- [Agent Notes](city-wallet/CLAUDE.md)

## Before Pushing

- Do not commit `.env` files.
- Do not commit `city_wallet.db`, `node_modules`, `.venv`, `.expo`, `android`, or IDE folders.
- Keep `package-lock.json` committed for reproducible mobile installs.
- Use `.env.example` files for placeholder keys only.

