import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'screens/app_shell.dart';
import 'services/device_manager.dart';
import 'theme/app_theme.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    ChangeNotifierProvider(
      create: (_) => DeviceManager(),
      child: const RetroWaveApp(),
    ),
  );
}

class RetroWaveApp extends StatelessWidget {
  const RetroWaveApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RetroWave',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark(),
      home: const AppShell(),
    );
  }
}
