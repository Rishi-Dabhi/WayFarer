# City Wallet Agent Notes

This project is a hackathon prototype for the DSV-Gruppe Generative City Wallet challenge.

## Product Direction

The consumer app should open to an interactive Mapbox map. Shops and organisations appear as pins with coupon-count badges. Tapping a shop opens a shop detail page with store information, products, and available coupons. Tapping a coupon opens the coupon detail page; the QR code is shown from that page and is scanned by the merchant flow.

The notification flow is different from the app-icon flow: tapping a push notification should deep-link directly to the relevant coupon detail page.

## Current Architecture Target

- Mobile: Expo React Native with Expo Router.
- Map: Mapbox via `@rnmapbox/maps`.
- AI: on-device Gemma 3 1B GGUF through `llama.rn`, with a mock fallback so the demo remains usable before native model setup is complete.
- Backend: FastAPI.
- Storage target: MongoDB is the long-term fit because shops, context snapshots, preferences, and generated offers are document-shaped and geospatial queries benefit from `2dsphere` indexes. The current codebase still has SQLite routes in several places, so migrate incrementally and keep endpoints stable while doing so.
- Weather: OpenWeatherMap.
- Events: Eventbrite, with local stub fallback.
- POI/shop bootstrap: OSM Overpass through `seed_from_osm.py`, so real local venues can be registered before the demo.
- Payments: Stripe test mode. Wallet top-ups should be credited through Stripe webhooks, not client-side confirmation.
- Push: Expo Push Notifications.

## Key Demo Flow

1. Consumer opens app from icon.
2. Mapbox map loads around the user.
3. Pins show nearby registered shops and available coupon counts.
4. Consumer taps a shop pin.
5. Shop page shows details, products, and available coupons.
6. Consumer taps a coupon.
7. Coupon page shows details, context reason, and a QR modal.
8. Merchant scans QR and confirms redemption.
9. Cashback is deducted from merchant wallet and paid through Stripe test flow.
10. Transaction updates analytics and user preferences.

## Notification Flow

1. Background smart location detects relevant nearby offer opportunity.
2. App/backend saves or surfaces the coupon.
3. Expo push notification is sent with `{ screen: "coupon", coupon_id }`.
4. User taps the notification.
5. App opens directly to `/(consumer)/offer/[id]`.

## Important Implementation Notes

- Do not remove the existing smart location hook. It should continue using foreground `watchPositionAsync`, background `TaskManager`, and movement-aware throttling.
- For OSM venues, remember that raw OSM POIs are not automatically valid City Wallet merchants. Run `backend/seed_from_osm.py` before demos to create merchant accounts, products, wallets, and campaign defaults for nearby POIs.
- Keep fallback paths. Hackathon demos should work even without Eventbrite, OpenWeather, Mapbox, Stripe webhook, or Gemma model credentials.
- Avoid storing raw user location history. Store generated offer context snapshots, not continuous movement traces.

