import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/shop.dart';
import '../../services/api_service.dart';
import '../../theme/game_theme.dart';
import '../../widgets/coupon_card.dart';

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
      if (mounted) {
        setState(() {
          _shop = shop;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7DF),
      appBar: AppBar(
        title: Text(_shop?.name ?? 'Shop'),
        backgroundColor: GameTheme.cream,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _shop == null
              ? const Center(child: Text('Shop not found'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 18, 20, 32),
                    children: [
                      _ShopHeader(shop: _shop!),
                      const SizedBox(height: 20),
                      if (_shop!.coupons?.isNotEmpty == true) ...[
                        const Text(
                          'Current Offer',
                          style: TextStyle(color: GameTheme.ink, fontSize: 16, fontWeight: FontWeight.w900),
                        ),
                        const SizedBox(height: 10),
                        CouponCard(
                          coupon: _shop!.coupons!.first,
                          onTap: () => context.push('/consumer/offer/${_shop!.coupons!.first.id}'),
                        ),
                      ] else
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: GameTheme.panel(color: GameTheme.cream),
                          child: const Text(
                            'No live offer right now. Check back when the shop, weather, and time line up.',
                            style: TextStyle(color: GameTheme.bark, fontWeight: FontWeight.w700, height: 1.4),
                          ),
                        ),
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
      case 'quiet':
        return GameTheme.grass;
      case 'busy':
        return GameTheme.berry;
      default:
        return GameTheme.carrot;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: GameTheme.panel(color: GameTheme.cream),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: GameTheme.inset(color: GameTheme.parchment, border: GameTheme.carrot),
            child: const Icon(Icons.storefront, color: GameTheme.carrot, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  shop.name,
                  style: const TextStyle(color: GameTheme.ink, fontSize: 18, fontWeight: FontWeight.w900),
                ),
                Text(shop.category, style: const TextStyle(color: GameTheme.bark, fontWeight: FontWeight.w700)),
                if (shop.address != null)
                  Text(shop.address!, style: const TextStyle(fontSize: 12, color: GameTheme.soil)),
              ],
            ),
          ),
          Column(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: GameTheme.parchment,
                  borderRadius: BorderRadius.circular(GameTheme.radius),
                  border: Border.all(color: _busynessColor, width: 2),
                ),
                child: Text(
                  shop.busyness,
                  style: TextStyle(color: _busynessColor, fontSize: 12, fontWeight: FontWeight.w900),
                ),
              ),
              if (shop.activeCouponCount > 0) ...[
                const SizedBox(height: 4),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: GameTheme.parchment,
                    borderRadius: BorderRadius.circular(GameTheme.radius),
                    border: Border.all(color: GameTheme.carrot, width: 2),
                  ),
                  child: const Text(
                    '1 offer',
                    style: TextStyle(color: GameTheme.carrot, fontSize: 12, fontWeight: FontWeight.w900),
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}
