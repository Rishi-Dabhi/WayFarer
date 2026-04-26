# Project Summary

City Wallet, branded as WayFarer, is a context-aware coupon and cashback wallet that helps local merchants turn real-time city movement into targeted demand. Its novel approach is to periodically poll user location, similar to how Google Maps infers route traffic, and use those movement signals to estimate how busy or quiet nearby stores are.

Instead of merchants manually creating generic discounts, the system observes where users are, which shops are nearby, and whether a store appears under-visited compared with expected activity. The backend combines this live location and busyness signal with weather, time of day, local events, shop distance, product availability, merchant campaign rules, and user preferences. From that context, it dynamically generates coupons that are relevant to the user's current moment and useful to the merchant's current need.

For example, a quiet cafe on a rainy afternoon can automatically offer a nearby user a timely coffee discount, while a restaurant during a slow lunch period can trigger a short-lived meal offer. Consumers discover offers on the Flutter map, open a coupon, and present a QR code in-store. Merchants scan the QR code to validate and redeem the offer. The backend then marks the coupon as redeemed, records the transaction, deducts cashback from the merchant wallet, and updates purchase history and user preferences.

Merchants can manage shop details, products, campaign settings, wallet topups, QR scanning, and analytics. WayFarer turns passive location polling into a complete local commerce loop: stores get smarter footfall incentives, and users receive offers with real cashback that feel immediate, local, and contextually meaningful.
