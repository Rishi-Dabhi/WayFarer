import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import '../config.dart';
import '../services/location_service.dart';

enum MovementState { stationary, walking, movingFast }

class LocationProvider extends ChangeNotifier {
  final LocationService _service;
  StreamSubscription<Position>? _sub;

  double _lat = Config.demoLat;
  double _lng = Config.demoLng;
  double _speed = 0;
  bool _hasRealLocation = false;

  LocationProvider(this._service);

  double get lat => _lat;
  double get lng => _lng;
  bool get hasRealLocation => _hasRealLocation;

  MovementState get movementState {
    if (_speed < Config.speedStaticMax) return MovementState.stationary;
    if (_speed < Config.speedWalkingMax) return MovementState.walking;
    return MovementState.movingFast;
  }

  String get movementLabel {
    switch (movementState) {
      case MovementState.stationary: return 'static';
      case MovementState.walking: return 'walking';
      case MovementState.movingFast: return 'moving fast';
    }
  }

  Future<void> start() async {
    final pos = await _service.getCurrent();
    if (pos != null) _update(pos);

    _sub = _service.stream.listen(_update);
  }

  void _update(Position pos) {
    _lat = pos.latitude;
    _lng = pos.longitude;
    _speed = pos.speed.clamp(0, 100);
    _hasRealLocation = true;
    notifyListeners();
  }

  void stop() {
    _sub?.cancel();
    _sub = null;
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}
