import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/coupon.dart';
import '../../models/product.dart';
import '../../models/shop.dart';
import '../../services/api_service.dart';

class ShopDetailScreen extends StatefulWidget {
  final String shopId;
  const ShopDetailScreen({super.key, required this.shopId});

  @override
  State<ShopDetailScreen> createState() => _ShopDetailScreenState();
}

class _ShopDetailScreenState extends State<ShopDetailScreen> {
  Shop? _shop;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final shop = await context.read<ApiService>().getShopDetail(int.parse(widget.shopId));
      if (mounted) setState(() { _shop = shop; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: Text(_shop?.name ?? 'Shop'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _shop == null
              ? const Center(child: Text('Shop not found'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _ShopHeader(shop: _shop!),
                      const SizedBox(height: 20),
                      if (_shop!.coupons?.isNotEmpty == true) ...[
                        const Text('Available Offers', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        ..._shop!.coupons!.map((c) => _CouponCard(coupon: c)),
                        const SizedBox(height: 20),
                      ],
                      if (_shop!.products?.isNotEmpty == true) ...[
                        const Text('Products', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),
                        ..._shop!.products!.map((p) => _ProductRow(product: p)),
                      ],
                    ],
                  ),
                ),
    );
  }
}

class _ShopHeader extends StatelessWidget {
  final Shop shop;
  const _ShopHeader({required this.shop});

  Color get _busynessColor {
    switch (shop.busyness) {
      case 'quiet': return Colors.green;
      case 'busy': return Colors.red;
      default: return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: const Color(0xFFF97316).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Icons.storefront, color: Color(0xFFF97316), size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(shop.name, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(shop.category, style: TextStyle(color: Colors.grey.shade600)),
                if (shop.address != null)
                  Text(shop.address!, style: TextStyle(fontSize: 12, color: Colors.grey.shade500)),
              ],
            ),
          ),
          Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: _busynessColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(shop.busyness, style: TextStyle(color: _busynessColor, fontSize: 12, fontWeight: FontWeight.w600)),
              ),
              if (shop.activeCouponCount > 0) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: Colors.deepOrange.shade50,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${shop.activeCouponCount} offers', style: TextStyle(color: Colors.deepOrange.shade700, fontSize: 12)),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _CouponCard extends StatelessWidget {
  final Coupon coupon;
  const _CouponCard({required this.coupon});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/consumer/offer/${coupon.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.deepOrange.shade100),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(coupon.headline, style: const TextStyle(fontWeight: FontWeight.bold)),
                ),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFFF97316),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('${coupon.discountPct.toStringAsFixed(0)}% off',
                      style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(coupon.bodyText, style: TextStyle(color: Colors.grey.shade700, fontSize: 13), maxLines: 2, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 8),
            Text('€${coupon.cashbackEur.toStringAsFixed(2)} cashback',
                style: TextStyle(color: Colors.green.shade700, fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  final Product product;
  const _ProductRow({required this.product});

  Color get _stockColor {
    switch (product.stockLevel) {
      case 'low': return Colors.red;
      case 'high': return Colors.green;
      default: return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(product.name, style: const TextStyle(fontWeight: FontWeight.w600)),
                if (product.description != null)
                  Text(product.description!, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text('€${product.priceEur.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: _stockColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(product.stockLevel, style: TextStyle(color: _stockColor, fontSize: 11)),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
