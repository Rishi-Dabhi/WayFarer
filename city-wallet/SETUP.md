# City Wallet Setup Guide

## Prerequisites

- Python 3.11+
- Node.js 20+
- Expo CLI
- Stripe CLI for local webhooks
- A Mapbox access token
- Optional: OpenWeatherMap and Eventbrite tokens

## Backend

```bash
cd city-wallet/backend
cp .env.example .env
pip install -r requirements.txt
uvicorn main:app --reload --port 8000
```

The current implementation still uses SQLite for runtime stability, with MongoDB documented in `PLAN.md` as the next migration phase. The first backend run seeds demo users and shops.

Demo logins:

- Consumer: `user@demo.com` / `demo1234`
- Merchant: `merchant@demo.com` / `demo1234`

For Stripe wallet top-ups, run this in another terminal:

```bash
stripe listen --forward-to localhost:8000/api/webhooks/stripe
```

Copy the `whsec_...` value into `STRIPE_WEBHOOK_SECRET`.

## Mobile

```bash
cd city-wallet/mobile
cp .env.example .env
npm install
npx expo start
```

Set these in `mobile/.env`:

```env
EXPO_PUBLIC_API_URL=http://YOUR_LAN_IP:8000
EXPO_PUBLIC_STRIPE_PK=pk_test_...
EXPO_PUBLIC_MAPBOX_TOKEN=pk.eyJ1...
```

Mapbox and `llama.rn` require a custom Expo dev build, not plain Expo Go. The Gemma path includes a fallback generator so the demo can still create offers before native model setup is complete.

## OSM Pre-Demo Shop Registration

OSM POIs are not City Wallet merchants by default. Before the demo, register nearby real venues:

```bash
cd city-wallet/backend
python seed_from_osm.py --lat 48.778 --lng 9.180 --radius 400 --dry-run
python seed_from_osm.py --lat 48.778 --lng 9.180 --radius 400
```

The script creates merchant accounts, products, campaign defaults, and wallet balances for real nearby shops.

## Consumer Flow

1. Open the app from the icon.
2. The Mapbox map loads around the user.
3. Shop pins show active coupon counts.
4. Tap a pin, then tap `Open store`.
5. The shop page shows details, products, and available coupons.
6. Tap a coupon to view details.
7. Tap `View QR code` to show the redeemable QR.

## Notification Flow

Push notifications include coupon routing data. Tapping a notification opens `/(consumer)/offer/[id]` directly.

## Merchant Flow

1. Log in as merchant.
2. Top up the organisation wallet with Stripe test card `4242 4242 4242 4242`.
3. Stripe webhook credits the wallet.
4. Scan the consumer QR.
5. Confirm redemption.
6. Cashback is deducted from the merchant wallet and the transaction updates analytics/preferences.

