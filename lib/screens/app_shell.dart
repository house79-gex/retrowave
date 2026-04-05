import 'package:flutter/material.dart';
import '../theme/app_theme.dart';
import 'bluetooth_screen.dart';
import 'devices_screen.dart';
import 'home_screen.dart';
import 'search_screen.dart';
import 'setup_screen.dart';

class AppShell extends StatefulWidget {
  const AppShell({super.key});

  @override
  State<AppShell> createState() => _AppShellState();
}

class _AppShellState extends State<AppShell> {
  int _index = 0;

  static const _labels = ['Dispositivi', 'Home', 'Cerca', 'Spotify', 'Setup'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          DevicesScreen(),
          HomeScreen(),
          SearchScreen(),
          BluetoothScreen(),
          SetupScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        height: 76,
        backgroundColor: const Color(0xF2111318),
        indicatorColor: AppColors.acc.withValues(alpha: 0.15),
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          _nav(Icons.sensors, _labels[0]),
          _nav(Icons.home_outlined, _labels[1]),
          _nav(Icons.search, _labels[2]),
          _nav(Icons.music_note, _labels[3]),
          _nav(Icons.add_circle_outline, _labels[4]),
        ],
      ),
    );
  }

  NavigationDestination _nav(IconData icon, String label) {
    return NavigationDestination(
      icon: Icon(icon, color: AppColors.muted),
      selectedIcon: Icon(icon, color: AppColors.acc),
      label: label,
    );
  }
}
