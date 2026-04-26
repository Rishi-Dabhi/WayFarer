import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class CampaignScreen extends StatefulWidget {
  const CampaignScreen({super.key});

  @override
  State<CampaignScreen> createState() => _CampaignScreenState();
}

class _CampaignScreenState extends State<CampaignScreen> {
  bool _loading = true;
  bool _saving = false;
  int? _shopId;

  bool _active = true;
  bool _autoEnabled = true;
  String _goal = 'fill_quiet_hours';
  final _maxDiscount = TextEditingController(text: '20');
  final _maxCashback = TextEditingController(text: '2.00');
  final _radius = TextEditingController(text: '200');
  final _quietThreshold = TextEditingController(text: '30');
  final _frequency = TextEditingController(text: '15');
  List<String> _quietHours = ['09:00-11:00'];

  final _allQuietHours = ['09:00-11:00', '14:00-16:00', '15:00-17:00', '20:00-22:00'];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _maxDiscount.dispose();
    _maxCashback.dispose();
    _radius.dispose();
    _quietThreshold.dispose();
    _frequency.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    setState(() => _loading = true);
    try {
      final shopData = await context.read<ApiService>().getMerchantShop(user.id);
      _shopId = shopData['id'] ?? shopData['shop_id'];
      if (shopData['is_active'] != null) _active = shopData['is_active'];
      if (shopData['auto_coupon_enabled'] != null) _autoEnabled = shopData['auto_coupon_enabled'];
      if (shopData['campaign_goal'] != null) _goal = shopData['campaign_goal'];
      if (shopData['max_discount_pct'] != null) _maxDiscount.text = '${shopData['max_discount_pct']}';
      if (shopData['cashback_budget_per_coupon_cents'] != null)
        _maxCashback.text = (shopData['cashback_budget_per_coupon_cents'] / 100).toStringAsFixed(2);
      if (shopData['auto_trigger_radius_m'] != null) _radius.text = '${shopData['auto_trigger_radius_m']}';
      if (shopData['quiet_threshold_ratio'] != null)
        _quietThreshold.text = '${(shopData['quiet_threshold_ratio'] * 100).round()}';
      if (shopData['coupon_frequency_minutes'] != null) _frequency.text = '${shopData['coupon_frequency_minutes']}';
      if (shopData['target_quiet_hours'] is List) _quietHours = List<String>.from(shopData['target_quiet_hours']);
      if (mounted) setState(() => _loading = false);
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _save() async {
    if (_shopId == null) return;
    setState(() => _saving = true);
    try {
      await context.read<ApiService>().updateShop(_shopId!, {
        'is_active': _active,
        'auto_coupon_enabled': _autoEnabled,
        'campaign_goal': _goal,
        'max_discount_pct': int.tryParse(_maxDiscount.text) ?? 20,
        'cashback_budget_per_coupon_cents': ((double.tryParse(_maxCashback.text) ?? 2.0) * 100).round(),
        'auto_trigger_radius_m': int.tryParse(_radius.text) ?? 200,
        'quiet_threshold_ratio': (int.tryParse(_quietThreshold.text) ?? 30) / 100.0,
        'coupon_frequency_minutes': int.tryParse(_frequency.text) ?? 15,
        'target_quiet_hours': _quietHours,
      });
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Campaign rules saved')));
    } catch (_) {} finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(title: const Text('Campaign Rules'), backgroundColor: Colors.white, elevation: 0),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('The AI creates the actual offer. You set the rules.',
                      style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
                  const SizedBox(height: 16),
                  _card(Column(
                    children: [
                      _SwitchRow('Campaign Active', _active, (v) => setState(() => _active = v)),
                      _SwitchRow('Automatic Coupons', _autoEnabled, (v) => setState(() => _autoEnabled = v)),
                    ],
                  )),
                  const SizedBox(height: 12),
                  _card(Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Campaign Goal', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        children: {
                          'fill_quiet_hours': 'Fill Quiet Hours',
                          'clear_stock': 'Clear Stock',
                          'new_customers': 'Attract New Customers',
                        }.entries.map((e) => ChoiceChip(
                          label: Text(e.value),
                          selected: _goal == e.key,
                          onSelected: (_) => setState(() => _goal = e.key),
                          selectedColor: const Color(0xFFF97316),
                          labelStyle: TextStyle(color: _goal == e.key ? Colors.white : null),
                        )).toList(),
                      ),
                    ],
                  )),
                  const SizedBox(height: 12),
                  _card(Column(
                    children: [
                      _NumField('Max Discount (%)', _maxDiscount, suffix: '%'),
                      const SizedBox(height: 12),
                      _NumField('Max Cashback per Coupon', _maxCashback, prefix: '€'),
                      const SizedBox(height: 12),
                      _NumField('Auto Trigger Radius', _radius, suffix: 'm'),
                      const SizedBox(height: 12),
                      _NumField('Quiet Threshold', _quietThreshold, suffix: '%'),
                      const SizedBox(height: 12),
                      _NumField('Min Frequency', _frequency, suffix: 'min'),
                    ],
                  )),
                  const SizedBox(height: 12),
                  _card(Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Quiet Hours', style: TextStyle(fontWeight: FontWeight.w600)),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        children: _allQuietHours.map((h) => FilterChip(
                          label: Text(h),
                          selected: _quietHours.contains(h),
                          onSelected: (v) => setState(() => v ? _quietHours.add(h) : _quietHours.remove(h)),
                          selectedColor: const Color(0xFFF97316).withOpacity(0.2),
                        )).toList(),
                      ),
                    ],
                  )),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF97316), padding: const EdgeInsets.symmetric(vertical: 14)),
                    child: _saving
                        ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                        : const Text('Save Campaign Rules', style: TextStyle(fontSize: 16)),
                  ),
                ],
              ),
            ),
    );
  }

  Widget _card(Widget child) => Container(
    padding: const EdgeInsets.all(16),
    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
    child: child,
  );
}

class _SwitchRow extends StatelessWidget {
  final String label;
  final bool value;
  final void Function(bool) onChanged;

  const _SwitchRow(this.label, this.value, this.onChanged);

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(label, style: const TextStyle(fontWeight: FontWeight.w500)),
      Switch(value: value, onChanged: onChanged, activeThumbColor: const Color(0xFFF97316)),
    ],
  );
}

class _NumField extends StatelessWidget {
  final String label;
  final TextEditingController controller;
  final String? prefix, suffix;

  const _NumField(this.label, this.controller, {this.prefix, this.suffix});

  @override
  Widget build(BuildContext context) => TextField(
    controller: controller,
    keyboardType: const TextInputType.numberWithOptions(decimal: true),
    decoration: InputDecoration(
      labelText: label,
      prefixText: prefix,
      suffixText: suffix,
      border: const OutlineInputBorder(),
      isDense: true,
    ),
  );
}
