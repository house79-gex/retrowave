import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/device_group.dart';
import '../models/esp_device.dart';
import 'esp32_controller.dart';
import 'mdns_discovery.dart';

/// Stato globale: discovery, polling, gruppi, selezione, target invio.
class DeviceManager extends ChangeNotifier {
  DeviceManager() {
    _loadPrefs();
    _discoveryTimer = Timer.periodic(const Duration(seconds: 12), (_) => refreshDiscovery());
    _pollTimer = Timer.periodic(const Duration(seconds: 5), (_) => pollStatuses());
    unawaited(refreshDiscovery());
  }

  final List<EspDevice> _devices = [];
  List<DeviceGroup> groups = [];
  List<Map<String, String>> recentStations = [];

  /// MAC selezionati per azioni contestuali.
  final Set<String> selectedMacs = {};

  /// Destinatari per Home / Cerca (se vuoto → tutti online).
  final Set<String> targetMacs = {};

  Timer? _discoveryTimer;
  Timer? _pollTimer;
  bool discoveryBusy = false;

  List<EspDevice> get devices => List.unmodifiable(_devices);

  int get onlineCount => _devices.where((d) => d.isOnline).length;

  List<EspDevice> get selectedDevices =>
      _devices.where((d) => selectedMacs.contains(d.mac)).toList();

  List<EspDevice> get targetsResolved {
    if (targetMacs.isEmpty) {
      return _devices.where((d) => d.isOnline).toList();
    }
    return _devices.where((d) => targetMacs.contains(d.mac) && d.isOnline).toList();
  }

