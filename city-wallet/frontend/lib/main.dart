import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_stripe/flutter_stripe.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'config.dart';
import 'providers/auth_provider.dart';
import 'providers/location_provider.dart';
import 'services/api_service.dart';
import 'services/location_service.dart';
import 'services/notification_service.dart';
import 'services/storage_service.dart';
import 'theme/game_theme.dart';

import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/consumer/consumer_shell.dart';
import 'screens/consumer/consumer_wallet_screen.dart';
import 'screens/consumer/map_screen.dart';
import 'screens/consumer/offer_detail_screen.dart';
import 'screens/consumer/profile_screen.dart';
import 'screens/consumer/shop_detail_screen.dart';
import 'screens/merchant/analytics_screen.dart';
import 'screens/merchant/campaign_screen.dart';
import 'screens/merchant/dashboard_screen.dart';
import 'screens/merchant/merchant_shell.dart';
import 'screens/merchant/new_product_screen.dart';
import 'screens/merchant/profile_screen.dart';
import 'screens/merchant/products_screen.dart';
import 'screens/merchant/scan_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final stripePk = Config.stripePk;
  if (stripePk.isNotEmpty) {
    Stripe.publishableKey = stripePk;
    await Stripe.instance.applySettings();
  }
  final storage = StorageService();
  final api = ApiService(storage);
  final auth = AuthProvider(api, storage);
  await auth.loadFromStorage();
  await NotificationService.instance.initialize();
  runApp(CityWalletApp(auth: auth, api: api));
}

class CityWalletApp extends StatefulWidget {
  final AuthProvider auth;
  final ApiService api;

  const CityWalletApp({super.key, required this.auth, required this.api});

  @override
  State<CityWalletApp> createState() => _CityWalletAppState();
}

class _CityWalletAppState extends State<CityWalletApp> {
  late final GoRouter _router = _buildRouter();

