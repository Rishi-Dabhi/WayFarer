import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

class MerchantProfileScreen extends StatefulWidget {
  const MerchantProfileScreen({super.key});

  @override
  State<MerchantProfileScreen> createState() => _MerchantProfileScreenState();
}

class _MerchantProfileScreenState extends State<MerchantProfileScreen> {
  Map<String, dynamic>? _wallet;
  bool _loadingWallet = true;
  bool _topping = false;
  final _amount = TextEditingController(text: '10.00');

  @override
  void initState() {
    super.initState();
    _loadWallet();
  }

  @override
  void dispose() {
    _amount.dispose();
    super.dispose();
  }

  Future<void> _loadWallet() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    setState(() => _loadingWallet = true);
    try {
      final data = await context.read<ApiService>().getWalletBalance(user.id);
      if (mounted) setState(() => _wallet = data);
    } catch (_) {
      if (mounted) setState(() => _wallet = null);
    } finally {
      if (mounted) setState(() => _loadingWallet = false);
    }
  }

  Future<void> _topup() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    final euros = double.tryParse(_amount.text.trim());
    if (euros == null || euros <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Enter a valid amount above 0.')),
      );
      return;
    }
    setState(() => _topping = true);
    try {
      final res = await context.read<ApiService>().topupWallet(user.id, (euros * 100).round());
      if (res['payment_intent_id'] != null) {
        await context.read<ApiService>().topupConfirm(res['payment_intent_id']);
      }
      await _loadWallet();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Wallet topped up successfully.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Top-up failed. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _topping = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final balanceEur = ((_wallet?['balance_cents'] ?? 0) / 100.0).toStringAsFixed(2);

    return Scaffold(
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user?.name.isNotEmpty == true ? user!.name : 'Merchant',
                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  user?.email ?? '',
                  style: TextStyle(color: Colors.grey.shade700),
                ),
                const SizedBox(height: 10),
                const Text(
                  'Role: merchant',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          if (_loadingWallet)
            const Center(child: Padding(
              padding: EdgeInsets.symmetric(vertical: 8),
              child: CircularProgressIndicator(),
            ))
          else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.orange.shade200),
              ),
              child: Row(
                children: [
                  const Icon(Icons.account_balance_wallet, color: Color(0xFFF97316), size: 30),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text('Wallet Balance', style: TextStyle(fontSize: 12, color: Colors.grey)),
                      Text('€$balanceEur', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Add Money to Wallet', style: TextStyle(fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _amount,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      prefixText: '€ ',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _topping ? null : _topup,
                      style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF97316)),
                      child: _topping
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                            )
                          : const Text('Add Funds'),
                    ),
                  ),
                ],
              ),
            ),
            if (_wallet?['topup_history'] is List && (_wallet!['topup_history'] as List).isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Wallet History', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
              const SizedBox(height: 8),
              ...(_wallet!['topup_history'] as List).map(
                (t) => _HistoryRow(data: t as Map<String, dynamic>),
              ),
            ],
            const SizedBox(height: 10),
          ],
          FilledButton.tonal(
            style: FilledButton.styleFrom(
              foregroundColor: Colors.red,
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('Log out'),
                  content: const Text('You will need to sign in again.'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(false),
                      child: const Text('Cancel'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(dialogContext).pop(true),
                      child: const Text('Log out', style: TextStyle(color: Colors.red)),
                    ),
                  ],
                ),
              );
              if (ok != true) return;
              await context.read<AuthProvider>().logout();
            },
            child: const Text('Log Out'),
          ),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final Map<String, dynamic> data;
  const _HistoryRow({required this.data});

  @override
  Widget build(BuildContext context) {
    final amountEur = ((data['amount_cents'] ?? 0) / 100.0).toStringAsFixed(2);
    final status = (data['status'] ?? 'pending').toString();
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(10)),
      child: Row(
        children: [
          Text('+€$amountEur', style: const TextStyle(fontWeight: FontWeight.bold)),
          const Spacer(),
          Text(
            status,
            style: TextStyle(
              color: status == 'succeeded' ? Colors.green : Colors.amber.shade700,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }
}
