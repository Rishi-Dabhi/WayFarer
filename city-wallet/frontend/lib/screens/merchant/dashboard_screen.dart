import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../theme/game_theme.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _savingBusiness = false;
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
      if (shopData.isEmpty) {
        if (mounted) setState(() { _shopId = null; _data = null; _loading = false; });
        return;
      }
      final sid = shopData['id'] ?? shopData['shop_id'];
      if (sid == null) { setState(() => _loading = false); return; }
      _shopId = sid;
      final analytics = await context.read<ApiService>().getAnalytics(sid);
      if (mounted) setState(() { _data = analytics; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _openRegisterBusinessDialog() async {
    final shopName = TextEditingController();
    final shopDescription = TextEditingController();
    final shopCategory = TextEditingController(text: 'retail');
    final shopAddress = TextEditingController();
    final shopLat = TextEditingController();
    final shopLng = TextEditingController();
    final maxDiscount = TextEditingController(text: '15');
    final productName = TextEditingController();
    final productDescription = TextEditingController();
    final productPrice = TextEditingController();

    await showDialog<void>(
      context: context,
      useRootNavigator: true,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Register New Business', style: TextStyle(color: GameTheme.ink, fontWeight: FontWeight.w900)),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _tf(shopName, 'Store Name *'),
                  _tf(shopDescription, 'Description'),
                  _tf(shopCategory, 'Category'),
                  _tf(shopAddress, 'Address'),
                  _tf(shopLat, 'Latitude *', type: TextInputType.number),
                  _tf(shopLng, 'Longitude *', type: TextInputType.number),
                  _tf(maxDiscount, 'Max Discount % *', type: TextInputType.number),
                  const SizedBox(height: 8),
                  _tf(productName, 'First Product Name *'),
                  _tf(productDescription, 'First Product Description'),
                  _tf(productPrice, 'First Product Price (€) *', type: TextInputType.number),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: _savingBusiness ? null : () => Navigator.of(dialogCtx, rootNavigator: true).pop(),
              child: const Text('Cancel', style: TextStyle(color: GameTheme.bark)),
            ),
            FilledButton(
              onPressed: _savingBusiness ? null : () async {
                final lat = double.tryParse(shopLat.text.trim());
                final lng = double.tryParse(shopLng.text.trim());
                final discount = int.tryParse(maxDiscount.text.trim());
                final price = double.tryParse(productPrice.text.trim());
                if (shopName.text.trim().isEmpty || productName.text.trim().isEmpty ||
                    lat == null || lng == null || discount == null || price == null || price <= 0) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please fill required fields with valid values.')),
                  );
                  return;
                }
                setDialogState(() => _savingBusiness = true);
                try {
                  final api = context.read<ApiService>();
                  final shop = await api.createMerchantShop({
                    'name': shopName.text.trim(),
                    'description': shopDescription.text.trim(),
                    'category': shopCategory.text.trim().isEmpty ? 'retail' : shopCategory.text.trim(),
                    'latitude': lat, 'longitude': lng,
                    'address': shopAddress.text.trim(),
                    'max_discount_pct': discount,
                  });
                  await api.createProduct({
                    'shop_id': shop['id'],
                    'name': productName.text.trim(),
                    'description': productDescription.text.trim(),
                    'price_cents': (price * 100).round(),
                    'category': 'other',
                    'stock_level': 'normal',
                  });
                  if (context.mounted) Navigator.of(dialogCtx, rootNavigator: true).pop();
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Business registered successfully.')),
                  );
                  await _load();
                } catch (_) {
                  if (mounted) ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Failed to register business.')),
                  );
                } finally {
                  if (ctx.mounted) setDialogState(() => _savingBusiness = false);
                }
              },
              child: Text(_savingBusiness ? 'Saving…' : 'Register'),
            ),
          ],
        ),
      ),
    );

    for (final c in [shopName, shopDescription, shopCategory, shopAddress, shopLat, shopLng, maxDiscount, productName, productDescription, productPrice]) {
      c.dispose();
    }
  }

  Widget _tf(TextEditingController c, String label, {TextInputType? type}) => Padding(
    padding: const EdgeInsets.only(bottom: 10),
    child: TextField(controller: c, keyboardType: type, decoration: InputDecoration(labelText: label)),
  );

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    return Scaffold(
      appBar: AppBar(
        title: Text('Welcome, ${user?.name.split(' ').first ?? 'Merchant'}'),
        actions: [
          IconButton(
            tooltip: 'Register New Business',
            icon: const Icon(Icons.add_business),
            onPressed: _openRegisterBusinessDialog,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: GameTheme.carrot))
          : _data == null
              ? _EmptyState(onRegister: _openRegisterBusinessDialog, onRefresh: _load)
              : RefreshIndicator(
                  color: GameTheme.carrot,
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                    children: [
                      _AddBranchBanner(onTap: _openRegisterBusinessDialog),
                      const SizedBox(height: 14),
                      _MetricGrid(data: _data!),
                      const SizedBox(height: 16),
                      _VisitorsLineChart(
                        data: (_data!['visitors_by_day_14d'] as List? ?? []).cast<Map<String, dynamic>>(),
                      ),
                      const SizedBox(height: 14),
                      _HourlyActivityChart(
                        data: (_data!['coupons_by_hour'] as List? ?? []).cast<Map<String, dynamic>>(),
                      ),
                      const SizedBox(height: 14),
                      _TopProductsChart(
                        data: (_data!['top_products'] as List? ?? []).cast<Map<String, dynamic>>(),
                      ),
                      const SizedBox(height: 14),
                      _RecentRedemptions(
                        data: (_data!['recent_redemptions'] as List? ?? []).cast<Map<String, dynamic>>(),
                        onViewAll: _shopId != null ? () => context.push('/merchant/analytics') : null,
                      ),
                    ],
                  ),
                ),
    );
  }
}

