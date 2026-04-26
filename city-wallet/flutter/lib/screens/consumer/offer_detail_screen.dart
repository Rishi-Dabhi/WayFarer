import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../models/coupon.dart';
import '../../services/api_service.dart';

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
      if (mounted) setState(() { _coupon = c; _loading = false; });
    } catch (_) {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _showQR() {
    if (_coupon?.qrToken == null) return;
    showDialog(
      context: context,
      builder: (_) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              QrImageView(
                data: _coupon!.qrToken!,
                size: 240,
                backgroundColor: Colors.white,
              ),
              const SizedBox(height: 16),
              Text(_coupon!.headline, textAlign: TextAlign.center, style: const TextStyle(fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Text('Show this to the merchant', style: TextStyle(color: Colors.grey.shade600, fontSize: 13)),
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
      backgroundColor: const Color(0xFFF9FAFB),
      appBar: AppBar(
        title: const Text('Offer Detail'),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _coupon == null
              ? const Center(child: Text('Offer not found'))
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Shop meta
                      if (_coupon!.shopName != null)
                        Text(_coupon!.shopName!,
                            style: TextStyle(color: Colors.grey.shade600, fontSize: 14)),
                      if (_coupon!.address != null)
                        Text(_coupon!.address!,
                            style: TextStyle(color: Colors.grey.shade500, fontSize: 12)),
                      const SizedBox(height: 12),
                      // Headline
                      Text(_coupon!.headline,
                          style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                      const SizedBox(height: 16),
                      // Stats row
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                children: [
                                  Text('${_coupon!.discountPct.toStringAsFixed(0)}%',
                                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Color(0xFFF97316))),
                                  const Text('Discount', style: TextStyle(color: Colors.grey)),
                                ],
                              ),
                            ),
                            Container(width: 1, height: 40, color: Colors.grey.shade200),
                            Expanded(
                              child: Column(
                                children: [
                                  Text('€${_coupon!.cashbackEur.toStringAsFixed(2)}',
                                      style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: Colors.green)),
                                  const Text('Cashback', style: TextStyle(color: Colors.grey)),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Body
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(_coupon!.bodyText, style: const TextStyle(fontSize: 15, height: 1.5)),
                      ),
                      const SizedBox(height: 16),
                      // Action
                      if (_coupon!.isRedeemed)
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.green.shade50,
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.green.shade200),
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.check_circle, color: Colors.green.shade700),
                              const SizedBox(width: 8),
                              Text('Redeemed', style: TextStyle(color: Colors.green.shade700, fontWeight: FontWeight.bold, fontSize: 16)),
                            ],
                          ),
                        )
                      else if (_coupon!.isActive) ...[
                        FilledButton.icon(
                          onPressed: _showQR,
                          icon: const Icon(Icons.qr_code),
                          label: const Text('View QR Code'),
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.blue,
                            padding: const EdgeInsets.symmetric(vertical: 14),
                          ),
                        ),
                        if (_coupon!.expiresAt != null) ...[
                          const SizedBox(height: 8),
                          Text('Expires: ${_coupon!.expiresAt}',
                              textAlign: TextAlign.center,
                              style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
                        ],
                      ],
                      // Why now
                      if (_coupon!.whyNow != null) ...[
                        const SizedBox(height: 16),
                        GestureDetector(
                          onTap: () => setState(() => _showWhyNow = !_showWhyNow),
                          child: Container(
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: Colors.blue.shade50,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Icon(Icons.lightbulb_outlined, color: Colors.blue.shade700, size: 18),
                                    const SizedBox(width: 8),
                                    const Text('Why this offer?', style: TextStyle(fontWeight: FontWeight.w600)),
                                    const Spacer(),
                                    Icon(_showWhyNow ? Icons.expand_less : Icons.expand_more),
                                  ],
                                ),
                                if (_showWhyNow) ...[
                                  const SizedBox(height: 8),
                                  Text(_coupon!.whyNow!, style: TextStyle(color: Colors.blue.shade800, height: 1.5)),
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