  Future<void> _loadPrefs() async {
    final p = await SharedPreferences.getInstance();
    final g = p.getString('retrowave_groups');
    if (g != null) {
      try {
        final list = jsonDecode(g) as List<dynamic>;
        groups = list.map((e) => DeviceGroup.fromJson(Map<String, dynamic>.from(e as Map))).toList();
      } catch (_) {}
    }
    final r = p.getString('retrowave_recent');
    if (r != null) {
      try {
        final list = jsonDecode(r) as List<dynamic>;
        recentStations = list.map((e) => Map<String, String>.from((e as Map).map((k, v) => MapEntry(k.toString(), v.toString())))).toList();
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> _saveGroups() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('retrowave_groups', jsonEncode(groups.map((e) => e.toJson()).toList()));
  }

  Future<void> _saveRecent() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('retrowave_recent', jsonEncode(recentStations));
  }

  Future<void> refreshDiscovery() async {
    if (discoveryBusy) return;
    discoveryBusy = true;
    notifyListeners();
    try {
      final endpoints = await discoverRetrowaveEndpoints();
      for (final ep in endpoints) {
        await _mergeFromEndpoint(ep);
      }
    } finally {
      discoveryBusy = false;
      notifyListeners();
    }
  }

  Future<void> _mergeFromEndpoint(MdnsEndpoint ep) async {
    final ctrl = Esp32Controller(ep.baseUrl);
    final status = await ctrl.getStatus();
    if (status == null) {
      _upsertPending(ep);
      return;
    }
    final mac = (status['mac'] ?? '').toString();
    if (mac.isEmpty) return;
    final name = (status['name'] ?? 'RetroWave').toString();
    final mode = (status['mode'] ?? 'idle').toString();
    final url = status['url']?.toString();
    final vol = int.tryParse('${status['volume'] ?? 10}') ?? 10;
    final playing = status['playing'] == true;

    final host = ep.ipv4?.address ?? ep.host;
    final existing = _devices.indexWhere((d) => d.mac == mac);
    final updated = EspDevice(
      mac: mac,
      displayName: name,
      host: host,
      port: ep.port,
      isOnline: true,
      mode: mode,
      currentUrl: url,
      volume: vol.clamp(0, 21),
      playing: playing,
      stationLabel: _labelFromUrl(url),
    );

    if (existing >= 0) {
      _devices[existing] = updated;
    } else {
      _removePendingForHost(host, ep.port);
      _devices.add(updated);
    }
    notifyListeners();
  }

  void _upsertPending(MdnsEndpoint ep) {
    final key = 'pending:${ep.host}:${ep.port}';
    final host = ep.ipv4?.address ?? ep.host;
    final idx = _devices.indexWhere((d) => d.pendingKey == key || (d.mac.startsWith('pending:') && d.host == host && d.port == ep.port));
    final dev = EspDevice(
      mac: 'pending:${ep.host}:${ep.port}',
      displayName: 'RetroWave',
      host: host,
      port: ep.port,
      isOnline: false,
      pendingKey: key,
    );
    if (idx >= 0) {
      _devices[idx] = dev;
    } else {
      _devices.add(dev);
    }
  }

  void _removePendingForHost(String host, int port) {
    _devices.removeWhere((d) => d.mac.startsWith('pending:') && d.host == host && d.port == port);
  }

  String? _labelFromUrl(String? url) {
    if (url == null || url.isEmpty) return null;
    try {
      final u = Uri.parse(url);
      return u.host;
    } catch (_) {
      return url;
    }
  }

  Future<void> pollStatuses() async {
    var changed = false;
    for (var i = 0; i < _devices.length; i++) {
      final d = _devices[i];
      if (d.mac.startsWith('pending:')) continue;
      final ctrl = Esp32Controller(d.baseUrl);
      final s = await ctrl.getStatus(timeout: const Duration(seconds: 3));
      if (s == null) {
        if (d.isOnline) {
          _devices[i] = d.copyWith(isOnline: false);
          changed = true;
        }
        continue;
      }
      final mode = (s['mode'] ?? d.mode).toString();
      final url = s['url']?.toString();
      final vol = int.tryParse('${s['volume'] ?? d.volume}') ?? d.volume;
      final playing = s['playing'] == true;
      final name = (s['name'] ?? d.displayName).toString();
      _devices[i] = d.copyWith(
        isOnline: true,
        mode: mode,
        currentUrl: url,
        volume: vol.clamp(0, 21),
        playing: playing,
        displayName: name,
        stationLabel: _labelFromUrl(url),
      );
      changed = true;
    }
    if (changed) notifyListeners();
  }

  void toggleSelection(String mac) {
    if (selectedMacs.contains(mac)) {
      selectedMacs.remove(mac);
    } else {
      selectedMacs.add(mac);
    }
    _syncDeviceSelectedFlags();
    notifyListeners();
  }

  void clearSelection() {
    selectedMacs.clear();
    _syncDeviceSelectedFlags();
    notifyListeners();
  }

  void _syncDeviceSelectedFlags() {
    for (var i = 0; i < _devices.length; i++) {
      _devices[i] = _devices[i].copyWith(isSelected: selectedMacs.contains(_devices[i].mac));
    }
  }

  void selectGroup(DeviceGroup? g) {
    selectedMacs.clear();
    if (g != null) {
      for (final mac in g.deviceMacs) {
        if (_devices.any((d) => d.mac == mac)) selectedMacs.add(mac);
      }
    } else {
      for (final d in _devices) {
        if (d.isOnline && !d.mac.startsWith('pending:')) selectedMacs.add(d.mac);
      }
    }
    _syncDeviceSelectedFlags();
    notifyListeners();
  }

  void toggleTarget(String mac) {
    if (targetMacs.contains(mac)) {
      targetMacs.remove(mac);
    } else {
      targetMacs.add(mac);
    }
    notifyListeners();
  }

  void setAllTargets() {
    targetMacs.clear();
    notifyListeners();
  }

  Future<void> playUrlOnTargets(String url, {String? label}) async {
    final list = targetsResolved.where((d) => !d.mac.startsWith('pending:')).toList();
    if (list.isEmpty) return;
    await Future.wait(list.map((d) => Esp32Controller(d.baseUrl).playStream(url)));
    _pushRecent(name: label ?? url, url: url);
    await pollStatuses();
  }

  Future<void> playUrlOnSelected(String url, {String? label}) async {
    final macs = selectedMacs.isNotEmpty ? selectedMacs : targetMacs;
    final list = macs.isEmpty
        ? targetsResolved
        : _devices.where((d) => macs.contains(d.mac) && d.isOnline && !d.mac.startsWith('pending:')).toList();
    await Future.wait(list.map((d) => Esp32Controller(d.baseUrl).playStream(url)));
    _pushRecent(name: label ?? url, url: url);
    await pollStatuses();
  }

  void _pushRecent({required String name, required String url}) {
    recentStations.removeWhere((e) => e['url'] == url);
    recentStations.insert(0, {'name': name, 'url': url});
    if (recentStations.length > 30) recentStations = recentStations.sublist(0, 30);
    unawaited(_saveRecent());
    notifyListeners();
  }

  Future<void> stopTargets() async {
    final list = targetsResolved.where((d) => !d.mac.startsWith('pending:')).toList();
    await Future.wait(list.map((d) => Esp32Controller(d.baseUrl).stop()));
    await pollStatuses();
  }

  Future<void> stopSelected() async {
    final list = selectedDevices.where((d) => d.isOnline && !d.mac.startsWith('pending:')).toList();
    await Future.wait(list.map((d) => Esp32Controller(d.baseUrl).stop()));
    await pollStatuses();
  }

  Future<void> broadcastSameRadio(String url, {String? label}) async {
    final list = selectedDevices.where((d) => d.isOnline && !d.mac.startsWith('pending:')).toList();
    if (list.isEmpty) return;
    await Future.wait(list.map((d) => Esp32Controller(d.baseUrl).playStream(url)));
    _pushRecent(name: label ?? url, url: url);
    await pollStatuses();
  }

  Future<void> broadcastBluetooth() async {
    final list = selectedDevices.where((d) => d.isOnline && !d.mac.startsWith('pending:')).toList();
    await Future.wait(list.map((d) => Esp32Controller(d.baseUrl).toggleBluetooth()));
    await pollStatuses();
  }

  Future<void> syncVolumeSelected() async {
    final list = selectedDevices.where((d) => d.isOnline && !d.mac.startsWith('pending:')).toList();
    if (list.isEmpty) return;
    final v = list.first.volume;
    await Future.wait(list.map((d) => Esp32Controller(d.baseUrl).setVolume(v)));
    await pollStatuses();
  }

  Future<bool> renameDevice(String mac, String newName) async {
    final i = _devices.indexWhere((e) => e.mac == mac);
    if (i < 0) return false;
    final d = _devices[i];
    final ok = await Esp32Controller(d.baseUrl).rename(newName);
    if (ok) {
      _devices[i] = _devices[i].copyWith(displayName: newName);
      notifyListeners();
    }
    return ok;
  }

  Future<void> setVolumeForDevice(String mac, int v) async {
    final i = _devices.indexWhere((e) => e.mac == mac);
    if (i < 0) return;
    await Esp32Controller(_devices[i].baseUrl).setVolume(v);
    await pollStatuses();
  }

  /// Per test/emulatore: aggiunge un dispositivo tramite IP o hostname noto.
  Future<bool> addManualHost(String host, {int port = 80}) async {
    final base = port == 80 ? 'http://$host' : 'http://$host:$port';
    final ctrl = Esp32Controller(base);
    final status = await ctrl.getStatus();
    if (status == null) return false;
    final mac = (status['mac'] ?? '').toString();
    if (mac.isEmpty) return false;
    await _mergeFromEndpoint(MdnsEndpoint(host: host, port: port, ipv4: InternetAddress.tryParse(host)));
    return true;
  }

  Future<void> addGroup(String name, List<String> macs) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    groups.add(DeviceGroup(id: id, name: name, deviceMacs: macs));
    await _saveGroups();
    notifyListeners();
  }

  @override
  void dispose() {
    _discoveryTimer?.cancel();
    _pollTimer?.cancel();
    super.dispose();
  }
}
