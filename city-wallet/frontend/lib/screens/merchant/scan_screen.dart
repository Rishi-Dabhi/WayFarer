import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../theme/game_theme.dart';

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
    } catch (_) {
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
    } catch (_) {
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
        _ScanState.scanning || _ScanState.validating =>
          _CameraView(onDetect: _onDetect, loading: _state == _ScanState.validating, error: _error),
        _ScanState.preview =>
          _PreviewView(data: _couponData!, onConfirm: _redeem, onCancel: _reset),
        _ScanState.confirming =>
          const Center(child: CircularProgressIndicator(color: GameTheme.carrot)),
        _ScanState.success =>
          _SuccessView(data: _couponData!, onScanAnother: _reset),
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
            width: 240, height: 240,
            decoration: BoxDecoration(
              border: Border.all(color: GameTheme.carrot, width: 3),
              borderRadius: BorderRadius.circular(GameTheme.radius),
            ),
          ),
        ),
        if (loading)
          Container(
            color: Colors.black54,
            child: const Center(child: CircularProgressIndicator(color: GameTheme.carrot)),
          ),
        Positioned(
          bottom: 60, left: 0, right: 0,
          child: Column(
            children: [
              const Text(
                'Point camera at customer\'s QR code',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white70, fontSize: 14, fontWeight: FontWeight.w700),
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, textAlign: TextAlign.center, style: const TextStyle(color: GameTheme.berry, fontWeight: FontWeight.w700)),
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
      color: const Color(0xFFFFF7DF),
      padding: const EdgeInsets.all(24),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: GameTheme.panel(color: GameTheme.parchment),
            child: Column(
              children: [
                Text(
                  data['headline'] ?? '',
                  style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: GameTheme.ink),
                  textAlign: TextAlign.center,
                ),
                if (data['shop_name'] != null) ...[
                  const SizedBox(height: 6),
                  Text(data['shop_name'], style: const TextStyle(color: GameTheme.bark, fontWeight: FontWeight.w700, fontSize: 13)),
                ],
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(child: _StatBox('$discountPct%', 'Discount', GameTheme.carrot)),
                    const SizedBox(width: 12),
                    Expanded(child: _StatBox('€$cashbackEur', 'Cashback', GameTheme.grass)),
                  ],
                ),
                if (data['body_text'] != null) ...[
                  const SizedBox(height: 14),
                  Text(
                    data['body_text'],
                    style: const TextStyle(color: GameTheme.bark, fontWeight: FontWeight.w700, fontSize: 13),
                    maxLines: 2, overflow: TextOverflow.ellipsis,
                  ),
                ],
              ],
            ),
          ),
          const Spacer(),
          SizedBox(
            width: double.infinity, height: 50,
            child: FilledButton(
              onPressed: onConfirm,
              style: FilledButton.styleFrom(
                backgroundColor: GameTheme.grass,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(GameTheme.radius),
                  side: const BorderSide(color: GameTheme.bark, width: 2),
                ),
              ),
              child: const Text('Confirm Redemption', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900)),
            ),
          ),
          const SizedBox(height: 12),
          TextButton(
            onPressed: onCancel,
            child: const Text('Cancel', style: TextStyle(color: GameTheme.bark, fontWeight: FontWeight.w700)),
          ),
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
      decoration: GameTheme.inset(color: GameTheme.cream, border: color),
      child: Column(
        children: [
          Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
          Text(label, style: TextStyle(color: color.withOpacity(0.8), fontSize: 12, fontWeight: FontWeight.w700)),
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
      color: const Color(0xFFFFF7DF),
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Container(
            padding: const EdgeInsets.all(28),
            decoration: GameTheme.panel(color: GameTheme.parchment),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 72, height: 72,
                  decoration: BoxDecoration(
                    color: GameTheme.grass,
                    borderRadius: BorderRadius.circular(GameTheme.radius),
                    border: Border.all(color: GameTheme.bark, width: 2),
                  ),
                  child: const Icon(Icons.check, color: Colors.white, size: 40),
                ),
                const SizedBox(height: 18),
                const Text('Redeemed!', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: GameTheme.ink)),
                const SizedBox(height: 6),
                Text('€$cashbackEur cashback sent to customer',
                    style: const TextStyle(color: GameTheme.bark, fontWeight: FontWeight.w700)),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity, height: 44,
                  child: FilledButton(
                    onPressed: onScanAnother,
                    child: const Text('Scan Another'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
