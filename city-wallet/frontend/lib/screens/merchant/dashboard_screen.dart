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
        if (mounted) {
          setState(() {
            _shopId = null;
            _data = null;
            _loading = false;
          });
        }
        return;
      }
      final sid = shopData['id'] ?? shopData['shop_id'];
      if (sid == null) { setState(() => _loading = false); return; }
      _shopId = sid;
      final analytics = await context.read<ApiService>().getAnalytics(sid);
      if (mounted) {
        setState(() {
          _data = analytics;
          _loading = false;
        });
      }
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
          title: const Text('Register New Business'),
          content: SizedBox(
            width: 420,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _DialogInput(controller: shopName, label: 'Store Name *'),
                  _DialogInput(controller: shopDescription, label: 'Description'),
                  _DialogInput(controller: shopCategory, label: 'Category'),
                  _DialogInput(controller: shopAddress, label: 'Address'),
                  _DialogInput(controller: shopLat, label: 'Latitude *', keyboardType: TextInputType.number),
                  _DialogInput(controller: shopLng, label: 'Longitude *', keyboardType: TextInputType.number),
                  _DialogInput(controller: maxDiscount, label: 'Max Discount % *', keyboardType: TextInputType.number),
                  const SizedBox(height: 8),
                  _DialogInput(controller: productName, label: 'First Product Name *'),
                  _DialogInput(controller: productDescription, label: 'First Product Description'),
                  _DialogInput(controller: productPrice, label: 'First Product Price (€) *', keyboardType: TextInputType.number),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: _savingBusiness
                  ? null
                  : () {
                      FocusManager.instance.primaryFocus?.unfocus();
                      Navigator.of(dialogCtx, rootNavigator: true).pop();
                    },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: _savingBusiness
                  ? null
                  : () async {
                      final lat = double.tryParse(shopLat.text.trim());
                      final lng = double.tryParse(shopLng.text.trim());
                      final discount = int.tryParse(maxDiscount.text.trim());
                      final price = double.tryParse(productPrice.text.trim());
                      if (shopName.text.trim().isEmpty ||
                          productName.text.trim().isEmpty ||
                          lat == null ||
                          lng == null ||
                          discount == null ||
                          price == null ||
                          price <= 0) {
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
                          'latitude': lat,
                          'longitude': lng,
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
                        if (context.mounted) {
                          FocusManager.instance.primaryFocus?.unfocus();
                          Navigator.of(dialogCtx, rootNavigator: true).pop();
                        }
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Business registered successfully.')),
                          );
                        }
                        await _load();
                      } catch (_) {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Failed to register business.')),
                          );
                        }
                      } finally {
                        if (ctx.mounted) setDialogState(() => _savingBusiness = false);
                      }
                    },
              child: Text(_savingBusiness ? 'Saving...' : 'Register'),
            ),
          ],
        ),
      ),
    );

    shopName.dispose();
    shopDescription.dispose();
    shopCategory.dispose();
    shopAddress.dispose();
    shopLat.dispose();
    shopLng.dispose();
    maxDiscount.dispose();
    productName.dispose();
    productDescription.dispose();
    productPrice.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Register New Business',
            icon: const Icon(Icons.add_business, color: Color(0xFFF97316)),
            onPressed: _openRegisterBusinessDialog,
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _data == null
              ? Center(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.store_mall_directory_outlined, size: 56, color: Color(0xFFF97316)),
                        const SizedBox(height: 12),
                        const Text('No business registered yet', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 8),
                        Text(
                          'Register your business to add store details, products, location, and discount rules.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: Colors.grey.shade700),
                        ),
                        const SizedBox(height: 16),
                        FilledButton.icon(
                          onPressed: _openRegisterBusinessDialog,
                          icon: const Icon(Icons.add_business),
                          style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF97316)),
                          label: const Text('Register New Business'),
                        ),
                        const SizedBox(height: 10),
                        TextButton(onPressed: _load, child: const Text('Refresh')),
                      ],
                    ),
                  ),
                )
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.all(16),
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Expanded(
                              child: Text(
                                'Need another branch/store? Register a new business and it will be discoverable on the customer map.',
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                            const SizedBox(width: 10),
                            FilledButton(
                              onPressed: _openRegisterBusinessDialog,
                              style: FilledButton.styleFrom(
                                backgroundColor: const Color(0xFFF97316),
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                              ),
                              child: const Text('Add Business'),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      _MetricGrid(data: _data!),
                      const SizedBox(height: 16),
                      _VisitorsLineChart(data: (_data!['visitors_by_day_14d'] as List? ?? []).cast<Map<String, dynamic>>()),
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
      _Metric('Visitors (14d)', '${data['unique_visitors_last_14_days'] ?? 0}', Icons.people, Colors.orange),
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
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              data['headline'] ?? '',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
          Text(
            '€${((data['cashback_cents'] ?? 0) / 100).toStringAsFixed(2)}',
            style: const TextStyle(color: Colors.green, fontWeight: FontWeight.w600),
          ),
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
    final maxY = points.isEmpty ? 1.0 : points.reduce((a, b) => a > b ? a : b).clamp(1, 9999).toDouble();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Customer Visits (Last 14 Days)', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 10),
          SizedBox(
            height: 140,
            child: CustomPaint(
              painter: _LineChartPainter(points: points, maxY: maxY),
              child: Container(),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: const [
              Text('14 days ago', style: TextStyle(fontSize: 11, color: Colors.grey)),
              Text('Today', style: TextStyle(fontSize: 11, color: Colors.grey)),
            ],
          ),
        ],
      ),
    );
  }
}

class _DialogInput extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final TextInputType? keyboardType;
  const _DialogInput({required this.controller, required this.label, this.keyboardType});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      style: const TextStyle(fontSize: 14),
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
    );
  }
}

class _LineChartPainter extends CustomPainter {
  final List<double> points;
  final double maxY;
  _LineChartPainter({required this.points, required this.maxY});

  @override
  void paint(Canvas canvas, Size size) {
    final axisPaint = Paint()
      ..color = Colors.grey.shade300
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, size.height), Offset(size.width, size.height), axisPaint);

    if (points.length < 2) return;

    final path = Path();
    for (var i = 0; i < points.length; i++) {
      final x = (size.width / (points.length - 1)) * i;
      final y = size.height - (points[i] / maxY) * (size.height - 8);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }

    final linePaint = Paint()
      ..color = const Color(0xFFF97316)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.5;
    canvas.drawPath(path, linePaint);
  }

  @override
  bool shouldRepaint(covariant _LineChartPainter oldDelegate) {
    return oldDelegate.points != points || oldDelegate.maxY != maxY;
  }
}
