# Payments and Purchase History Plan

## Current state

The app has a useful foundation, but the real payment and purchase pipeline is not fully implemented yet.

Already in place:

- `transactions` records coupon redemptions.
- `coupons.product_id` links a coupon to the product it was generated for.
- `shops.category` gives each redemption a merchant/category signal.
- `user_preferences` stores learned preference data.
- Merchant QR redemption can deduct cashback from the merchant wallet.
- Preference learning currently updates category affinity after redemption.

The main missing piece is richer purchase events and using them more directly in `auto_nearby_coupons`.

## What is still simulated

Merchant wallet top-up currently creates a Stripe PaymentIntent, but the Flutter app immediately confirms it through the backend. There is no real Stripe PaymentSheet/card confirmation flow in the app yet.

Cashback transfer support exists in the backend, but it depends on proper Stripe connected account setup for the consumer.

## Purchase history model

Add a proper purchase history layer that records what the user actually bought, not only which coupon was redeemed.

Suggested fields:

- `user_id`
- `shop_id`
- `coupon_id`
- `product_id`
- `amount_cents`
- `cashback_cents`
- `discount_pct`
- `purchased_at`
- `source`, for example `qr_redemption`, `payone_import`, or `manual_demo`
- optional basket JSON for multiple items

## Preference learning

Use purchase events to update:

- preferred shop categories
- preferred products/items
- active shopping hours
- average spend range
- discount/cashback sensitivity
- redemption behavior by weather, time, and busyness

Then feed those learned preferences into `auto_nearby_coupons` so coupon ranking is influenced by both live context and the user's real purchase behavior.

## Next steps

1. Add a `purchase_events` table.
2. Write a service that records a purchase event when a coupon is redeemed.
3. Extend `preference_learner.py` to learn from product, category, spend, time, and context.
4. Update `auto_nearby_coupons` scoring to prefer products/categories the user actually buys.
5. Replace simulated wallet top-up confirmation with a real Stripe PaymentSheet flow.
6. Optionally import Payone/POS basket data later for item-level history.
