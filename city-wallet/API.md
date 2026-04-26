# City Wallet API Reference

Base URL: `http://localhost:8000` (dev) — set `EXPO_PUBLIC_API_URL` in mobile `.env` to match.

All protected endpoints require `Authorization: Bearer <jwt>`.

---

## Auth

### Register
```
POST /api/auth/register
```
```json
{ "email": "string", "password": "string", "role": "consumer|merchant", "name": "string" }
```
```json
{ "token": "jwt", "role": "consumer", "user_id": 1 }
```

### Login
```
POST /api/auth/login
```
```json
{ "email": "string", "password": "string" }
```
```json
{ "token": "jwt", "role": "consumer", "user_id": 1 }
```

### Me
```
GET /api/auth/me
Authorization: Bearer <jwt>
```
```json
{ "id": 1, "email": "...", "role": "consumer", "name": "..." }
```

### Push Token
```
POST /api/auth/push-token
Authorization: Bearer <jwt>
```
```json
{ "expo_push_token": "ExponentPushToken[...]" }
```

---

## Context Signals

```
GET /api/context/signals?lat=48.778&lng=9.180&radius=600&demo=rainy_quiet
```

`demo` is optional. Valid values: `rainy_quiet`, `sunny_lunch_busy`, `evening_event`.

```json
{
  "weather": { "temp": 11, "feels_like": 8, "condition": "light rain", "icon": "10d" },
  "time": { "hour": 14, "period": "afternoon", "day_of_week": "Saturday" },
  "nearby_shops": [
    { "shop_id": 1, "name": "Café Kern", "category": "cafe", "distance_m": 80,
      "busyness": "quiet", "txn_count_15min": 2, "typical_txn": 12 }
  ],
  "local_events": [
    { "name": "Stuttgart Market", "distance_m": 350, "date": "2026-04-26" }
  ],
  "osm_density": {
    "total": 24,
    "by_category": { "cafe": 8, "restaurant": 6, "retail": 10 },
    "closest": [{ "name": "Café Eckstein", "category": "cafe", "distance_m": 45 }]
  }
}
```

---

## Shops

### Map pins (consumer home)
```
GET /api/shops/map?lat=48.778&lng=9.180&radius=600
```
Returns shops within radius sorted by distance, closest first. Busy shops last.
```json
[
  {
    "id": 1, "_id": "1", "name": "Café Kern", "category": "cafe",
    "lat": 48.778, "lng": 9.180, "address": "Marktplatz 1",
    "distance_m": 80, "active_coupon_count": 3,
    "busyness": "quiet", "txn_count_15min": 2
  }
]
```

### Shop detail
```
GET /api/shops/{shop_id}
```
```json
{
  "shop": { "id": 1, "name": "Café Kern", "category": "cafe", ... },
  "products": [{ "id": 1, "name": "Flat White", "price_cents": 380, "stock_level": "normal" }],
  "active_coupons": [{ "id": 5, "headline": "Warm up. 80m away.", "discount_pct": 15, ... }],
  "busyness": { "level": "quiet", "txn_count_15min": 2, "typical": 12 }
}
```

---

## Offers (Claude-generated, server-side SSE)

### Generate offer stream
```
POST /api/offers/generate?user_lat=48.778&user_lng=9.180&user_id=1&demo=rainy_quiet
```
Returns `text/event-stream`. Events (each line is `data: <json>`):

| type | payload |
|---|---|
| `context` | full signals object |
| `thinking` | `{ "message": "Selecting shop..." }` |
| `token` | `{ "text": "Warm" }` (one token at a time) |
| `offer_data` | complete parsed offer JSON |
| `offer` | persisted coupon with `id`, `qr_token`, `expires_at` |
| `error` | `{ "message": "No nearby shops found" }` |

### Get offer
```
GET /api/offers/{coupon_id}
```

### User's offer history
```
GET /api/offers/user/{user_id}
```

---

## Coupons

### Create (device-generated)

Used by the on-device Gemma flow. Backend mints the signed QR token.

```
POST /api/coupons
```
```json
{
  "shop_id": 1,
  "user_id": 1,
  "headline": "Warm up. 80m away.",
  "body_text": "It's cold and Café Kern is quiet — perfect for a flat white.",
  "why_now": "Payone activity at 17% of typical demand this Tuesday afternoon.",
  "discount_pct": 15,
  "cashback_cents": 57,
  "product_id": 1,
  "context_snapshot": { "weather": {}, "time": {}, "busyness": "quiet" },
  "expires_minutes": 60
}
```
```json
{ "coupon_id": 5, "qr_token": "abc123hmac", "expires_at": "2026-04-26T15:30:00" }
```

### Auto-nearby (backend-owned generation)

Checks merchant campaign thresholds and auto-creates coupons for qualifying shops.

```
POST /api/coupons/auto-nearby
```
```json
{ "lat": 48.778, "lng": 9.180, "user_id": 1, "radius_m": 800 }
```
```json
{
  "created": [{ "coupon_id": 6, "shop_name": "Café Kern", "headline": "...", ... }],
  "count": 1
}
```

### Validate (for merchant scanner)
```
GET /api/coupons/validate/{token}
```
Returns `400` for invalid token, `404` if not found, `409` if already redeemed, `410` if expired.
```json
{ "id": 5, "headline": "...", "cashback_cents": 57, "shop_name": "Café Kern", "valid": true, ... }
```

