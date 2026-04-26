import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';

enum _ScanState { scanning, validating, preview, confirming, success }

class ScanScreen extends StatefulWidget {
  const ScanScreen({super.key});

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  _ScanState _state = _ScanState.scanning;
  Map<String, dynamic>? _couponData;
  String? _qrToken;
  String? _error;
  bool _processed = false;

  void _onDetect(BarcodeCapture capture) {
    if (_state != _ScanState.scanning || _processed) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;
    _processed = true;
    _validate(raw);
  }

  Future<void> _validate(String token) async {
    setState(() { _state = _ScanState.validating; _qrToken = token; _error = null; });
    try {
      final data = await context.read<ApiService>().validateQR(token);
      if (mounted) setState(() { _couponData = data; _state = _ScanState.preview; });
    } catch (e) {
      if (mounted) setState(() { _error = 'Invalid or expired QR code'; _state = _ScanState.scanning; _processed = false; });
    }
  }

  Future<void> _redeem() async {
    final user = context.read<AuthProvider>().user;
    if (user == null || _qrToken == null) return;
    setState(() => _state = _ScanState.confirming);
    try {
      await context.read<ApiService>().redeemCoupon(_qrToken!, user.id);
      if (mounted) setState(() => _state = _ScanState.success);
    } catch (e) {
      if (mounted) setState(() { _error = 'Redemption failed'; _state = _ScanState.preview; });
    }
  }

  void _reset() => setState(() {
    _state = _ScanState.scanning;
    _couponData = null;
    _qrToken = null;
    _error = null;
    _processed = false;
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan QR', style: TextStyle(color: Colors.white)),
        backgroundColor: Colors.transparent,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: switch (_state) {
        _ScanState.scanning || _ScanState.validating => _CameraView(onDetect: _onDetect, loading: _state == _ScanState.validating, error: _error),
        _ScanState.preview => _PreviewView(data: _couponData!, onConfirm: _redeem, onCancel: _reset),
        _ScanState.confirming => const Center(child: CircularProgressIndicator(color: Colors.white)),
        _ScanState.success => _SuccessView(data: _couponData!, onScanAnother: _reset),
      },
    );
  }
}

class _CameraView extends StatelessWidget {
  final void Function(BarcodeCapture) onDetect;
  final bool loading;
  final String? error;

  const _CameraView({required this.onDetect, required this.loading, this.error});

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        MobileScanner(onDetect: onDetect),
        Center(
          child: Container(
            width: 240,
            height: 240,
            decoration: BoxDecoration(
              border: Border.all(color: Colors.orange, width: 3),
              borderRadius: BorderRadius.circular(12),
            ),
          ),
        ),
        if (loading)
          Container(
            color: Colors.black54,
            child: const Center(child: CircularProgressIndicator(color: Colors.orange)),
          ),
        Positioned(
          bottom: 60,
          left: 0,
          right: 0,
          child: Column(
            children: [
              const Text('Point camera at customer\'s QR code',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white70, fontSize: 14)),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, textAlign: TextAlign.center, style: const TextStyle(color: Colors.redAccent)),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PreviewView extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _PreviewView({required this.data, required this.onConfirm, required this.onCancel});

  @override
  Widget build(BuildContext context) {
    final cashbackEur = ((data['cashback_cents'] ?? 0) / 100).toStringAsFixed(2);
    final discountPct = (data['discount_pct'] ?? 0).toStringAsFixed(0);

    return Container(
      color: Colors.white,
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 20),
          Text(data['headline'] ?? '', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold), textAlign: TextAlign.center),
          const SizedBox(height: 8),
          if (data['shop_name'] != null)
            Text(data['shop_name'], style: TextStyle(color: Colors.grey.shade600)),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(child: _StatBox('$discountPct%', 'Discount', Colors.orange)),
              const SizedBox(width: 12),
              Expanded(child: _StatBox('€$cashbackEur', 'Cashback', Colors.green)),
            ],
          ),
          if (data['body_text'] != null) ...[
            const SizedBox(height: 16),
            Text(data['body_text'], style: TextStyle(color: Colors.grey.shade700), maxLines: 2, overflow: TextOverflow.ellipsis),
          ],
          const Spacer(),
          FilledButton(
            onPressed: onConfirm,
            style: FilledButton.styleFrom(
              backgroundColor: Colors.green,
              minimumSize: const Size(double.infinity, 52),
            ),
            child: const Text('Confirm Redemption', style: TextStyle(fontSize: 16)),
          ),
          const SizedBox(height: 12),
          TextButton(onPressed: onCancel, child: const Text('Cancel')),
        ],
      ),
    );
  }
}

class _StatBox extends StatelessWidget {
  final String value, label;
  final Color color;
  const _StatBox(this.value, this.label, this.color);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color)),
          Text(label, style: TextStyle(color: color.withOpacity(0.8), fontSize: 12)),
        ],
      ),
    );
  }
}

class _SuccessView extends StatelessWidget {
  final Map<String, dynamic> data;
  final VoidCallback onScanAnother;

  const _SuccessView({required this.data, required this.onScanAnother});

  @override
  Widget build(BuildContext context) {
    final cashbackEur = ((data['cashback_cents'] ?? 0) / 100).toStringAsFixed(2);
    return Container(
      color: Colors.white,
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
              child: const Icon(Icons.check, color: Colors.white, size: 44),
            ),
            const SizedBox(height: 20),
            const Text('Redeemed!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text('€$cashbackEur cashback sent to customer',
                style: TextStyle(color: Colors.grey.shade600)),
            const SizedBox(height: 32),
            FilledButton(
              onPressed: onScanAnother,
              style: FilledButton.styleFrom(backgroundColor: const Color(0xFFF97316)),
              child: const Text('Scan Another'),
            ),
          ],
        ),
      ),
    );
  }
}
