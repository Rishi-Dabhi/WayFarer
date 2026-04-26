import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../theme/game_theme.dart';

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
      appBar: AppBar(title: const Text('Full Analytics')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: GameTheme.carrot))
          : _data == null
              ? const Center(child: Text('No data', style: TextStyle(color: GameTheme.bark, fontWeight: FontWeight.w700)))
              : RefreshIndicator(
                  color: GameTheme.carrot,
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    children: [
                      _StatsGrid(data: _data!),
                      const SizedBox(height: 14),
                      _CashbackCard(data: _data!),
                      const SizedBox(height: 14),
                      _HourChart(data: _data!),
                      const SizedBox(height: 14),
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
      ('Generated', '${data['coupons_generated_total'] ?? 0}', GameTheme.water),
      ('Redeemed', '${data['redemptions_total'] ?? 0}', GameTheme.grass),
      ('Rate', '${data['redemption_rate_pct'] ?? 0}%', GameTheme.carrot),
      ('Avg Discount', '${data['avg_discount_pct'] ?? 0}%', GameTheme.berry),
      ('Visitors (14d)', '${data['unique_visitors_last_14_days'] ?? 0}', GameTheme.sky),
      ('Visits (14d)', '${data['visits_last_14_days'] ?? 0}', GameTheme.mint),
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
        decoration: GameTheme.panel(color: GameTheme.parchment),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(s.$2, style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900, color: s.$3)),
            Text(s.$1, style: const TextStyle(color: GameTheme.bark, fontSize: 12, fontWeight: FontWeight.w700)),
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
      decoration: GameTheme.panel(color: GameTheme.parchment),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: GameTheme.carrot.withOpacity(0.15),
              borderRadius: BorderRadius.circular(GameTheme.radius),
              border: Border.all(color: GameTheme.bark, width: 1),
            ),
            child: const Icon(Icons.payments_outlined, color: GameTheme.carrot, size: 26),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Total Cashback Paid Out', style: TextStyle(color: GameTheme.bark, fontWeight: FontWeight.w700, fontSize: 12)),
              Text('€$totalEur', style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900, color: GameTheme.ink)),
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

    final counts = List<double>.filled(24, 0);
    for (final h in hours) {
      final idx = (h['hour'] as num?)?.toInt() ?? 0;
      if (idx >= 0 && idx < 24) counts[idx] = (h['count'] as num?)?.toDouble() ?? 0;
    }
    final maxCount = counts.reduce(math.max).clamp(1, 9999).toDouble();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: GameTheme.panel(color: GameTheme.parchment),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Coupons by Hour', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: GameTheme.ink)),
          const SizedBox(height: 16),
          SizedBox(
            height: 90,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(24, (i) {
                final ratio = counts[i] / maxCount;
                final active = counts[i] > 0;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Tooltip(
                      message: '${i}h: ${counts[i].toInt()}',
                      child: Container(
                        height: (80 * ratio).clamp(2, 80),
                        decoration: BoxDecoration(
                          color: active ? GameTheme.carrot : GameTheme.parchment,
                          border: Border.all(color: active ? GameTheme.bark : GameTheme.wheat, width: 1),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 6),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('0h', style: TextStyle(fontSize: 10, color: GameTheme.bark, fontWeight: FontWeight.w700)),
              Text('6h', style: TextStyle(fontSize: 10, color: GameTheme.bark, fontWeight: FontWeight.w700)),
              Text('12h', style: TextStyle(fontSize: 10, color: GameTheme.bark, fontWeight: FontWeight.w700)),
              Text('18h', style: TextStyle(fontSize: 10, color: GameTheme.bark, fontWeight: FontWeight.w700)),
              Text('23h', style: TextStyle(fontSize: 10, color: GameTheme.bark, fontWeight: FontWeight.w700)),
            ],
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
    final maxR = products.map((p) => (p['redemptions'] as num?)?.toDouble() ?? 0).reduce(math.max).clamp(1, 9999).toDouble();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: GameTheme.panel(color: GameTheme.parchment),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Top Products', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: GameTheme.ink)),
          const SizedBox(height: 14),
          ...products.take(5).toList().asMap().entries.map((e) {
            final redemptions = (e.value['redemptions'] as num?)?.toDouble() ?? 0;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 22, height: 22,
                    decoration: BoxDecoration(
                      color: [GameTheme.carrot, GameTheme.water, GameTheme.grass, GameTheme.sky, GameTheme.mint][e.key % 5],
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: GameTheme.bark, width: 1),
                    ),
                    child: Center(child: Text('${e.key + 1}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900))),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(e.value['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: GameTheme.ink), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        LayoutBuilder(builder: (ctx, constraints) => Stack(
                          children: [
                            Container(height: 6, width: constraints.maxWidth, decoration: GameTheme.inset(color: GameTheme.cream, border: GameTheme.wheat)),
                            Container(height: 6, width: constraints.maxWidth * (redemptions / maxR), decoration: BoxDecoration(color: GameTheme.carrot, borderRadius: BorderRadius.circular(2))),
                          ],
                        )),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text('${redemptions.toInt()}×', style: const TextStyle(color: GameTheme.bark, fontSize: 11, fontWeight: FontWeight.w700)),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
