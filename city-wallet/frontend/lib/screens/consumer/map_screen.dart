import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../models/shop.dart';
import '../../providers/auth_provider.dart';
import '../../providers/location_provider.dart';
import '../../services/api_service.dart';
import '../../theme/game_theme.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _mapController = MapController();
  List<Shop> _shops = [];
  bool _loading = false;
  int _radius = 5000;
  Timer? _refreshTimer;
  static const int _greenUserThreshold = 1;
  static const int _orangeUserThreshold = 8;
  static const double _demoLat = 51.5042;
  static const double _demoLng = -0.1050;
  LatLng? _overrideCenter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LocationProvider>().start().then((_) => _loadShops());
      _refreshTimer = Timer.periodic(const Duration(milliseconds: 60000), (_) => _loadShops());
    });
  }

  @override
  void dispose() {
    _refreshTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadShops() async {
    final loc = context.read<LocationProvider>();
    if (!loc.hasRealLocation || loc.lat == null || loc.lng == null) return;
    setState(() => _loading = true);
    try {
      final api = context.read<ApiService>();
      final userId = context.read<AuthProvider>().user?.id;
      await api.autoNearbyCoupons(loc.lat!, loc.lng!, userId: userId, radius: _radius);
      var shops = await api.getMapShops(loc.lat!, loc.lng!, radius: _radius, userId: userId);
      LatLng? centerOverride;

      if (shops.isEmpty) {
        await api.autoNearbyCoupons(_demoLat, _demoLng, userId: userId, radius: _radius, maxCoupons: 3);
        shops = await api.getMapShops(_demoLat, _demoLng, radius: _radius, userId: userId);
        if (shops.isNotEmpty) {
          centerOverride = const LatLng(_demoLat, _demoLng);
        }
      }

      if (mounted) {
        setState(() {
          _shops = shops;
          _overrideCenter = centerOverride;
        });
      }
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _busynessColor(String b) {
    switch (b) {
      case 'quiet': return GameTheme.grass;
      case 'busy': return GameTheme.berry;
      default: return GameTheme.carrot;
    }
  }

  int _dummyUsersInStore(Shop shop) {
    final geoHash = shop.lat.abs().round() + (shop.lng.abs() * 1000).round();
    return ((shop.id * 11 + geoHash + shop.activeCouponCount * 3) % 12) + 1;
  }

  Color _shopMarkerColor(Shop shop) {
    final usersInStore = _dummyUsersInStore(shop);
    if (usersInStore <= _greenUserThreshold) return GameTheme.grass;
    if (usersInStore <= 4) return GameTheme.carrot;
    return GameTheme.berry;
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocationProvider>();
    if (!loc.hasRealLocation || loc.lat == null || loc.lng == null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.my_location, color: GameTheme.carrot, size: 40),
                const SizedBox(height: 16),
                const Text('Enable location to find nearby offers', textAlign: TextAlign.center, style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Text(
                  loc.error ?? 'WayFarer uses your current location instead of demo coordinates.',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: GameTheme.bark),
                ),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed: loc.isLoading ? null : () => context.read<LocationProvider>().start().then((_) => _loadShops()),
                  icon: loc.isLoading
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.location_searching),
                  label: const Text('Use my location'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    final center = _overrideCenter ?? LatLng(loc.lat!, loc.lng!);

    return Scaffold(
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom: 15,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.citywallet.app',
              ),
              MarkerLayer(markers: [
                Marker(
                  point: center,
                  width: 24,
                  height: 24,
                  child: const Icon(Icons.my_location, color: GameTheme.water, size: 24),
                ),
                ..._shops.map((shop) => Marker(
                      point: LatLng(shop.lat, shop.lng),
                      width: 60,
                      height: 60,
                      child: GestureDetector(
                        onTap: () {
                          context.push('/consumer/shop/${shop.id}');
                        },
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: _shopMarkerColor(shop),
                                borderRadius: BorderRadius.circular(6),
                                border: Border.all(color: GameTheme.bark, width: 2),
                                boxShadow: const [BoxShadow(color: GameTheme.soil, blurRadius: 0, offset: Offset(3, 3))],
                              ),
                              child: const Icon(Icons.storefront, color: Colors.white, size: 16),
                            ),
                            if (shop.activeCouponCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: GameTheme.wheat,
                                  borderRadius: BorderRadius.circular(4),
                                  border: Border.all(color: GameTheme.bark),
                                ),
                                child: Text(
                                  '${shop.activeCouponCount}',
                                  style: const TextStyle(color: GameTheme.ink, fontSize: 10, fontWeight: FontWeight.w900),
                                ),
                              ),
                          ],
                        ),
                      ),
                    )),
              ]),
            ],
          ),
          // Top bar
          Positioned(
            top: MediaQuery.of(context).padding.top + 6,
            left: 8,
            right: 8,
            child: _TopBar(
              loading: _loading,
              onRefresh: _loadShops,
            ),
          ),
          // Radius chips
          Positioned(
            top: MediaQuery.of(context).padding.top + 72,
            left: 8,
            right: 8,
            child: _RadiusChips(
              selected: _radius,
              onSelected: (r) {
                setState(() {
                  _radius = r;
                  _shops = [];
                });
                _loadShops();
              },
            ),
          ),
          // Bottom sheet
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _ShopListSheet(
              shops: _shops,
              loading: _loading,
              radius: _radius,
              onExpandRadius: () {
                setState(() {
                  _radius = 5000;
                  _shops = [];
                });
                _loadShops();
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.small(
        onPressed: () => _mapController.move(center, 15),
        backgroundColor: GameTheme.cream,
        child: const Icon(Icons.my_location, color: GameTheme.water),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final bool loading;
  final VoidCallback onRefresh;

  const _TopBar({required this.loading, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: GameTheme.panel(color: GameTheme.cream),
      child: Row(
        children: [
          const Icon(Icons.location_city, color: GameTheme.carrot),
          const SizedBox(width: 8),
          const Text('WayFarer', style: TextStyle(color: GameTheme.ink, fontWeight: FontWeight.w900)),
          const Spacer(),
          loading
              ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
              : IconButton(
                  icon: const Icon(Icons.refresh, size: 20),
                  onPressed: onRefresh,
                  visualDensity: VisualDensity.compact,
                ),
        ],
      ),
    );
  }
}

class _RadiusChips extends StatelessWidget {
  final int selected;
  final void Function(int) onSelected;

  const _RadiusChips({required this.selected, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      clipBehavior: Clip.none,
      child: Row(
        children: [200, 500, 800, 2000, 5000].map((r) {
          final label = r >= 1000 ? '${r ~/ 1000}km' : '${r}m';
          final isSelected = r == selected;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: GestureDetector(
              onTap: () => onSelected(r),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 6),
                decoration: BoxDecoration(
                  color: isSelected ? GameTheme.carrot : GameTheme.cream,
                  borderRadius: BorderRadius.circular(GameTheme.radius),
                  border: Border.all(color: GameTheme.bark, width: 2),
                  boxShadow: const [BoxShadow(color: GameTheme.soil, blurRadius: 0, offset: Offset(2, 2))],
                ),
                child: Text(
                  label,
                  style: TextStyle(
                    color: isSelected ? Colors.white : GameTheme.ink,
                    fontSize: 12,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _ShopListSheet extends StatelessWidget {
  final List<Shop> shops;
  final bool loading;
  final int radius;
  final VoidCallback onExpandRadius;

  const _ShopListSheet({
    required this.shops,
    required this.loading,
    required this.radius,
    required this.onExpandRadius,
  });

  @override
  Widget build(BuildContext context) {
    if (shops.isEmpty) {
      return Container(
        padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
        decoration: const BoxDecoration(
          color: GameTheme.cream,
          borderRadius: BorderRadius.vertical(top: Radius.circular(GameTheme.radius)),
          border: Border(top: BorderSide(color: GameTheme.bark, width: 3)),
          boxShadow: [BoxShadow(color: GameTheme.soil, blurRadius: 0, offset: Offset(0, -4))],
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(color: GameTheme.bark, borderRadius: BorderRadius.circular(2)),
              ),
              const Icon(Icons.storefront_outlined, color: GameTheme.bark),
              const SizedBox(height: 8),
              Text(
                loading ? 'Looking for nearby shops...' : 'No registered shops within ${radius >= 1000 ? '${radius ~/ 1000}km' : '${radius}m'}',
                textAlign: TextAlign.center,
                style: const TextStyle(color: GameTheme.ink, fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                'Seed shops near this emulator location or switch the emulator location to where your shops are.',
                textAlign: TextAlign.center,
                style: const TextStyle(color: GameTheme.bark, fontSize: 12),
              ),
              if (!loading && radius < 5000) ...[
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: onExpandRadius,
                  icon: const Icon(Icons.travel_explore),
                  label: const Text('Search 5km'),
                ),
              ],
            ],
          ),
        ),
      );
    }
    return Container(
      height: 224,
      decoration: const BoxDecoration(
        color: GameTheme.cream,
        borderRadius: BorderRadius.vertical(top: Radius.circular(GameTheme.radius)),
        border: Border(top: BorderSide(color: GameTheme.bark, width: 3)),
        boxShadow: [BoxShadow(color: GameTheme.soil, blurRadius: 0, offset: Offset(0, -4))],
      ),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(color: GameTheme.bark, borderRadius: BorderRadius.circular(2)),
          ),
          Expanded(
            child: ListView.builder(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              itemCount: shops.length,
              itemBuilder: (_, i) => _ShopCard(shop: shops[i]),
            ),
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

class _ShopCard extends StatelessWidget {
  final Shop shop;
  const _ShopCard({required this.shop});

  int get _dummyUsersInStore {
    final geoHash = shop.lat.abs().round() + (shop.lng.abs() * 1000).round();
    return ((shop.id * 11 + geoHash + shop.activeCouponCount * 3) % 12) + 1;
  }

  Color get _markerColor {
    if (_dummyUsersInStore <= _MapScreenState._greenUserThreshold) return GameTheme.grass;
    if (_dummyUsersInStore <= 4) return GameTheme.carrot;
    return GameTheme.berry;
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/consumer/shop/${shop.id}'),
      child: Container(
        width: 210,
        margin: const EdgeInsets.only(right: 16, bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: GameTheme.inset(color: const Color(0xFFFFF8DF), border: GameTheme.wheat),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(shop.name, style: const TextStyle(color: GameTheme.ink, fontWeight: FontWeight.w900), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 12),
            if (shop.coupons?.isNotEmpty == true)
              _OfferPreview(coupon: shop.coupons!.first)
            else
              Text(
                'No live offer yet',
                style: const TextStyle(color: GameTheme.soil, fontSize: 12, fontWeight: FontWeight.w700),
              ),
            const Spacer(),
            Row(
              children: [
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(color: _markerColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 4),
                Text(
                  '$_dummyUsersInStore users',
                  style: const TextStyle(color: GameTheme.ink, fontSize: 12, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                if (shop.activeCouponCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: GameTheme.parchment,
                      borderRadius: BorderRadius.circular(GameTheme.radius),
                      border: Border.all(color: GameTheme.carrot),
                    ),
                    child: Text(
                      '${shop.activeCouponCount} offer${shop.activeCouponCount == 1 ? '' : 's'}',
                      style: const TextStyle(fontSize: 11, color: GameTheme.carrot, fontWeight: FontWeight.w900),
                    ),
                  ),
              ],
            ),
            if (shop.distanceM != null)
              Text('${shop.distanceM!.toStringAsFixed(0)} m away', style: const TextStyle(fontSize: 11, color: GameTheme.soil)),
          ],
        ),
      ),
    );
  }
}

class _OfferPreview extends StatelessWidget {
  final dynamic coupon;
  const _OfferPreview({required this.coupon});

  @override
  Widget build(BuildContext context) {
    final target = coupon.offerTarget as String;
    final headline = coupon.headline as String;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(9),
      decoration: GameTheme.inset(color: GameTheme.parchment, border: GameTheme.carrot),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: GameTheme.carrot,
                  borderRadius: BorderRadius.circular(GameTheme.radius),
                  border: Border.all(color: GameTheme.bark),
                ),
                child: Text(
                  '${coupon.discountPct.toStringAsFixed(0)}% off',
                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.w900),
                ),
              ),
              const Spacer(),
              Text(
                'EUR ${coupon.cashbackEur.toStringAsFixed(2)} back',
                style: const TextStyle(color: GameTheme.grass, fontSize: 10, fontWeight: FontWeight.w900),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            headline,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: GameTheme.ink,
              fontSize: 12,
              fontWeight: FontWeight.w900,
              height: 1.2,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            target,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: GameTheme.bark,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              height: 1.2,
            ),
          ),
        ],
      ),
    );
  }
}