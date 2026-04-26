import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/location_provider.dart';
import '../../services/api_service.dart';
import '../../services/notification_service.dart';
import '../../theme/game_theme.dart';

class ConsumerShell extends StatefulWidget {
  final StatefulNavigationShell shell;
  const ConsumerShell({super.key, required this.shell});

  @override
  State<ConsumerShell> createState() => _ConsumerShellState();
}

class _ConsumerShellState extends State<ConsumerShell> {
  Timer? _notificationTimer;
  bool _notificationSent = false;
  static const double _fallbackLat = 51.5136;
  static const double _fallbackLng = -0.1365;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _notificationTimer = Timer(const Duration(seconds: 40), _sendNearestNotification);
    });
  }

  Future<void> _sendNearestNotification() async {
    if (!mounted || _notificationSent) return;

    final auth = context.read<AuthProvider>();
    final user = auth.user;
    if (user == null || user.role != 'consumer') return;

    final location = context.read<LocationProvider>();
    if (!location.hasRealLocation || location.lat == null || location.lng == null) {
      await location.start();
    }

    final lat = location.lat;
    final lng = location.lng;
    if (lat == null || lng == null) return;

    final api = context.read<ApiService>();
    await api.autoNearbyCoupons(lat, lng, userId: user.id, radius: 5000, maxCoupons: 3);
    var shops = await api.getMapShops(lat, lng, radius: 5000, userId: user.id);
    var notificationPrefix = 'Nearest';

    if (shops.isEmpty) {
      await api.autoNearbyCoupons(_fallbackLat, _fallbackLng, userId: user.id, radius: 5000, maxCoupons: 3);
      shops = await api.getMapShops(_fallbackLat, _fallbackLng, radius: 5000, userId: user.id);
      notificationPrefix = 'London demo';
    }

    if (shops.isEmpty) return;

    final nearestShop = shops.first;
    final nearestCoupon = nearestShop.coupons?.isNotEmpty == true ? nearestShop.coupons!.first : null;

    await NotificationService.instance.showNearbyNotification(
      notificationId: nearestCoupon?.id ?? nearestShop.id,
      title: nearestCoupon != null
          ? '$notificationPrefix deal at ${nearestShop.name}'
          : '$notificationPrefix shop: ${nearestShop.name}',
      body: nearestCoupon != null
          ? nearestCoupon.headline
          : 'You are near ${nearestShop.name}. Tap to see what is available.',
      route: nearestCoupon != null
          ? '/consumer/offer/${nearestCoupon.id}'
          : '/consumer/shop/${nearestShop.id}',
    );
    _notificationSent = true;
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: widget.shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: widget.shell.currentIndex,
        onDestinationSelected: widget.shell.goBranch,
        backgroundColor: GameTheme.cream,
        indicatorColor: GameTheme.wheat,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: MaterialStateProperty.resolveWith(
          (_) => const TextStyle(fontWeight: FontWeight.w900, color: GameTheme.ink),
        ),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.map_outlined), selectedIcon: Icon(Icons.map), label: 'Discover'),
          NavigationDestination(icon: Icon(Icons.wallet_outlined), selectedIcon: Icon(Icons.wallet), label: 'Wallet'),
          NavigationDestination(icon: Icon(Icons.person_outlined), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
