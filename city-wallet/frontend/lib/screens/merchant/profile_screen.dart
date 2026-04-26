import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../theme/game_theme.dart';

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
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid amount above 0.')));
      return;
    }
    setState(() => _topping = true);
    try {
      final res = await context.read<ApiService>().topupWallet(user.id, (euros * 100).round());
      final clientSecret = res['client_secret'] as String?;
      final publishableKey = res['publishable_key'] as String?;

      if (clientSecret != null && publishableKey != null && publishableKey.isNotEmpty) {
        Stripe.publishableKey = publishableKey;
        await Stripe.instance.applySettings();
        await Stripe.instance.initPaymentSheet(
          paymentSheetParameters: SetupPaymentSheetParameters(
            paymentIntentClientSecret: clientSecret,
            merchantDisplayName: 'City Wallet',
            style: ThemeMode.light,
          ),
        );
        await Stripe.instance.presentPaymentSheet();
        await _loadWallet();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment submitted — balance updates shortly')),
        );
      } else {
        if (res['payment_intent_id'] != null) {
          await context.read<ApiService>().topupConfirm(res['payment_intent_id'] as String);
        }
        await _loadWallet();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Wallet topped up successfully.')));
      }
    } on StripeException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.error.localizedMessage ?? 'Payment cancelled')),
      );
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Top-up failed. Please try again.')));
    } finally {
      if (mounted) setState(() => _topping = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final balanceEur = ((_wallet?['balance_cents'] ?? 0) / 100.0).toStringAsFixed(2);
    final initial = user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : 'M';

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: GameTheme.panel(color: GameTheme.parchment),
            child: Row(
              children: [
                Container(
                  width: 52, height: 52,
                  decoration: GameTheme.inset(color: GameTheme.carrot, border: GameTheme.bark),
                  child: Center(
                    child: Text(initial, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w900)),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        user?.name.isNotEmpty == true ? user!.name : 'Merchant',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w900, color: GameTheme.ink),
                      ),
                      Text(user?.email ?? '', style: const TextStyle(color: GameTheme.bark, fontSize: 13, fontWeight: FontWeight.w700)),
                      const SizedBox(height: 4),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: GameTheme.carrot.withOpacity(0.15),
                          borderRadius: BorderRadius.circular(GameTheme.radius),
                          border: Border.all(color: GameTheme.carrot.withOpacity(0.4), width: 1),
                        ),
                        child: const Text('merchant', style: TextStyle(fontSize: 11, color: GameTheme.carrot, fontWeight: FontWeight.w700)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (_loadingWallet)
            const Center(child: Padding(padding: EdgeInsets.all(16), child: CircularProgressIndicator(color: GameTheme.carrot)))
          else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: GameTheme.panel(color: GameTheme.parchment),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.account_balance_wallet, color: GameTheme.carrot, size: 22),
                      const SizedBox(width: 8),
                      const Text('Wallet Balance', style: TextStyle(fontWeight: FontWeight.w900, color: GameTheme.ink)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Text('€$balanceEur', style: const TextStyle(fontSize: 28, fontWeight: FontWeight.w900, color: GameTheme.ink)),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _amount,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: const InputDecoration(labelText: 'Add Amount', prefixText: '€ '),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    height: 44,
                    child: FilledButton(
                      onPressed: _topping ? null : _topup,
                      child: _topping
                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                          : const Text('Add Funds'),
                    ),
                  ),
                ],
              ),
            ),
            if (_wallet?['topup_history'] is List && (_wallet!['topup_history'] as List).isNotEmpty) ...[
              const SizedBox(height: 14),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: GameTheme.panel(color: GameTheme.parchment),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Top-up History', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: GameTheme.ink)),
                    const SizedBox(height: 10),
                    ...(_wallet!['topup_history'] as List).map((t) => _HistoryRow(data: t as Map<String, dynamic>)),
                  ],
                ),
              ),
            ],
          ],
          const SizedBox(height: 16),
          OutlinedButton.icon(
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (dialogContext) => AlertDialog(
                  title: const Text('Log out', style: TextStyle(color: GameTheme.ink, fontWeight: FontWeight.w900)),
                  content: const Text('You will need to sign in again.', style: TextStyle(color: GameTheme.bark)),
                  actions: [
                    TextButton(onPressed: () => Navigator.of(dialogContext).pop(false), child: const Text('Cancel', style: TextStyle(color: GameTheme.bark))),
                    TextButton(onPressed: () => Navigator.of(dialogContext).pop(true), child: const Text('Log out', style: TextStyle(color: GameTheme.berry, fontWeight: FontWeight.w900))),
                  ],
                ),
              );
              if (ok != true) return;
              await context.read<AuthProvider>().logout();
            },
            icon: const Icon(Icons.logout, color: GameTheme.berry),
            label: const Text('Log Out', style: TextStyle(color: GameTheme.berry, fontWeight: FontWeight.w900)),
            style: OutlinedButton.styleFrom(
              side: const BorderSide(color: GameTheme.berry, width: 2),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
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
    final isOk = status == 'succeeded';
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: GameTheme.inset(color: GameTheme.cream, border: GameTheme.wheat),
      child: Row(
        children: [
          Container(width: 8, height: 8, color: isOk ? GameTheme.grass : GameTheme.carrot),
          const SizedBox(width: 10),
          Text('+€$amountEur', style: const TextStyle(fontWeight: FontWeight.w900, color: GameTheme.ink)),
          const Spacer(),
          Text(status, style: TextStyle(color: isOk ? GameTheme.grass : GameTheme.carrot, fontSize: 11, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