// ──────────────────────────────────────────────
// Widgets
// ──────────────────────────────────────────────

class _EmptyState extends StatelessWidget {
  final VoidCallback onRegister;
  final VoidCallback onRefresh;
  const _EmptyState({required this.onRegister, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: GameTheme.panel(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const PixelMotif(color: GameTheme.carrot, size: 10),
              const SizedBox(height: 16),
              const Text('No business registered yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: GameTheme.ink)),
              const SizedBox(height: 8),
              const Text(
                'Register your business to add store details, products, and discount rules.',
                textAlign: TextAlign.center,
                style: TextStyle(color: GameTheme.bark, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: onRegister,
                icon: const Icon(Icons.add_business),
                label: const Text('Register New Business'),
              ),
              const SizedBox(height: 10),
              TextButton(onPressed: onRefresh, child: const Text('Refresh', style: TextStyle(color: GameTheme.bark))),
            ],
          ),
        ),
      ),
    );
  }
}

class _AddBranchBanner extends StatelessWidget {
  final VoidCallback onTap;
  const _AddBranchBanner({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: GameTheme.inset(color: GameTheme.parchment, border: GameTheme.wheat),
      child: Row(
        children: [
          const Icon(Icons.add_business_outlined, color: GameTheme.carrot, size: 20),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'Add another branch? Register a new business.',
              style: TextStyle(color: GameTheme.bark, fontWeight: FontWeight.w700, fontSize: 13),
            ),
          ),
          GestureDetector(
            onTap: onTap,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: GameTheme.carrot,
                borderRadius: BorderRadius.circular(GameTheme.radius),
                border: Border.all(color: GameTheme.bark, width: 2),
              ),
              child: const Text('Add', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 12)),
            ),
          ),
        ],
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
      _M('Generated Today', '${data['coupons_generated_today'] ?? 0}', Icons.flash_on, GameTheme.water),
      _M('Redeemed Today', '${data['redemptions_today'] ?? 0}', Icons.check_circle, GameTheme.grass),
      _M('Visitors (14d)', '${data['unique_visitors_last_14_days'] ?? 0}', Icons.people, GameTheme.carrot),
      _M('Cashback Today', '€${((data['wallet_spent_today_cents'] ?? 0) / 100).toStringAsFixed(2)}', Icons.wallet, GameTheme.berry),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisSpacing: 12,
      mainAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: metrics.map((m) => _MetricCard(m: m)).toList(),
    );
  }
}

