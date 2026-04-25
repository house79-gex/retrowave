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

  static const _labels = ['Dispositivi', 'Home', 'Radio', 'Bluetooth', 'Setup'];

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
        height: 72,
        backgroundColor: const Color(0xF012151C),
        indicatorColor: AppColors.accSoft,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: [
          _nav(Icons.devices_rounded, _labels[0]),
          _nav(Icons.home_rounded, _labels[1]),
          _nav(Icons.radio_rounded, _labels[2]),
          _nav(Icons.bluetooth_rounded, _labels[3]),
          _nav(Icons.tune_rounded, _labels[4]),
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