  @override
  void initState() {
    super.initState();
    NotificationService.instance.setRouteTapHandler((route) {
      _router.go(route);
    });
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: widget.auth),
        Provider.value(value: widget.api),
        ChangeNotifierProvider(create: (_) => LocationProvider(LocationService())),
      ],
      child: MaterialApp.router(
          title: 'WayFarer',
          scrollBehavior: const _AppScrollBehavior(),
          theme: ThemeData(
            colorScheme: ColorScheme.fromSeed(
              seedColor: GameTheme.carrot,
              brightness: Brightness.light,
              primary: GameTheme.carrot,
              secondary: GameTheme.grass,
              surface: GameTheme.cream,
            ),
            useMaterial3: true,
            scaffoldBackgroundColor: const Color(0xFFFFF7DF),
            fontFamily: 'monospace',
            appBarTheme: const AppBarTheme(
              backgroundColor: GameTheme.cream,
              elevation: 0,
              centerTitle: false,
              titleTextStyle: TextStyle(color: GameTheme.ink, fontSize: 18, fontWeight: FontWeight.w900),
              iconTheme: IconThemeData(color: GameTheme.ink),
              surfaceTintColor: Colors.transparent,
            ),
            filledButtonTheme: FilledButtonThemeData(
              style: FilledButton.styleFrom(
                backgroundColor: GameTheme.carrot,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(GameTheme.radius),
                  side: const BorderSide(color: GameTheme.bark, width: 2),
                ),
                textStyle: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
            outlinedButtonTheme: OutlinedButtonThemeData(
              style: OutlinedButton.styleFrom(
                foregroundColor: GameTheme.ink,
                side: const BorderSide(color: GameTheme.bark, width: 2),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GameTheme.radius)),
              ),
            ),
            inputDecorationTheme: InputDecorationTheme(
              filled: true,
              fillColor: GameTheme.cream,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(GameTheme.radius),
                borderSide: const BorderSide(color: GameTheme.bark, width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(GameTheme.radius),
                borderSide: const BorderSide(color: GameTheme.bark, width: 2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(GameTheme.radius),
                borderSide: const BorderSide(color: GameTheme.carrot, width: 2),
              ),
              labelStyle: const TextStyle(color: GameTheme.bark, fontWeight: FontWeight.w700),
              prefixStyle: const TextStyle(color: GameTheme.bark, fontWeight: FontWeight.w700),
              suffixStyle: const TextStyle(color: GameTheme.bark, fontWeight: FontWeight.w700),
              prefixIconColor: GameTheme.bark,
              suffixIconColor: GameTheme.bark,
            ),
            switchTheme: SwitchThemeData(
              thumbColor: MaterialStateProperty.resolveWith((s) =>
                  s.contains(MaterialState.selected) ? GameTheme.carrot : GameTheme.bark),
              trackColor: MaterialStateProperty.resolveWith((s) =>
                  s.contains(MaterialState.selected) ? GameTheme.wheat : GameTheme.parchment),
            ),
            chipTheme: ChipThemeData(
              selectedColor: GameTheme.carrot,
              backgroundColor: GameTheme.parchment,
              side: const BorderSide(color: GameTheme.bark, width: 1),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(GameTheme.radius)),
              labelStyle: const TextStyle(fontWeight: FontWeight.w700, color: GameTheme.ink),
              secondaryLabelStyle: const TextStyle(fontWeight: FontWeight.w700, color: Colors.white),
            ),
            navigationBarTheme: NavigationBarThemeData(
              backgroundColor: GameTheme.cream,
              indicatorColor: GameTheme.wheat,
              surfaceTintColor: Colors.transparent,
              labelTextStyle: MaterialStateProperty.all(
                const TextStyle(fontWeight: FontWeight.w900, color: GameTheme.ink, fontSize: 12),
              ),
            ),
            dialogTheme: DialogThemeData(
              backgroundColor: GameTheme.parchment,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(GameTheme.radius),
                side: const BorderSide(color: GameTheme.bark, width: 2),
              ),
            ),
          ),
          routerConfig: _router,
        ),
    );
  }

  GoRouter _buildRouter() => GoRouter(
        initialLocation: '/login',
        refreshListenable: widget.auth,
        redirect: (context, state) {
          final loggedIn = widget.auth.isLoggedIn;
          final onAuth = state.matchedLocation.startsWith('/login') ||
              state.matchedLocation.startsWith('/register');
          if (!loggedIn && !onAuth) return '/login';
          if (loggedIn && onAuth) {
            return widget.auth.user?.role == 'merchant' ? '/merchant' : '/consumer';
          }
          return null;
        },
        routes: [
          GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
          GoRoute(path: '/register', builder: (_, __) => const RegisterScreen()),

          // Consumer tabs
          StatefulShellRoute.indexedStack(
            builder: (_, __, shell) => ConsumerShell(shell: shell),
            branches: [
              StatefulShellBranch(routes: [
                GoRoute(
                  path: '/consumer',
                  builder: (_, __) => const MapScreen(),
                  routes: [
                    GoRoute(path: 'shop/:id', builder: (_, s) => ShopDetailScreen(shopId: s.pathParameters['id']!)),
                    GoRoute(path: 'offer/:id', builder: (_, s) => OfferDetailScreen(offerId: s.pathParameters['id']!)),
                  ],
                ),
              ]),
              StatefulShellBranch(routes: [
                GoRoute(path: '/consumer/wallet', builder: (_, __) => const ConsumerWalletScreen()),
              ]),
              StatefulShellBranch(routes: [
                GoRoute(path: '/consumer/profile', builder: (_, __) => const ProfileScreen()),
              ]),
            ],
          ),

          // Merchant tabs
          StatefulShellRoute.indexedStack(
            builder: (_, __, shell) => MerchantShell(shell: shell),
            branches: [
              StatefulShellBranch(routes: [
                GoRoute(
                  path: '/merchant',
                  builder: (_, __) => const DashboardScreen(),
                  routes: [
                    GoRoute(path: 'analytics', builder: (_, __) => const AnalyticsScreen()),
                  ],
                ),
              ]),
              StatefulShellBranch(routes: [
                GoRoute(
                  path: '/merchant/products',
                  builder: (_, __) => const ProductsScreen(),
                  routes: [
                    GoRoute(path: 'new', builder: (_, s) => NewProductScreen(shopId: s.uri.queryParameters['shopId'] ?? '0')),
                  ],
                ),
              ]),
              StatefulShellBranch(routes: [
                GoRoute(path: '/merchant/campaign', builder: (_, __) => const CampaignScreen()),
              ]),
              StatefulShellBranch(routes: [
                GoRoute(path: '/merchant/scan', builder: (_, __) => const ScanScreen()),
              ]),
              StatefulShellBranch(routes: [
                GoRoute(path: '/merchant/profile', builder: (_, __) => const MerchantProfileScreen()),
              ]),
            ],
          ),
        ],
      );
}

class _AppScrollBehavior extends MaterialScrollBehavior {
  const _AppScrollBehavior();

  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.stylus,
        PointerDeviceKind.trackpad,
      };
}
