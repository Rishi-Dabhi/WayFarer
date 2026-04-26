import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class MerchantWalletScreen extends StatefulWidget {
  const MerchantWalletScreen({super.key});

  @override
  State<MerchantWalletScreen> createState() => _MerchantWalletScreenState();
}

class _MerchantWalletScreenState extends State<MerchantWalletScreen> {
  Map<String, dynamic>? _data;
  bool _loading = true;
  bool _topping = false;
  final _amount = TextEditingController(text: '10.00');

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    setState(() => _loading = true);
    try {
      final data = await context.read<ApiService>().getWalletBalance(user.id);
      if (mounted) setState(() { _data = data; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _topup() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    final euros = double.tryParse(_amount.text);
    if (euros == null || euros <= 0) return;
    setState(() => _topping = true);
    try {
      final res = await context.read<ApiService>().topupWallet(user.id, (euros * 100).round());
      if (res['payment_intent_id'] != null) {
        await context.read<ApiService>().topupConfirm(res['payment_intent_id']);
      }
      await _load();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Top-up successful')));
    } catch (_) {} finally {
      if (mounted) setState(() => _topping = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final balanceEur = ((_data?['balance_cents'] ?? 0) / 100.0);
    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(title: const Text('Organisation Wallet'), backgroundColor: Colors.white, elevation: 0),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.orange.shade200, width: 2),
                    ),
                    child: Column(
                      children: [
                        const Icon(Icons.account_balance_wallet, color: Color(0xFFF97316), size: 36),
                        const SizedBox(height: 8),
                        const Text('Available Balance', style: TextStyle(color: Colors.grey)),
                        const SizedBox(height: 4),
                        Text('€${balanceEur.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 36, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('Used for cashback payouts', style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Top Up Wallet', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _amount,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Amount', prefixText: '€ ', border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: FilledButton(
                            onPressed: _topping ? null : _topup,
                            style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF97316)),
                            child: _topping
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Add Funds'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_data?['topup_history'] is List && (_data!['topup_history'] as List).isNotEmpty) ...[
                    const SizedBox(height: 20),
                    const Text('Top-up History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                    const SizedBox(height: 10),
                    ...(_data!['topup_history'] as List).map((t) => _TopupRow(data: t as Map<String, dynamic>)),
                  ],
                ],
              ),
            ),
    );
  }
}

class _TopupRow extends StatelessWidget {
  final Map<String, dynamic> data;
  const _TopupRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final amountEur = ((data['amount_cents'] ?? 0) / 100.0).toStringAsFixed(2);
    final status = data['status'] ?? 'pending';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Text('+€$amountEur', style: const TextStyle(fontWeight: FontWeight.bold)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
            decoration: BoxDecoration(
              color: status == 'succeeded' ? Colors.green.shade50 : Colors.amber.shade50,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(status, style: TextStyle(color: status == 'succeeded' ? Colors.green.shade700 : Colors.amber.shade800, fontSize: 12)),
          ),
        ],
      ),
    );
  }
}
