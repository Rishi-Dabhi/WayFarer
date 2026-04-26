import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class AnalyticsScreen extends StatefulWidget {
  const AnalyticsScreen({super.key});

  @override
  State<AnalyticsScreen> createState() => _AnalyticsScreenState();
}

class _AnalyticsScreenState extends State<AnalyticsScreen> {
  Map<String, dynamic>? _data;
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
      final shopData = await context.read<ApiService>().getMerchantShop(user.id);
      final shopId = shopData['id'] ?? shopData['shop_id'];
      if (shopId == null) { setState(() => _loading = false); return; }
      final analytics = await context.read<ApiService>().getAnalytics(shopId);
      if (mounted) setState(() { _data = analytics; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(title: const Text('Full Analytics'), backgroundColor: Colors.white, elevation: 0),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _data == null
              ? const Center(child: Text('No data'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _StatsGrid(data: _data!),
                      const SizedBox(height: 16),
                      _CashbackCard(data: _data!),
                      const SizedBox(height: 16),
                      _HourChart(data: _data!),
                      const SizedBox(height: 16),
                      _TopProducts(data: _data!),
                    ],
                  ),
                ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final Map<String, dynamic> data;
  const _StatsGrid({required this.data});

  @override
  Widget build(BuildContext context) {
    final stats = [
      ('Generated', '${data['coupons_generated_total'] ?? 0}'),
      ('Redeemed', '${data['redemptions_total'] ?? 0}'),
      ('Rate', '${data['redemption_rate_pct'] ?? 0}%'),
      ('Avg Discount', '${data['avg_discount_pct'] ?? 0}%'),
      ('Visitors (14d)', '${data['unique_visitors_last_14_days'] ?? 0}'),
      ('Visits (14d)', '${data['visits_last_14_days'] ?? 0}'),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 2,
      children: stats.map((s) => Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(s.$2, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
            Text(s.$1, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
          ],
        ),
      )).toList(),
    );
  }
}

class _CashbackCard extends StatelessWidget {
  final Map<String, dynamic> data;
  const _CashbackCard({required this.data});

  @override
  Widget build(BuildContext context) {
    final totalEur = ((data['wallet_spent_total_cents'] ?? 0) / 100.0).toStringAsFixed(2);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.orange.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.payments_outlined, color: Color(0xFFF97316), size: 28),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Total Cashback Paid Out', style: TextStyle(color: Colors.grey)),
              Text('€$totalEur', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            ],
          ),
        ],
      ),
    );
  }
}

class _HourChart extends StatelessWidget {
  final Map<String, dynamic> data;
  const _HourChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final hours = (data['coupons_by_hour'] as List? ?? []).cast<Map<String, dynamic>>();
    if (hours.isEmpty) return const SizedBox.shrink();
    final maxCount = hours.map((h) => (h['count'] as num?)?.toDouble() ?? 0).reduce((a, b) => a > b ? a : b);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Coupons by Hour', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 16),
          SizedBox(
            height: 100,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: hours.map((h) {
                final count = (h['count'] as num?)?.toDouble() ?? 0;
                final ratio = maxCount > 0 ? count / maxCount : 0.0;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Container(
                          height: (80 * ratio).clamp(2, 80),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF97316),
                            borderRadius: BorderRadius.circular(3),
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
          const SizedBox(height: 4),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [Text('0h', style: TextStyle(fontSize: 10, color: Colors.grey)), Text('12h', style: TextStyle(fontSize: 10, color: Colors.grey)), Text('23h', style: TextStyle(fontSize: 10, color: Colors.grey))],
          ),
        ],
      ),
    );
  }
}

class _TopProducts extends StatelessWidget {
  final Map<String, dynamic> data;
  const _TopProducts({required this.data});

  @override
  Widget build(BuildContext context) {
    final products = (data['top_products'] as List? ?? []).cast<Map<String, dynamic>>();
    if (products.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Top Products', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 12),
          ...products.take(3).toList().asMap().entries.map((e) => Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 24, height: 24,
                  decoration: const BoxDecoration(color: Color(0xFFF97316), shape: BoxShape.circle),
                  child: Center(child: Text('${e.key + 1}', style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.bold))),
                ),
                const SizedBox(width: 10),
                Expanded(child: Text(e.value['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w500))),
                Text('${e.value['redemptions']} redemptions', style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
              ],
            ),
          )),
        ],
      ),
    );
  }
}
