import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';
import '../../models/shop.dart';
import '../../providers/location_provider.dart';
import '../../services/api_service.dart';

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  final _mapController = MapController();
  List<Shop> _shops = [];
  bool _loading = false;
  int _radius = 2000;
  Timer? _refreshTimer;
  int? _selectedShopId;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<LocationProvider>().start();
      _loadShops();
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
    setState(() => _loading = true);
    try {
      final shops = await context.read<ApiService>().getMapShops(loc.lat, loc.lng, radius: _radius);
      if (mounted) setState(() => _shops = shops);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Color _busynessColor(String b) {
    switch (b) {
      case 'quiet': return Colors.green;
      case 'busy': return Colors.red;
      default: return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = context.watch<LocationProvider>();
    final center = LatLng(loc.lat, loc.lng);

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
                  child: const Icon(Icons.my_location, color: Colors.blue, size: 24),
                ),
                ..._shops.map((shop) => Marker(
                      point: LatLng(shop.lat, shop.lng),
                      width: 60,
                      height: 60,
                      child: GestureDetector(
                        onTap: () {
                          setState(() => _selectedShopId = shop.id);
                          context.push('/consumer/shop/${shop.id}');
                        },
                        child: Column(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(6),
                              decoration: BoxDecoration(
                                color: _busynessColor(shop.busyness),
                                shape: BoxShape.circle,
                                boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                              ),
                              child: const Icon(Icons.storefront, color: Colors.white, size: 16),
                            ),
                            if (shop.activeCouponCount > 0)
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                                decoration: BoxDecoration(
                                  color: Colors.deepOrange,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  '${shop.activeCouponCount}',
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
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
            top: MediaQuery.of(context).padding.top + 8,
            left: 16,
            right: 16,
            child: _TopBar(
              movementLabel: loc.movementLabel,
              loading: _loading,
              onRefresh: _loadShops,
            ),
          ),
          // Radius chips
          Positioned(
            top: MediaQuery.of(context).padding.top + 64,
            left: 16,
            child: _RadiusChips(
              selected: _radius,
              onSelected: (r) {
                setState(() => _radius = r);
                _loadShops();
              },
            ),
          ),
          // Bottom sheet
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _ShopListSheet(shops: _shops),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.small(
        onPressed: () => _mapController.move(center, 15),
        backgroundColor: Colors.white,
        child: const Icon(Icons.my_location, color: Colors.blue),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final String movementLabel;
  final bool loading;
  final VoidCallback onRefresh;

  const _TopBar({required this.movementLabel, required this.loading, required this.onRefresh});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
      ),
      child: Row(
        children: [
          const Icon(Icons.location_city, color: Color(0xFFF97316)),
          const SizedBox(width: 8),
          const Text('City Wallet', style: TextStyle(fontWeight: FontWeight.bold)),
          const Spacer(),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: Colors.blue.shade50,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(movementLabel, style: TextStyle(fontSize: 11, color: Colors.blue.shade700)),
          ),
          const SizedBox(width: 8),
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
    return Row(
      children: [200, 500, 800, 2000].map((r) {
        final label = r >= 1000 ? '${r ~/ 1000}km' : '${r}m';
        final isSelected = r == selected;
        return Padding(
          padding: const EdgeInsets.only(right: 6),
          child: GestureDetector(
            onTap: () => onSelected(r),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFF97316) : Colors.white,
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
              ),
              child: Text(
                label,
                style: TextStyle(
                  color: isSelected ? Colors.white : Colors.black87,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        );
      }).toList(),
    );
  }
}

class _ShopListSheet extends StatelessWidget {
  final List<Shop> shops;
  const _ShopListSheet({required this.shops});

  @override
  Widget build(BuildContext context) {
    if (shops.isEmpty) return const SizedBox.shrink();
    return Container(
      height: 200,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 12)],
      ),
      child: Column(
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 8),
            decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2)),
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

  Color get _busynessColor {
    switch (shop.busyness) {
      case 'quiet': return Colors.green;
      case 'busy': return Colors.red;
      default: return Colors.orange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => context.push('/consumer/shop/${shop.id}'),
      child: Container(
        width: 180,
        margin: const EdgeInsets.only(right: 12, bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          border: Border.all(color: Colors.grey.shade200),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(shop.name, style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
            Text(shop.category, style: TextStyle(color: Colors.grey.shade600, fontSize: 12)),
            const Spacer(),
            Row(
              children: [
                Container(
                  width: 8, height: 8,
                  decoration: BoxDecoration(color: _busynessColor, shape: BoxShape.circle),
                ),
                const SizedBox(width: 4),
                Text(shop.busyness, style: const TextStyle(fontSize: 12)),
                const Spacer(),
                if (shop.activeCouponCount > 0)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: Colors.deepOrange.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '${shop.activeCouponCount} offers',
                      style: TextStyle(fontSize: 11, color: Colors.deepOrange.shade700),
                    ),
                  ),
              ],
            ),
            if (shop.distanceM != null)
              Text('${shop.distanceM!.toStringAsFixed(0)} m away', style: TextStyle(fontSize: 11, color: Colors.grey.shade500)),
          ],
        ),
      ),
    );
  }
}
