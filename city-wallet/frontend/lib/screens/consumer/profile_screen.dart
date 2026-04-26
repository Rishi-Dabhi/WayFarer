import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../models/coupon.dart';
import '../../providers/auth_provider.dart';
import '../../services/api_service.dart';
import '../../theme/game_theme.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  static const _historyLimit = 4;
  List<Coupon> _history = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadHistory());
  }

  Future<void> _loadHistory() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;
    try {
      final coupons = await context.read<ApiService>().getUserCoupons(user.id);
      if (mounted) setState(() => _history = coupons.take(_historyLimit).toList());
    } catch (_) {
      if (mounted) setState(() => _history = []);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final initial = user?.name.isNotEmpty == true ? user!.name[0].toUpperCase() : 'U';

    return Scaffold(
      backgroundColor: const Color(0xFFFFF7DF),
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: GameTheme.cream,
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _loadHistory,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 18, 20, 32),
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: GameTheme.panel(color: GameTheme.cream),
              child: Row(
                children: [
                  Container(
                    width: 58,
                    height: 58,
                    decoration: GameTheme.inset(color: GameTheme.carrot, border: GameTheme.bark),
                    child: Center(
                      child: Text(
                        initial,
                        style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w900),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          user?.name ?? '',
                          style: const TextStyle(color: GameTheme.ink, fontWeight: FontWeight.w900, fontSize: 17),
                        ),
                        if (user?.email.isNotEmpty == true)
                          Text(
                            user!.email,
                            style: const TextStyle(color: GameTheme.bark, fontSize: 13, fontWeight: FontWeight.w700),
                          ),
                      ],
                    ),
                  ),
                  const PixelMotif(color: GameTheme.mint, size: 5),
                ],
              ),
            ),
            const SizedBox(height: 18),
            _HistoryPanel(history: _history),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: GameTheme.panel(color: const Color(0xFFE8F3C5), shadow: GameTheme.grass),
              child: const Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.privacy_tip_outlined, color: GameTheme.grass, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Privacy',
                        style: TextStyle(color: GameTheme.ink, fontWeight: FontWeight.w900, fontSize: 16),
                      ),
                    ],
                  ),
                  SizedBox(height: 12),
                  _PrivacyRow('GPS coordinates are never stored'),
                  _PrivacyRow('Only abstract context signals are sent'),
                  _PrivacyRow('Offer generation uses AI'),
                ],
              ),
            ),
            const SizedBox(height: 22),
            OutlinedButton.icon(
              onPressed: () async {
                await context.read<AuthProvider>().logout();
                if (context.mounted) context.go('/login');
              },
              icon: const Icon(Icons.logout, color: GameTheme.berry),
              label: const Text(
                'Log Out',
                style: TextStyle(color: GameTheme.berry, fontWeight: FontWeight.w900),
              ),
              style: OutlinedButton.styleFrom(
                side: const BorderSide(color: GameTheme.berry, width: 2),
                backgroundColor: GameTheme.cream,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GameTheme.radius)),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryPanel extends StatelessWidget {
  final List<Coupon> history;

  const _HistoryPanel({required this.history});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: GameTheme.panel(color: GameTheme.parchment),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.history, color: GameTheme.carrot, size: 20),
              SizedBox(width: 8),
              Text(
                'Recent History',
                style: TextStyle(color: GameTheme.ink, fontWeight: FontWeight.w900, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (history.isEmpty)
            const Text(
              'No coupon activity yet.',
              style: TextStyle(color: GameTheme.bark, fontWeight: FontWeight.w700),
            )
          else
            ...history.map((coupon) => _HistoryRow(coupon: coupon)),
        ],
      ),
    );
  }
}

class _HistoryRow extends StatelessWidget {
  final Coupon coupon;

  const _HistoryRow({required this.coupon});

  Color get _statusColor {
    switch (coupon.status) {
      case 'redeemed':
        return GameTheme.grass;
      case 'expired':
        return GameTheme.berry;
      default:
        return GameTheme.carrot;
    }
  }

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () => context.push('/consumer/offer/${coupon.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
        decoration: GameTheme.inset(color: GameTheme.cream, border: GameTheme.wheat),
        child: Row(
          children: [
            Container(width: 9, height: 9, color: _statusColor),
            const SizedBox(width: 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    coupon.headline,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: GameTheme.ink, fontWeight: FontWeight.w900, fontSize: 13),
                  ),
                  Text(
                    coupon.shopName ?? coupon.offerTarget,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: GameTheme.bark, fontWeight: FontWeight.w700, fontSize: 11),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              coupon.status.toUpperCase(),
              style: TextStyle(color: _statusColor, fontWeight: FontWeight.w900, fontSize: 10),
            ),
          ],
        ),
      ),
    );
  }
}

class _PrivacyRow extends StatelessWidget {
  final String text;
  const _PrivacyRow(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Container(width: 8, height: 8, color: GameTheme.grass),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: GameTheme.bark, fontSize: 13, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}
