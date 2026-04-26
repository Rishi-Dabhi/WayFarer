import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../theme/game_theme.dart';

class ConsumerShell extends StatelessWidget {
  final StatefulNavigationShell shell;
  const ConsumerShell({super.key, required this.shell});

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