class _M {
  final String label, value;
  final IconData icon;
  final Color color;
  const _M(this.label, this.value, this.icon, this.color);
}

class _MetricCard extends StatelessWidget {
  final _M m;
  const _MetricCard({required this.m});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: GameTheme.panel(color: GameTheme.parchment),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: m.color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(GameTheme.radius),
            ),
            child: Icon(m.icon, color: m.color, size: 18),
          ),
          const Spacer(),
          Text(m.value, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: GameTheme.ink)),
          Text(m.label, style: const TextStyle(color: GameTheme.bark, fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _VisitorsLineChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  const _VisitorsLineChart({required this.data});

  @override
  Widget build(BuildContext context) {
    final points = data.map((e) => (e['visitors'] as num?)?.toDouble() ?? 0).toList();
    final maxY = points.isEmpty ? 1.0 : points.reduce(math.max).clamp(1, 99999).toDouble();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: GameTheme.panel(color: GameTheme.parchment),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 10, height: 10, color: GameTheme.carrot),
              const SizedBox(width: 8),
              const Text('Customer Visits · 14 Days', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: GameTheme.ink)),
            ],
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 120,
            child: CustomPaint(
              painter: _LinePainter(points: points, maxY: maxY),
              child: Container(),
            ),
          ),
          const SizedBox(height: 6),
          const Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('14 days ago', style: TextStyle(fontSize: 10, color: GameTheme.bark, fontWeight: FontWeight.w700)),
              Text('Today', style: TextStyle(fontSize: 10, color: GameTheme.bark, fontWeight: FontWeight.w700)),
            ],
          ),
        ],
      ),
    );
  }
}

class _LinePainter extends CustomPainter {
  final List<double> points;
  final double maxY;
  _LinePainter({required this.points, required this.maxY});

  @override
  void paint(Canvas canvas, Size size) {
    if (points.length < 2) return;
    final n = points.length;
    Offset pt(int i) => Offset(
      (size.width / (n - 1)) * i,
      size.height - (points[i] / maxY) * (size.height - 10),
    );

    // Filled area
    final fillPath = Path()..moveTo(pt(0).dx, size.height);
    for (var i = 0; i < n; i++) fillPath.lineTo(pt(i).dx, pt(i).dy);
    fillPath.lineTo(pt(n - 1).dx, size.height);
    fillPath.close();
    canvas.drawPath(fillPath, Paint()..color = GameTheme.carrot.withOpacity(0.15));

    // Grid lines
    final gridPaint = Paint()..color = GameTheme.wheat.withOpacity(0.6)..strokeWidth = 1;
    for (var i = 1; i <= 3; i++) {
      final y = size.height * i / 4;
      canvas.drawLine(Offset(0, y), Offset(size.width, y), gridPaint);
    }

    // Line
    final linePath = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (var i = 1; i < n; i++) linePath.lineTo(pt(i).dx, pt(i).dy);
    canvas.drawPath(linePath, Paint()
      ..color = GameTheme.carrot
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round);

    // Dots on each point
    final dotPaint = Paint()..color = GameTheme.carrot;
    for (var i = 0; i < n; i++) canvas.drawCircle(pt(i), 3, dotPaint);
  }

  @override
  bool shouldRepaint(covariant _LinePainter old) => old.points != points || old.maxY != maxY;
}

