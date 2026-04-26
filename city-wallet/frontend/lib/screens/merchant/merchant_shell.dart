import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/game_theme.dart';

class MerchantShell extends StatelessWidget {
  final StatefulNavigationShell shell;
  const MerchantShell({super.key, required this.shell});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: shell,
      bottomNavigationBar: NavigationBar(
        selectedIndex: shell.currentIndex,
        onDestinationSelected: shell.goBranch,
        backgroundColor: GameTheme.cream,
        indicatorColor: GameTheme.wheat,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: MaterialStateProperty.all(
          const TextStyle(fontWeight: FontWeight.w900, color: GameTheme.ink, fontSize: 12),
        ),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.dashboard_outlined), selectedIcon: Icon(Icons.dashboard), label: 'Dashboard'),
          NavigationDestination(icon: Icon(Icons.inventory_2_outlined), selectedIcon: Icon(Icons.inventory_2), label: 'Products'),
          NavigationDestination(icon: Icon(Icons.tune_outlined), selectedIcon: Icon(Icons.tune), label: 'Campaign'),
          NavigationDestination(icon: Icon(Icons.qr_code_scanner), label: 'Scan'),
          NavigationDestination(icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: 'Profile'),
        ],
      ),
    );
  }
}
