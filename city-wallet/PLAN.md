# City Wallet Redesign Plan

## Goal

Implement the redesigned user flow:

- App icon opens a Mapbox shop map.
- Notification tap opens a coupon detail page directly.
- Shop pins show active coupon counts.
- Shop pages list products and coupons.
- Coupon pages expose details first and QR code through a button/modal.
- Coupon generation uses on-device Gemma 3 1B where possible.
- Event context comes from Eventbrite, not Ticketmaster.
- Stripe wallet top-ups use webhooks.
- MongoDB is the intended database direction for geospatial and document-shaped data.

## Implementation Phases

### Phase 1: Durable Flow on Current Backend

- Add `GET /api/shops/map`.
- Add `GET /api/shops/{shop_id}`.
- Add `POST /api/coupons` for device-generated coupons.
- Keep SQLite-backed implementation while the Mongo migration is not complete.
- Replace Ticketmaster service with Eventbrite service plus stub fallback.
- Add Stripe webhook route for top-up crediting. Keep the old manual confirm endpoint only as a dev fallback until the Mongo/payment migration is complete.
- Add Expo push service.

### Phase 2: Mobile Map UX

- Add Mapbox dependency and token config.
- Replace consumer home offer feed with a Mapbox map.
- Add `useMapShops`.
- Add `app/(consumer)/shop/[id].tsx`.
- Redesign `app/(consumer)/offer/[id].tsx` with a QR modal.
- Add push-notification registration and tap routing.

### Phase 3: On-Device Gemma

- Add `llama.rn` and `expo-file-system` dependencies.
- Add `gemmaService.ts`.
- Add `useGemma.ts`.
- Add model download screen.
- Keep a mock generation fallback for demo reliability.

### Phase 4: MongoDB Migration

- Add `motor` and `dnspython`.
- Replace `database.py` with Motor client.
- Migrate auth, shops, products, coupons, wallet, analytics, preferences, and Payone density.
- Add Mongo indexes:
  - `shops.location` as `2dsphere`.
  - `coupons.qr_token` unique.
  - `coupons.user_id + status`.
  - `payone_density.shop_id + recorded_at`.
- Update `seed.py` and `seed_from_osm.py`.

## Demo Credentials Needed

Backend `.env`:

```env
OPENWEATHER_API_KEY=
EVENTBRITE_TOKEN=
STRIPE_SECRET_KEY=sk_test_...
STRIPE_WEBHOOK_SECRET=whsec_...
JWT_SECRET=
DATABASE_URL=./city_wallet.db
MONGODB_URL=mongodb+srv://...
```

Mobile `.env`:

```env
EXPO_PUBLIC_API_URL=http://localhost:8000
EXPO_PUBLIC_STRIPE_PK=pk_test_...
EXPO_PUBLIC_MAPBOX_TOKEN=pk.eyJ1...
GEMMA_MODEL_URL=https://huggingface.co/lmstudio-community/gemma-3-1b-it-GGUF/resolve/main/gemma-3-1b-it-q4_0.gguf
```