class _HourlyActivityChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  const _HourlyActivityChart({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();
    // Build full 24-hour array
    final counts = List<double>.filled(24, 0);
    for (final h in data) {
      final hour = (h['hour'] as num?)?.toInt() ?? 0;
      if (hour >= 0 && hour < 24) counts[hour] = (h['count'] as num?)?.toDouble() ?? 0;
    }
    final maxCount = counts.reduce(math.max).clamp(1, 9999).toDouble();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: GameTheme.panel(color: GameTheme.parchment),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 10, height: 10, color: GameTheme.water),
              const SizedBox(width: 8),
              const Text('Coupon Activity · By Hour', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: GameTheme.ink)),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 80,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(24, (i) {
                final ratio = counts[i] / maxCount;
                final isActive = counts[i] > 0;
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 1),
                    child: Tooltip(
                      message: '${i}h: ${counts[i].toInt()}',
                      child: Container(
                        height: (70 * ratio).clamp(2, 70),
                        decoration: BoxDecoration(
                          color: isActive ? GameTheme.water : GameTheme.parchment,
                          border: Border.all(color: isActive ? GameTheme.bark : GameTheme.wheat, width: 1),
                          borderRadius: const BorderRadius.vertical(top: Radius.circular(2)),
                        ),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: 4),
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

class _TopProductsChart extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  const _TopProductsChart({required this.data});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();
    final top = data.take(5).toList();
    final maxRedemptions = top.map((p) => (p['redemptions'] as num?)?.toDouble() ?? 0).reduce(math.max).clamp(1, 9999).toDouble();

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: GameTheme.panel(color: GameTheme.parchment),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(width: 10, height: 10, color: GameTheme.grass),
              const SizedBox(width: 8),
              const Text('Top Products', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: GameTheme.ink)),
            ],
          ),
          const SizedBox(height: 14),
          ...top.asMap().entries.map((e) {
            final name = e.value['name'] as String? ?? '';
            final redemptions = (e.value['redemptions'] as num?)?.toDouble() ?? 0;
            final ratio = redemptions / maxRedemptions;
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 20, height: 20,
                    decoration: BoxDecoration(
                      color: e.key == 0 ? GameTheme.carrot : e.key == 1 ? GameTheme.water : GameTheme.grass,
                      borderRadius: BorderRadius.circular(3),
                      border: Border.all(color: GameTheme.bark, width: 1),
                    ),
                    child: Center(
                      child: Text('${e.key + 1}', style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w900)),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: GameTheme.ink), maxLines: 1, overflow: TextOverflow.ellipsis),
                        const SizedBox(height: 4),
                        LayoutBuilder(builder: (ctx, constraints) => Stack(
                          children: [
                            Container(
                              height: 6,
                              width: constraints.maxWidth,
                              decoration: GameTheme.inset(color: GameTheme.cream, border: GameTheme.wheat),
                            ),
                            Container(
                              height: 6,
                              width: constraints.maxWidth * ratio,
                              decoration: BoxDecoration(
                                color: GameTheme.grass,
                                borderRadius: BorderRadius.circular(2),
                              ),
                            ),
                          ],
                        )),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '${redemptions.toInt()}×',
                    style: const TextStyle(color: GameTheme.bark, fontSize: 11, fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _RecentRedemptions extends StatelessWidget {
  final List<Map<String, dynamic>> data;
  final VoidCallback? onViewAll;
  const _RecentRedemptions({required this.data, this.onViewAll});

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: GameTheme.panel(color: GameTheme.parchment),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.receipt_long_outlined, color: GameTheme.carrot, size: 18),
              const SizedBox(width: 8),
              const Expanded(
                child: Text('Recent Redemptions', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: GameTheme.ink)),
              ),
              if (onViewAll != null)
                GestureDetector(
                  onTap: onViewAll,
                  child: const Text('View All →', style: TextStyle(color: GameTheme.carrot, fontWeight: FontWeight.w900, fontSize: 12)),
                ),
            ],
          ),
          const SizedBox(height: 12),
          ...data.take(5).map((r) {
            final cashback = ((r['cashback_cents'] as num?)?.toDouble() ?? 0) / 100;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: GameTheme.inset(color: GameTheme.cream, border: GameTheme.wheat),
              child: Row(
                children: [
                  Container(width: 8, height: 8, color: GameTheme.grass),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      r['headline'] as String? ?? '',
                      style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13, color: GameTheme.ink),
                      maxLines: 1, overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  Text(
                    '€${cashback.toStringAsFixed(2)}',
                    style: const TextStyle(color: GameTheme.grass, fontWeight: FontWeight.w900, fontSize: 13),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }
}