### Redeem
```
POST /api/coupons/redeem
Authorization: Bearer <merchant-jwt>
```
```json
{ "token": "abc123hmac", "merchant_id": 2 }
```
```json
{
  "success": true,
  "transaction_id": 10,
  "cashback_cents": 57,
  "stripe_transfer_id": "tr_...",
  "new_wallet_balance": 4943
}
```

Errors: `402` insufficient wallet balance, `403` wrong merchant, `410` expired.

### Coupon detail
```
GET /api/coupons/{coupon_id}
```

### User coupon list
```
GET /api/coupons/user/{user_id}
```

---

## Products

```
GET    /api/products?shop_id=1
POST   /api/products            Authorization: Bearer <merchant-jwt>
PUT    /api/products/{id}       Authorization: Bearer <merchant-jwt>
DELETE /api/products/{id}       Authorization: Bearer <merchant-jwt>
```

`POST` / `PUT` body:
```json
{ "shop_id": 1, "name": "Oat Latte", "price_cents": 420, "category": "cafe", "stock_level": "normal" }
```

`stock_level` values: `low`, `normal`, `high`.

---

## Merchants

### Get shop config
```
GET /api/merchants/shop/{merchant_id}
Authorization: Bearer <jwt>
```

### Create shop
```
POST /api/merchants/shop
Authorization: Bearer <merchant-jwt>
```
```json
{
  "name": "Café Kern", "description": "...", "category": "cafe",
  "latitude": 48.778, "longitude": 9.180, "address": "Marktplatz 1",
  "target_quiet_hours": ["14:00-16:00"],
  "max_discount_pct": 20,
  "cashback_budget_per_coupon_cents": 300,
  "campaign_goal": "fill_quiet_hours",
  "auto_coupon_enabled": 1,
  "auto_trigger_radius_m": 200,
  "quiet_threshold_ratio": 0.6,
  "coupon_frequency_minutes": 60
}
```

`campaign_goal` values: `fill_quiet_hours`, `clear_stock`, `new_customers`.

### Update shop / campaign rules
```
PUT /api/merchants/shop/{shop_id}
Authorization: Bearer <merchant-jwt>
```
All fields optional — only provided fields are updated.

---

## Merchant Wallet

### Balance + top-up history
```
GET /api/wallet/balance/{merchant_id}
Authorization: Bearer <merchant-jwt>
```
```json
{
  "balance_cents": 4943,
  "updated_at": "2026-04-26T14:22:00",
  "topup_history": [{ "amount_cents": 2000, "status": "succeeded", "created_at": "..." }]
}
```

### Initiate top-up
```
POST /api/wallet/topup
Authorization: Bearer <merchant-jwt>
```
```json
{ "merchant_id": 2, "amount_cents": 2000 }
```
```json
{ "client_secret": "pi_...secret_...", "payment_intent_id": "pi_...", "amount_cents": 2000, "publishable_key": "pk_test_..." }
```
Minimum top-up: €1.00 (100 cents).

### Confirm top-up (dev fallback)

Only needed without Stripe webhooks (e.g. Expo Go demo mode).

```
POST /api/wallet/topup/confirm
Authorization: Bearer <merchant-jwt>
```
```json
{ "payment_intent_id": "pi_..." }
```

---

## Stripe Webhook

```
POST /api/webhooks/stripe
Stripe-Signature: t=...,v1=...
```

Handles `payment_intent.succeeded` → credits `merchant_wallets.balance_cents` and sends an Expo push notification to the merchant.

Local dev: `stripe listen --forward-to localhost:8000/api/webhooks/stripe`

---

## Analytics

```
GET /api/analytics/merchant/{shop_id}
Authorization: Bearer <merchant-jwt>
```
```json
{
  "coupons_generated_today": 12,
  "redemptions_today": 4,
  "redemption_rate_pct": 33,
  "avg_cashback_cents": 62,
  "wallet_spent_today_cents": 248,
  "coupons_by_hour": [{ "hour": 14, "count": 5 }],
  "top_products": [{ "name": "Flat White", "redemptions": 3 }],
  "recent_redemptions": [{ "headline": "...", "cashback_cents": 57, "redeemed_at": "..." }]
}
```

---

## Health

```
GET /health
```
```json
{ "status": "ok" }
```

---

## Demo Modes

Append `?demo=<key>` to the context signals or offer generate endpoint to override live data with preset context. Useful for repeatable hackathon demos.

| Key | Weather | Busyness | Events |
|---|---|---|---|
| `rainy_quiet` | 8°C light rain | quiet (2 txn) | none |
| `sunny_lunch_busy` | 22°C clear sky | normal (14 txn) | Stuttgart Market 350m |
| `evening_event` | 15°C few clouds | quiet (5 txn) | Jazz Night 180m + Street Food 420m |

---

## Error Codes

| Code | Meaning |
|---|---|
| 400 | Bad request / invalid input |
| 401 | Missing or invalid JWT |
| 402 | Insufficient merchant wallet balance |
| 403 | Action not permitted for this account |
| 404 | Resource not found |
| 409 | Conflict (e.g. coupon already redeemed) |
| 410 | Resource expired (coupon past `expires_at`) |
| 422 | Pydantic validation error |
| 500 | Unhandled server error |
