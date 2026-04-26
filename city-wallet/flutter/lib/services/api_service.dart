import 'package:dio/dio.dart';
import '../config.dart';
import '../models/coupon.dart';
import '../models/product.dart';
import '../models/shop.dart';
import 'storage_service.dart';

class ApiService {
  late final Dio _dio;
  final StorageService storage;

  ApiService(this.storage) {
    _dio = Dio(BaseOptions(
      baseUrl: Config.apiBaseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 30),
    ));
    _dio.interceptors.add(InterceptorsWrapper(
      onRequest: (options, handler) async {
        final token = await storage.getToken();
        if (token != null) {
          options.headers['Authorization'] = 'Bearer $token';
        }
        handler.next(options);
      },
    ));
  }

  // Auth
  Future<Map<String, dynamic>> login(String email, String password) async {
    final res = await _dio.post('/api/auth/login', data: {'email': email, 'password': password});
    return res.data;
  }

  Future<Map<String, dynamic>> register(String name, String email, String password, String role) async {
    final res = await _dio.post('/api/auth/register', data: {
      'name': name, 'email': email, 'password': password, 'role': role,
    });
    return res.data;
  }

  // Shops
  Future<List<Shop>> getMapShops(double lat, double lng, {int radius = 800}) async {
    final res = await _dio.get('/api/shops/map', queryParameters: {
      'lat': lat, 'lng': lng, 'radius': radius,
    });
    return (res.data as List).map((s) => Shop.fromJson(s)).toList();
  }

  Future<Shop> getShopDetail(int shopId) async {
    final res = await _dio.get('/api/shops/$shopId');
    final data = Map<String, dynamic>.from(res.data as Map);
    final shop = Map<String, dynamic>.from(data['shop'] as Map);
    shop['lat'] = shop['latitude'];
    shop['lng'] = shop['longitude'];
    shop['products'] = data['products'];
    shop['active_coupons'] = data['active_coupons'];
    shop['busyness'] = data['busyness']?['level'] ?? 'normal';
    shop['txn_count_15min'] = data['busyness']?['txn_count_15min'] ?? 0;
    shop['active_coupon_count'] = (data['active_coupons'] as List?)?.length ?? 0;
    return Shop.fromJson(shop);
  }

  // Coupons
  Future<Coupon> getCoupon(int id) async {
    final res = await _dio.get('/api/coupons/$id');
    return Coupon.fromJson(res.data);
  }

  Future<List<Coupon>> getUserCoupons(int userId) async {
    final res = await _dio.get('/api/coupons/user/$userId');
    return (res.data as List).map((c) => Coupon.fromJson(c)).toList();
  }

  Future<Map<String, dynamic>> validateQR(String token) async {
    final res = await _dio.get('/api/coupons/validate/$token');
    return res.data;
  }

  Future<Map<String, dynamic>> redeemCoupon(String token, int merchantId) async {
    final res = await _dio.post('/api/coupons/redeem', data: {
      'token': token, 'merchant_id': merchantId,
    });
    return res.data;
  }

  // Context
  Future<Map<String, dynamic>> getContextSignals(double lat, double lng) async {
    final res = await _dio.get('/api/context/signals', queryParameters: {'lat': lat, 'lng': lng});
    return res.data;
  }

  // Products
  Future<List<Product>> getProducts(int shopId) async {
    final res = await _dio.get('/api/products', queryParameters: {'shop_id': shopId});
    return (res.data as List).map((p) => Product.fromJson(p)).toList();
  }

  Future<Product> createProduct(Map<String, dynamic> data) async {
    final res = await _dio.post('/api/products', data: data);
    return Product.fromJson(res.data);
  }

  Future<void> deleteProduct(int id) => _dio.delete('/api/products/$id');

  // Merchants
  Future<Map<String, dynamic>> getMerchantShop(int merchantId) async {
    final res = await _dio.get('/api/merchants/shop/$merchantId');
    return res.data;
  }

  Future<void> updateShop(int shopId, Map<String, dynamic> data) =>
      _dio.put('/api/merchants/shop/$shopId', data: data);

  // Analytics
  Future<Map<String, dynamic>> getAnalytics(int shopId) async {
    final res = await _dio.get('/api/analytics/merchant/$shopId');
    return res.data;
  }

  // Wallet
  Future<Map<String, dynamic>> getWalletBalance(int merchantId) async {
    final res = await _dio.get('/api/wallet/balance/$merchantId');
    return res.data;
  }

  Future<Map<String, dynamic>> topupWallet(int merchantId, int amountCents) async {
    final res = await _dio.post('/api/wallet/topup', data: {
      'merchant_id': merchantId, 'amount_cents': amountCents,
    });
    return res.data;
  }

  Future<void> topupConfirm(String paymentIntentId) =>
      _dio.post('/api/wallet/topup/confirm', data: {'payment_intent_id': paymentIntentId});
}
