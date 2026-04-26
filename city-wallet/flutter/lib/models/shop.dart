import 'coupon.dart';
import 'product.dart';

class Shop {
  final int id;
  final String name;
  final String category;
  final String? address;
  final double lat;
  final double lng;
  final double? distanceM;
  final int activeCouponCount;
  final String busyness;
  final int txnCount15min;
  final List<Coupon>? coupons;
  final List<Product>? products;

  const Shop({
    required this.id,
    required this.name,
    required this.category,
    this.address,
    required this.lat,
    required this.lng,
    this.distanceM,
    required this.activeCouponCount,
    required this.busyness,
    required this.txnCount15min,
    this.coupons,
    this.products,
  });

  factory Shop.fromJson(Map<String, dynamic> j) => Shop(
        id: j['id'] ?? j['_id'] ?? 0,
        name: j['name'] ?? '',
        category: j['category'] ?? '',
        address: j['address'],
        lat: (j['lat'] ?? 0).toDouble(),
        lng: (j['lng'] ?? 0).toDouble(),
        distanceM: j['distance_m'] != null ? (j['distance_m']).toDouble() : null,
        activeCouponCount: j['active_coupon_count'] ?? 0,
        busyness: j['busyness'] ?? 'normal',
        txnCount15min: j['txn_count_15min'] ?? 0,
        coupons: j['active_coupons'] != null
            ? (j['active_coupons'] as List).map((c) => Coupon.fromJson(c)).toList()
            : null,
        products: j['products'] != null
            ? (j['products'] as List).map((p) => Product.fromJson(p)).toList()
            : null,
      );
}
