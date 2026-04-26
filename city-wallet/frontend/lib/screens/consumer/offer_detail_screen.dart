import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../models/coupon.dart';
import '../../services/api_service.dart';
import '../../theme/game_theme.dart';
import '../../widgets/coupon_scene_templates.dart';

class OfferDetailScreen extends StatefulWidget {
  final String offerId;
  const OfferDetailScreen({super.key, required this.offerId});

  @override
  State<OfferDetailScreen> createState() => _OfferDetailScreenState();
}

class _OfferDetailScreenState extends State<OfferDetailScreen> {
  Coupon? _coupon;
  bool _loading = true;
  bool _showWhyNow = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final c = await context.read<ApiService>().getCoupon(int.parse(widget.offerId));
      if (mounted) {
        setState(() {
          _coupon = c;
          _loading = false;
        });
      }
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showQR() {
    if (_coupon?.qrToken == null) return;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        backgroundColor: GameTheme.cream,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(GameTheme.radius),
          side: const BorderSide(color: GameTheme.bark, width: 3),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: GameTheme.inset(color: Colors.white, border: GameTheme.bark),
                child: QrImageView(
                  data: _coupon!.qrToken!,
                  size: 220,
                  backgroundColor: Colors.white,
                  eyeStyle: const QrEyeStyle(eyeShape: QrEyeShape.square, color: GameTheme.ink),
                  dataModuleStyle: const QrDataModuleStyle(dataModuleShape: QrDataModuleShape.square, color: GameTheme.ink),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                _coupon!.headline,
                textAlign: TextAlign.center,
                style: const TextStyle(color: GameTheme.ink, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 4),
              const Text(
                'Show this to the merchant',
                style: TextStyle(color: GameTheme.bark, fontSize: 13, fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 16),
              TextButton(onPressed: () => Navigator.pop(context), child: const Text('Close')),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFFF7DF),
      appBar: AppBar(
        title: const Text('Reward Ticket'),
        backgroundColor: GameTheme.cream,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _coupon == null
              ? const Center(child: Text('Offer not found'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 18, 20, 32),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _HeroTicket(coupon: _coupon!),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: GameTheme.panel(color: GameTheme.cream),
                        child: CouponPixelScene(coupon: _coupon!, height: 140),
                      ),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: GameTheme.panel(color: GameTheme.cream),
                        child: Text(
                          _coupon!.bodyText,
                          style: const TextStyle(
                            color: GameTheme.ink,
                            fontSize: 15,
                            height: 1.5,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      if (_coupon!.isRedeemed)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: GameTheme.inset(color: const Color(0xFFDDF1B4), border: GameTheme.grass),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle, color: Colors.green.shade800),
                              const SizedBox(width: 8),
                              Text(
                                'Redeemed',
                                style: TextStyle(color: Colors.green.shade800, fontWeight: FontWeight.w900, fontSize: 16),
                              ),
                            ],
                          ),
                        )
                      else if (_coupon!.isActive) ...[
                        FilledButton.icon(
                          onPressed: _showQR,
                          icon: const Icon(Icons.qr_code),
                          label: const Text('View QR Code'),
                          style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14)),
                        ),
                        if (_coupon!.expiresAt != null) ...[
                          const SizedBox(height: 8),
                          Text(
                            'Expires: ${_coupon!.expiresAt}',
                            textAlign: TextAlign.center,
                            style: const TextStyle(color: GameTheme.soil, fontSize: 12, fontWeight: FontWeight.w700),
                          ),
                        ],
                      ],
                      if (_coupon!.whyNow != null) ...[
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: () => setState(() => _showWhyNow = !_showWhyNow),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: GameTheme.inset(color: const Color(0xFFE8F3C5), border: GameTheme.grass),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    const Icon(Icons.lightbulb_outlined, color: GameTheme.grass, size: 18),
                                    const SizedBox(width: 8),
                                    const Text(
                                      'Why this offer?',
                                      style: TextStyle(color: GameTheme.ink, fontWeight: FontWeight.w900),
                                    ),
                                    const Spacer(),
                                    Icon(_showWhyNow ? Icons.expand_less : Icons.expand_more, color: GameTheme.bark),
                                  ],
                                ),
                                if (_showWhyNow) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    _coupon!.whyNow!,
                                    style: const TextStyle(color: GameTheme.bark, height: 1.5, fontWeight: FontWeight.w600),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
    );
  }
}

class _HeroTicket extends StatelessWidget {
  final Coupon coupon;

  const _HeroTicket({required this.coupon});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: GameTheme.panel(color: GameTheme.parchment),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PixelMotif(color: GameTheme.mint, size: 6),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (coupon.shopName != null) Text(coupon.shopName!, style: GameTheme.label),
                    if (coupon.address != null) Text(coupon.address!, style: const TextStyle(color: GameTheme.soil, fontSize: 12)),
                    const SizedBox(height: 10),
                    Text(coupon.headline, style: GameTheme.title.copyWith(fontSize: 24, height: 1.14)),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: GameTheme.inset(color: const Color(0xFFFFF8DF), border: GameTheme.wheat),
            child: Text(
              'OFFER ON: ${coupon.offerTarget}',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(color: GameTheme.bark, fontSize: 12, fontWeight: FontWeight.w900),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _RewardStat(
                  value: '${coupon.discountPct.toStringAsFixed(0)}%',
                  label: 'Discount',
                  color: GameTheme.carrot,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _RewardStat(
                  value: 'EUR ${coupon.cashbackEur.toStringAsFixed(2)}',
                  label: 'Cashback',
                  color: GameTheme.grass,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _RewardStat extends StatelessWidget {
  final String value;
  final String label;
  final Color color;

  const _RewardStat({required this.value, required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: GameTheme.inset(color: GameTheme.cream, border: color),
      child: Column(
        children: [
          Text(
            value,
            textAlign: TextAlign.center,
            style: TextStyle(color: color, fontSize: 20, fontWeight: FontWeight.w900, height: 1.05),
          ),
          const SizedBox(height: 4),
          Text(label.toUpperCase(), style: const TextStyle(color: GameTheme.bark, fontSize: 11, fontWeight: FontWeight.w900)),
        ],
      ),
    );
  }
}
