import 'dart:io' show Platform;

import 'package:android_intent_plus/android_intent.dart';

/// Apre le impostazioni WiFi di sistema (solo Android).
Future<void> openAndroidWifiSettings() async {
  if (!Platform.isAndroid) return;
  const intent = AndroidIntent(
    action: 'android.settings.WIFI_SETTINGS',
  );
  await intent.launch();
}

/// Apre le impostazioni Bluetooth di sistema (solo Android).
Future<void> openAndroidBluetoothSettings() async {
  if (!Platform.isAndroid) return;
  const intent = AndroidIntent(
    action: 'android.settings.BLUETOOTH_SETTINGS',
  );
  await intent.launch();
}
