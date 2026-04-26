import 'package:flutter/foundation.dart';

class Config {
  static String get apiBaseUrl {
    const env = String.fromEnvironment('API_BASE_URL');
    if (env.isNotEmpty) return env;
    if (!kDebugMode) return 'https://your-prod-api.com';
    return kIsWeb ? 'http://localhost:8000' : 'http://10.0.2.2:8000';
  }

  // Location
  static const int foregroundDistanceM = 15;
  static const int foregroundIntervalMs = 10000;
  static const double speedStaticMax = 0.4;
  static const double speedWalkingMax = 3.0;
  static const double offerTriggerDistanceM = 200;
  static const int offerCooldownMs = 180000;

  // Polling
  static const int signalRefreshMs = 60000;
  static const int mapRefreshMs = 60000;
}
