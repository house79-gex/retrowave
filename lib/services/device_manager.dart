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

  /// MAC nascosti: non riappaiono dopo mDNS (rimozione dall'app).
  final Set<String> _ignoredMacs = {};

  /// Endpoint `host:port` nascosti per voci pending.
  final Set<String> _ignoredEndpoints = {};

  /// MAC selezionati per azioni contestuali.
  final Set<String> selectedMacs = {};

  /// Destinatari per Home / Cerca (se vuoto → tutti online).
  final Set<String> targetMacs = {};

  Timer? _discoveryTimer;
  Timer? _pollTimer;
  bool discoveryBusy = false;
  bool _pollBusy = false;
  bool _refreshQueued = false;

  List<EspDevice> get devices => List.unmodifiable(_devices);

  /// Numero di dispositivi nascosti (ripristinabili da Setup).
  int get hiddenDeviceCount => _ignoredMacs.length + _ignoredEndpoints.length;

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
    final ignM = p.getString('retrowave_ignored_macs');
    if (ignM != null) {
      try {
        final list = jsonDecode(ignM) as List<dynamic>;
        _ignoredMacs
          ..clear()
          ..addAll(list.map((e) => normMac(e.toString())));
      } catch (_) {}
    }
    final ignE = p.getString('retrowave_ignored_endpoints');
    if (ignE != null) {
      try {
        final list = jsonDecode(ignE) as List<dynamic>;
        _ignoredEndpoints
          ..clear()
          ..addAll(list.map((e) => e.toString()));
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> _saveIgnored() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('retrowave_ignored_macs', jsonEncode(_ignoredMacs.toList()));
    await p.setString('retrowave_ignored_endpoints', jsonEncode(_ignoredEndpoints.toList()));
  }

  Future<void> _saveGroups() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('retrowave_groups', jsonEncode(groups.map((e) => e.toJson()).toList()));
  }

  Future<void> _saveRecent() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('retrowave_recent', jsonEncode(recentStations));
  }

  /// MAC univoco per confronti (mDNS / firmware possono usare maiuscole diverse).
  static String normMac(String raw) {
    return raw.trim().replaceAll('-', ':').toUpperCase();
  }

  Future<void> refreshDiscovery() async {
    if (_pollBusy) {
      _refreshQueued = true;
      return;
    }
    if (discoveryBusy) return;
    discoveryBusy = true;
    notifyListeners();
    try {
      final endpoints = await discoverRetrowaveEndpoints();
      await Future.wait(endpoints.map(_mergeFromEndpoint));
      _purgeStalePending();
    } finally {
      discoveryBusy = false;
      _dedupeRealDevicesByMac();
      notifyListeners();
    }
  }

  /// Hostname mDNS e IP risolto possono differire: controlla entrambi.
  bool _isEndpointIgnored(MdnsEndpoint ep) {
    final p = ep.port;
    if (_ignoredEndpoints.contains('${ep.host}:$p')) return true;
    final ip = ep.ipv4?.address;
    if (ip != null && _ignoredEndpoints.contains('$ip:$p')) return true;
    return false;
  }

  Future<Map<String, dynamic>?> _statusWithRetry(
    Esp32Controller ctrl, {
    Duration timeout = const Duration(seconds: 3),
  }) async {
    final first = await ctrl.getStatus(timeout: timeout);
    if (first != null) return first;
    return ctrl.getStatus(timeout: timeout);
  }

  Future<void> _mergeFromEndpoint(MdnsEndpoint ep) async {
    if (_isEndpointIgnored(ep)) return;
    final host = ep.ipv4?.address ?? ep.host;

    final ctrl = Esp32Controller(ep.baseUrl);
    final status = await _statusWithRetry(ctrl);
    if (status == null) {
      _upsertPending(ep);
      return;
    }
    final mac = (status['mac'] ?? '').toString();
    if (mac.isEmpty) return;
    if (_ignoredMacs.contains(normMac(mac))) return;
    final name = (status['name'] ?? 'RetroWave').toString();
    final mode = (status['mode'] ?? 'idle').toString();
    final url = status['url']?.toString();
    final vol = int.tryParse('${status['volume'] ?? 10}') ?? 10;
    final playing = status['playing'] == true;

    final existing = _devices.indexWhere(
      (d) => !d.mac.startsWith('pending:') && normMac(d.mac) == normMac(mac),
    );
    final now = DateTime.now().millisecondsSinceEpoch;
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
      stationLabel: _bestStationLabel(status: status, fallbackUrl: url),
      chip: status['chip']?.toString(),
      a2dpSinkCapable: status['a2dp_sink_capable'] is bool ? status['a2dp_sink_capable'] as bool : null,
      a2dpSinkStarted: status['a2dp_sink_started'] == true,
      a2dpConnected: status['a2dp_connected'] == true,
      a2dpPairingName: status['a2dp_pairing_name']?.toString(),
      boardProfile: status['board_profile']?.toString(),
      streamStation: status['stream_station']?.toString(),
      streamTitle: status['stream_title']?.toString(),
      streamIcyUrl: status['stream_icy_url']?.toString(),
      streamIcyDescription: status['stream_icy_description']?.toString(),
      lastSeenMs: now,
    );

    if (existing >= 0) {
      _devices[existing] = updated;
    } else {
      _removePendingForHost(host, ep.port);
      _devices.add(updated);
    }
    _removePendingForEp(ep);
    unawaited(_prunePendingMatchingMac(mac, ep.port));
  }

  /// Rimuove tutti i pending sulla stessa porta che rispondono con lo stesso MAC (hostname vs IP).
  Future<void> _prunePendingMatchingMac(String mac, int port) async {
    final want = normMac(mac);
    final toDrop = <String>[];
    for (final d in List<EspDevice>.from(_devices)) {
      if (!d.mac.startsWith('pending:')) continue;
      if (d.port != port) continue;
      final st = await Esp32Controller(d.baseUrl).getStatus(timeout: const Duration(seconds: 2));
      final m = (st?['mac'] ?? '').toString();
      if (m.isNotEmpty && normMac(m) == want) {
        toDrop.add(d.mac);
      }
    }
    if (toDrop.isEmpty) return;
    _devices.removeWhere((d) => toDrop.contains(d.mac));
    notifyListeners();
  }

  void _removePendingForEp(MdnsEndpoint ep) {
    final hIp = ep.ipv4?.address;
    final hName = ep.host;
    _devices.removeWhere((d) {
      if (!d.mac.startsWith('pending:')) return false;
      if (d.port != ep.port) return false;
      return d.host == hName || d.host == hIp || d.pendingKey == 'pending:$hName:${ep.port}';
    });
  }

  /// Un solo dispositivo reale per MAC (stesso ESP visto su piu endpoint).
  EspDevice _preferEspDevice(EspDevice a, EspDevice b) {
    final aRen = !a.displayName.toLowerCase().startsWith('retrowave');
    final bRen = !b.displayName.toLowerCase().startsWith('retrowave');
    if (aRen && !bRen) return a;
    if (!aRen && bRen) return b;
    if (a.isOnline && !b.isOnline) return a;
    if (!a.isOnline && b.isOnline) return b;
    return a.displayName.length >= b.displayName.length ? a : b;
  }

  void _dedupeRealDevicesByMac() {
    final pending = _devices.where((d) => d.mac.startsWith('pending:')).toList();
    final reals = _devices.where((d) => !d.mac.startsWith('pending:')).toList();
    final best = <String, EspDevice>{};
    for (final d in reals) {
      final k = normMac(d.mac);
      final cur = best[k];
      if (cur == null) {
        best[k] = d;
      } else {
        best[k] = _preferEspDevice(cur, d);
      }
    }
    final next = [...pending, ...best.values];
    if (next.length == _devices.length) {
      var same = true;
      for (var i = 0; i < next.length; i++) {
        if (next[i].mac != _devices[i].mac) {
          same = false;
          break;
        }
      }
      if (same) return;
    }
    _devices
      ..clear()
      ..addAll(next);
  }

  void _upsertPending(MdnsEndpoint ep) {
    if (_isEndpointIgnored(ep)) return;
    final host = ep.ipv4?.address ?? ep.host;
    final key = 'pending:${ep.host}:${ep.port}';
    final idx = _devices.indexWhere((d) => d.pendingKey == key || (d.mac.startsWith('pending:') && d.host == host && d.port == ep.port));
    final dev = EspDevice(
      mac: 'pending:${ep.host}:${ep.port}',
      displayName: 'RetroWave',
      host: host,
      port: ep.port,
      isOnline: false,
      pendingKey: key,
      lastSeenMs: DateTime.now().millisecondsSinceEpoch,
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

  String? _bestStationLabel({
    required Map<String, dynamic> status,
    required String? fallbackUrl,
  }) {
    final title = status['stream_title']?.toString().trim();
    final station = status['stream_station']?.toString().trim();
    if (title != null && title.isNotEmpty) return title;
    if (station != null && station.isNotEmpty) return station;
    return _labelFromUrl(fallbackUrl);
  }

  Future<void> pollStatuses() async {
    if (discoveryBusy || _pollBusy) return;
    _pollBusy = true;
    try {
      var changed = false;
      for (var i = 0; i < _devices.length; i++) {
        final d = _devices[i];
        if (d.mac.startsWith('pending:')) continue;
        final ctrl = Esp32Controller(d.baseUrl);
        final s = await _statusWithRetry(ctrl);
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
        final chip = s.containsKey('chip') ? s['chip']?.toString() : d.chip;
        final a2dpCap = s['a2dp_sink_capable'] is bool ? s['a2dp_sink_capable'] as bool : d.a2dpSinkCapable;
        final a2dpStarted = s.containsKey('a2dp_sink_started') ? s['a2dp_sink_started'] == true : d.a2dpSinkStarted;
        final a2dpConn = s.containsKey('a2dp_connected') ? s['a2dp_connected'] == true : d.a2dpConnected;
        final a2dpName = s.containsKey('a2dp_pairing_name') ? s['a2dp_pairing_name']?.toString() : d.a2dpPairingName;
        final boardPf = s.containsKey('board_profile') ? s['board_profile']?.toString() : d.boardProfile;
        final now = DateTime.now().millisecondsSinceEpoch;
        _devices[i] = d.copyWith(
          isOnline: true,
          mode: mode,
          currentUrl: url,
          volume: vol.clamp(0, 21),
          playing: playing,
          displayName: name,
          stationLabel: _bestStationLabel(status: s, fallbackUrl: url),
          chip: chip,
          a2dpSinkCapable: a2dpCap,
          a2dpSinkStarted: a2dpStarted,
          a2dpConnected: a2dpConn,
          a2dpPairingName: a2dpName,
          boardProfile: boardPf,
          streamStation: s.containsKey('stream_station') ? s['stream_station']?.toString() : d.streamStation,
          streamTitle: s.containsKey('stream_title') ? s['stream_title']?.toString() : d.streamTitle,
          streamIcyUrl: s.containsKey('stream_icy_url') ? s['stream_icy_url']?.toString() : d.streamIcyUrl,
          streamIcyDescription: s.containsKey('stream_icy_description') ? s['stream_icy_description']?.toString() : d.streamIcyDescription,
          lastSeenMs: now,
        );
        changed = true;
      }
      _purgeStalePending();
      _dedupeRealDevicesByMac();
      if (changed) {
        notifyListeners();
      }
    } finally {
      _pollBusy = false;
      if (_refreshQueued) {
        _refreshQueued = false;
        unawaited(refreshDiscovery());
      }
    }
  }

  void _purgeStalePending() {
    final now = DateTime.now().millisecondsSinceEpoch;
    _devices.removeWhere((d) => d.mac.startsWith('pending:') && (now - d.lastSeenMs) > 35000);
  }

  void markNowPlaying({
    required String url,
    required String name,
    String? logoUrl,
  }) {
    final urlTrim = url.trim();
    if (urlTrim.isEmpty) return;
    for (var i = 0; i < _devices.length; i++) {
      final d = _devices[i];
      if (d.currentUrl == null || d.currentUrl!.trim() != urlTrim) continue;
      _devices[i] = d.copyWith(
        stationLabel: name,
        stationLogoUrl: logoUrl,
      );
    }
    notifyListeners();
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
    await broadcastBluetoothDetailed();
  }

  /// Ritorna un riepilogo esiti toggle BT per UX più chiara.
  Future<Map<String, int>> broadcastBluetoothDetailed() async {
    final list = selectedDevices.where((d) => d.isOnline && !d.mac.startsWith('pending:')).toList();
    var turnedOn = 0;
    var turnedRadio = 0;
    var unsupported = 0;
    var failed = 0;
    await Future.wait(list.map((d) async {
      final resp = await Esp32Controller(d.baseUrl).toggleBluetoothRaw();
      switch (resp) {
        case 'BT_ON':
          turnedOn++;
          break;
        case 'RADIO':
          turnedRadio++;
          break;
        case 'BT_NOT_SUPPORTED':
          unsupported++;
          break;
        default:
          failed++;
      }
    }));
    await pollStatuses();
    return {
      'bt_on': turnedOn,
      'radio': turnedRadio,
      'unsupported': unsupported,
      'failed': failed,
      'total': list.length,
    };
  }

  Future<void> syncVolumeSelected() async {
    final list = selectedDevices.where((d) => d.isOnline && !d.mac.startsWith('pending:')).toList();
    if (list.isEmpty) return;
    final v = list.first.volume;
    await Future.wait(list.map((d) => Esp32Controller(d.baseUrl).setVolume(v)));
    await pollStatuses();
  }

  Future<bool> renameDevice(String mac, String newName) async {
    final i = _devices.indexWhere((e) => normMac(e.mac) == normMac(mac));
    if (i < 0) return false;
    final d = _devices[i];
    final ok = await Esp32Controller(d.baseUrl).rename(newName);
    if (ok) {
      _devices[i] = _devices[i].copyWith(displayName: newName);
      notifyListeners();
    }
    return ok;
  }

  /// Richiede all'ESP di cancellare il WiFi e riavviarsi in modalità hotspot (stessa LAN).
  Future<bool> requestWifiReset(String mac) async {
    final i = _devices.indexWhere((e) => normMac(e.mac) == normMac(mac));
    if (i < 0) return false;
    return Esp32Controller(_devices[i].baseUrl).wifiReset();
  }

  Future<void> setVolumeForDevice(String mac, int v) async {
    final i = _devices.indexWhere((e) => normMac(e.mac) == normMac(mac));
    if (i < 0) return;
    await Esp32Controller(_devices[i].baseUrl).setVolume(v);
    await pollStatuses();
  }

  /// Per test/emulatore: aggiunge un dispositivo tramite IP o hostname noto.
  Future<bool> addManualHost(String host, {int port = 80}) async {
    final resolvedHost = host.trim();
    if (resolvedHost.isEmpty) return false;
    final ignoredBefore = _ignoredEndpoints.length;
    final parsed = InternetAddress.tryParse(resolvedHost);
    _ignoredEndpoints.removeWhere((e) {
      final i = e.lastIndexOf(':');
      if (i <= 0) return false;
      final h = e.substring(0, i);
      final po = int.tryParse(e.substring(i + 1));
      if (po != port) return false;
      return h == resolvedHost || (parsed != null && h == parsed.address);
    });
    if (_ignoredEndpoints.length != ignoredBefore) {
      await _saveIgnored();
    }
    final base = port == 80 ? 'http://$resolvedHost' : 'http://$resolvedHost:$port';
    final ctrl = Esp32Controller(base);
    final status = await ctrl.getStatus();
    if (status == null) return false;
    final mac = (status['mac'] ?? '').toString();
    if (mac.isEmpty) return false;
    if (_ignoredMacs.contains(normMac(mac))) {
      _ignoredMacs.remove(normMac(mac));
      await _saveIgnored();
    }
    await _mergeFromEndpoint(
      MdnsEndpoint(host: resolvedHost, port: port, ipv4: InternetAddress.tryParse(resolvedHost)),
    );
    return true;
  }

  /// Rimuove dalla lista e impedisce che mDNS lo reimporti (stesso MAC o stesso host:port se pending).
  Future<void> removeDevice(String mac) async {
    EspDevice? ref;
    for (final d in _devices) {
      if (d.mac == mac) {
        ref = d;
        break;
      }
    }
    if (mac.startsWith('pending:')) {
      final rest = mac.substring('pending:'.length);
      _ignoredEndpoints.add(rest);
      if (ref != null) {
        _ignoredEndpoints.add('${ref.host}:${ref.port}');
      }
      _devices.removeWhere((d) => d.mac == mac);
      selectedMacs.remove(mac);
      targetMacs.remove(mac);
    } else {
      final n = normMac(mac);
      _ignoredMacs.add(n);
      _devices.removeWhere((d) => !d.mac.startsWith('pending:') && normMac(d.mac) == n);
      selectedMacs.removeWhere((m) => !m.startsWith('pending:') && normMac(m) == n);
      targetMacs.removeWhere((m) => !m.startsWith('pending:') && normMac(m) == n);
    }
    groups = groups
        .map(
          (g) => DeviceGroup(
            id: g.id,
            name: g.name,
            deviceMacs: g.deviceMacs.where((m) {
              if (mac.startsWith('pending:')) return m != mac;
              if (m.startsWith('pending:')) return true;
              return normMac(m) != normMac(mac);
            }).toList(),
          ),
        )
        .where((g) => g.deviceMacs.isNotEmpty)
        .toList();
    _syncDeviceSelectedFlags();
    await _saveIgnored();
    await _saveGroups();
    notifyListeners();
  }

  /// Cancella l'elenco nascosti e rilancia la discovery (dispositivi tornano visibili se in rete).
  Future<void> restoreHiddenDevices() async {
    _ignoredMacs.clear();
    _ignoredEndpoints.clear();
    await _saveIgnored();
    await refreshDiscovery();
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
