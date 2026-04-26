import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/coupon.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../theme/game_theme.dart';
import '../../widgets/coupon_card.dart';

class ConsumerWalletScreen extends StatefulWidget {
  const ConsumerWalletScreen({super.key});

  @override
  State<ConsumerWalletScreen> createState() => _ConsumerWalletScreenState();
}

class _ConsumerWalletScreenState extends State<ConsumerWalletScreen> {
  List<Coupon> _coupons = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    setState(() => _loading = true);
    try {
      final coupons = await context.read<ApiService>().getUserCoupons(user.id);
      if (mounted) setState(() { _coupons = coupons; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7DF),
      appBar: AppBar(
        title: const Text('My Wallet'),
        backgroundColor: GameTheme.cream,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _coupons.isEmpty
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.wallet_outlined, size: 64, color: Colors.grey.shade400),
                      const SizedBox(height: 12),
                      const Text('No coupons yet', style: TextStyle(color: GameTheme.bark, fontWeight: FontWeight.w900)),
                      const SizedBox(height: 4),
                      const Text('Discover shops on the map to get offers', style: TextStyle(fontSize: 12, color: GameTheme.soil)),
                    ],
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView.builder(
                    padding: const EdgeInsets.fromLTRB(16, 18, 20, 28),
                    itemCount: _coupons.length,
                    itemBuilder: (_, i) => CouponCard(
                      coupon: _coupons[i],
                      onTap: () => context.push('/consumer/offer/${_coupons[i].id}'),
                    ),
                  ),
                ),
    );
  }
}

class _CouponTile extends StatelessWidget {
  final Coupon coupon;
  const _CouponTile({required this.coupon});

  Color get _statusColor {
    switch (coupon.status) {
      case 'active': return Colors.green;
      case 'redeemed': return Colors.grey;
      default: return Colors.red;
    }
  }

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
          border: Border.all(color: Colors.grey.shade200),
        ),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              margin: const EdgeInsets.only(right: 12, top: 4),
              decoration: BoxDecoration(color: _statusColor, shape: BoxShape.circle),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(coupon.headline, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                  if (coupon.shopName != null)
                    Text(coupon.shopName!, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text('${coupon.discountPct.toStringAsFixed(0)}% off',
                    style: const TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFF97316))),
                Text('€${coupon.cashbackEur.toStringAsFixed(2)} back',
                    style: TextStyle(fontSize: 12, color: Colors.green.shade700)),
                Text(coupon.status, style: TextStyle(fontSize: 11, color: _statusColor)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
