import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  int? _shopId;

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
      final sid = shopData['id'] ?? shopData['shop_id'];
      if (sid == null) { setState(() => _loading = false); return; }
      _shopId = sid;
      final analytics = await context.read<ApiService>().getAnalytics(sid);
      if (mounted) setState(() { _data = analytics; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _data == null
              ? Center(child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('No shop found'),
                    const SizedBox(height: 8),
                    TextButton(onPressed: _load, child: const Text('Retry')),
                  ],
                ))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      _MetricGrid(data: _data!),
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Recent Redemptions', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                          if (_shopId != null)
                            TextButton(
                              onPressed: () => context.push('/merchant/analytics'),
                              child: const Text('View All →'),
                            ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      ...(_data!['recent_redemptions'] as List? ?? []).take(5).map(
                        (r) => _RedemptionRow(data: r as Map<String, dynamic>),
                      ),
                    ],
                  ),
                ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  final Map<String, dynamic> data;
  const _MetricGrid({required this.data});

  @override
  Widget build(BuildContext context) {
    final metrics = [
      _Metric('Generated Today', '${data['coupons_generated_today'] ?? 0}', Icons.flash_on, Colors.blue),
      _Metric('Redeemed Today', '${data['redemptions_today'] ?? 0}', Icons.check_circle, Colors.green),
      _Metric('Redemption Rate', '${data['redemption_rate_pct'] ?? 0}%', Icons.trending_up, Colors.orange),
      _Metric('Spent Today', '€${((data['wallet_spent_today_cents'] ?? 0) / 100).toStringAsFixed(2)}', Icons.wallet, Colors.purple),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.4,
      children: metrics.map((m) => _MetricCard(metric: m)).toList(),
    );
  }
}

class _Metric {
  final String label, value;
  final IconData icon;
  final Color color;
  const _Metric(this.label, this.value, this.icon, this.color);
}

class _MetricCard extends StatelessWidget {
  final _Metric metric;
  const _MetricCard({required this.metric});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(metric.icon, color: metric.color, size: 22),
          const Spacer(),
          Text(metric.value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
          Text(metric.label, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
        ],
      ),
    );
  }
}

class _RedemptionRow extends StatelessWidget {
  final Map<String, dynamic> data;
  const _RedemptionRow({required this.data});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Expanded(
            child: Text(data['headline'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600)),
          ),
          Text('€${((data['cashback_cents'] ?? 0) / 100).toStringAsFixed(2)}',
              style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
