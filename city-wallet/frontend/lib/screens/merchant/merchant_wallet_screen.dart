import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../theme/game_theme.dart';

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
        await _load();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment submitted — balance updates shortly')),
        );
      } else {
        if (res['payment_intent_id'] != null) {
          await context.read<ApiService>().topupConfirm(res['payment_intent_id'] as String);
        }
        await _load();
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Top-up successful')));
      }
    } on StripeException catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(e.error.localizedMessage ?? 'Payment cancelled')),
      );
    } catch (_) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Top-up failed')));
    } finally {
      if (mounted) setState(() => _topping = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final balanceEur = ((_data?['balance_cents'] ?? 0) / 100.0);
    return Scaffold(
      appBar: AppBar(title: const Text('Organisation Wallet')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: GameTheme.carrot))
          : RefreshIndicator(
              color: GameTheme.carrot,
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                children: [
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: GameTheme.panel(color: GameTheme.parchment),
                    child: Column(
                      children: [
                        const PixelMotif(color: GameTheme.carrot, size: 9),
                        const SizedBox(height: 12),
                        const Text('Available Balance', style: TextStyle(color: GameTheme.bark, fontWeight: FontWeight.w700, fontSize: 13)),
                        const SizedBox(height: 6),
                        Text(
                          '€${balanceEur.toStringAsFixed(2)}',
                          style: const TextStyle(fontSize: 36, fontWeight: FontWeight.w900, color: GameTheme.ink),
                        ),
                        const SizedBox(height: 4),
                        const Text('Used for cashback payouts', style: TextStyle(color: GameTheme.soil, fontSize: 12, fontWeight: FontWeight.w700)),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: GameTheme.panel(color: GameTheme.parchment),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Top Up Wallet', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 15, color: GameTheme.ink)),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _amount,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: const InputDecoration(labelText: 'Amount', prefixText: '€ '),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          height: 44,
                          child: FilledButton(
                            onPressed: _topping ? null : _topup,
                            child: _topping
                                ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Text('Add Funds'),
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_data?['topup_history'] is List && (_data!['topup_history'] as List).isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: GameTheme.panel(color: GameTheme.parchment),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Top-up History', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 14, color: GameTheme.ink)),
                          const SizedBox(height: 10),
                          ...(_data!['topup_history'] as List).map((t) => _TopupRow(data: t as Map<String, dynamic>)),
                        ],
                      ),
                    ),
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
          Text(
            status,
            style: TextStyle(
              color: isOk ? GameTheme.grass : GameTheme.carrot,
              fontSize: 11,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}
