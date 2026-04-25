import 'dart:async';
import 'dart:io';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../helpers/android_wifi_intent.dart';
import '../services/device_manager.dart';
import '../theme/app_theme.dart';

/// Setup guidato: rete, scansione automatica, IP manuale, ripristino nascosti.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> with WidgetsBindingObserver {
  static final Uri _captiveUri = Uri.parse('http://192.168.4.1');
  final _ipCtrl = TextEditingController();
  StreamSubscription<List<ConnectivityResult>>? _connSub;
  List<ConnectivityResult> _lastConn = [];
  Timer? _autoScan;
  bool _portalBusy = false;
  String? _portalDetected;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_readConnectivity());
    _connSub = Connectivity().onConnectivityChanged.listen((r) {
      if (mounted) setState(() => _lastConn = r);
    });
    _autoScan = Timer.periodic(const Duration(seconds: 8), (_) {
      if (!mounted) return;
      final dm = context.read<DeviceManager>();
      if (!dm.discoveryBusy) unawaited(dm.refreshDiscovery());
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<DeviceManager>().refreshDiscovery();
    });
  }

  Future<void> _readConnectivity() async {
    try {
      final r = await Connectivity().checkConnectivity();
      if (mounted) setState(() => _lastConn = r);
    } catch (_) {}
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _connSub?.cancel();
    _autoScan?.cancel();
    _ipCtrl.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_readConnectivity());
      context.read<DeviceManager>().refreshDiscovery();
    }
  }

  bool get _hasLan {
    return _lastConn.any(
      (e) => e == ConnectivityResult.wifi || e == ConnectivityResult.ethernet || e == ConnectivityResult.vpn,
    );
  }

  Future<void> _openCaptivePortal(BuildContext context) async {
    final ok = await launchUrl(_captiveUri, mode: LaunchMode.externalApplication);
    if (!context.mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Apri manualmente: http://192.168.4.1')),
      );
    }
  }

  static bool _isPrivateIPv4(String ip) {
    return ip.startsWith('192.168.') || ip.startsWith('10.') || ip.startsWith('172.16.') || ip.startsWith('172.17.') || ip.startsWith('172.18.') || ip.startsWith('172.19.') || ip.startsWith('172.20.') || ip.startsWith('172.21.') || ip.startsWith('172.22.') || ip.startsWith('172.23.') || ip.startsWith('172.24.') || ip.startsWith('172.25.') || ip.startsWith('172.26.') || ip.startsWith('172.27.') || ip.startsWith('172.28.') || ip.startsWith('172.29.') || ip.startsWith('172.30.') || ip.startsWith('172.31.');
  }

  Future<List<String>> _candidatePortalHosts() async {
    final set = <String>{'192.168.4.1'};
    try {
      final ifs = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      for (final ni in ifs) {
        for (final a in ni.addresses) {
          final ip = a.address;
          if (!_isPrivateIPv4(ip)) continue;
          final parts = ip.split('.');
          if (parts.length != 4) continue;
          final gw = '${parts[0]}.${parts[1]}.${parts[2]}.1';
          set.add(gw);
        }
      }
    } catch (_) {}
    // Fallback comuni su alcune reti.
    set.addAll(const ['192.168.0.1', '192.168.1.1', '10.0.0.1']);
    return set.toList();
  }

  Future<String?> _probePortalHost(String host) async {
    final uri = Uri.parse('http://$host/');
    try {
      final r = await http.get(uri).timeout(const Duration(seconds: 2));
      if (r.statusCode >= 200 && r.statusCode < 500) {
        final body = r.body.toLowerCase();
        if (body.contains('wifimanager') ||
            body.contains('retro') ||
            body.contains('configure wifi') ||
            body.contains('wifi') ||
            body.contains('captive')) {
          return host;
        }
        // Anche senza marker testuale, una risposta HTTP valida è un buon segnale.
        return host;
      }
    } catch (_) {}
    return null;
  }

  Future<void> _autoOpenPortal(BuildContext context) async {
    if (_portalBusy) return;
    setState(() => _portalBusy = true);
    try {
      final hosts = await _candidatePortalHosts();
      String? found;
      for (final h in hosts) {
        found = await _probePortalHost(h);
        if (found != null) break;
      }
      final target = found ?? _captiveUri.host;
      _portalDetected = target;
      final ok = await launchUrl(Uri.parse('http://$target'), mode: LaunchMode.externalApplication);
      if (!context.mounted) return;
      if (!ok) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Apri manualmente: http://$target')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Portale aperto su http://$target')),
        );
      }
    } finally {
      if (mounted) setState(() => _portalBusy = false);
    }
  }

  Future<void> _confirmWifiReset(BuildContext context, DeviceManager dm, String mac, String label) async {
    final go = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Riconfigurare il WiFi?'),
        content: Text(
          '«$label» cancellerà il WiFi e si riavvierà. Poi connettiti a RetroWave-…-Setup e apri il portale.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Conferma')),
        ],
      ),
    );
    if (go != true || !context.mounted) return;
    final ok = await dm.requestWifiReset(mac);
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          ok ? 'Richiesta inviata. Cerca RetroWave-…-Setup tra pochi secondi.' : 'Nessuna risposta: stessa WiFi?',
        ),
      ),
    );
    if (ok) unawaited(dm.refreshDiscovery());
  }

  Future<void> _addByIp(BuildContext context, DeviceManager dm) async {
    final host = _ipCtrl.text.trim();
    if (host.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Inserisci un indirizzo IP (es. 192.168.99.25)')),
      );
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    final ok = await dm.addManualHost(host);
    if (!context.mounted) return;
    messenger.showSnackBar(
      SnackBar(content: Text(ok ? 'Dispositivo aggiunto' : 'Non raggiungibile: verifica IP e rete')),
    );
    if (ok) _ipCtrl.clear();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DeviceManager>(
      builder: (context, dm, _) {
        final online = dm.devices.where((d) => d.isOnline && !d.mac.startsWith('pending:')).toList();
        final pending = dm.devices.where((d) => d.mac.startsWith('pending:')).length;

        return SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Setup', style: AppTheme.displayTitle(size: 32)),
                      Text(
                        'Stessa WiFi del telefono e degli ESP. L’app cerca da sola ogni pochi secondi.',
                        style: TextStyle(color: AppColors.muted2, fontSize: 14, height: 1.45),
                      ),
                    ],
                  ),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverToBoxAdapter(
                  child: _networkBanner(),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
                sliver: SliverToBoxAdapter(
                  child: _scanCard(context, dm, online.length, pending),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverToBoxAdapter(
                  child: _manualIpCard(context, dm),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                sliver: SliverToBoxAdapter(
                  child: Text('Azioni rapide', style: AppTheme.mono(11, color: AppColors.muted).copyWith(letterSpacing: 1)),
                ),
              ),
              SliverPadding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                sliver: SliverToBoxAdapter(
                  child: Column(
                    children: [
                      _tile(Icons.wifi_rounded, 'Impostazioni WiFi', 'Apri il pannello sistema', () => openAndroidWifiSettings()),
                      const SizedBox(height: 10),
                      _tile(
                        Icons.auto_awesome_rounded,
                        _portalBusy ? 'Rilevo portale...' : 'Portale captive automatico',
                        _portalDetected != null
                            ? 'Ultimo rilevato: http://$_portalDetected'
                            : 'Rileva gateway ESP e apre il portale',
                        () => _autoOpenPortal(context),
                      ),
                      const SizedBox(height: 10),
                      _tile(Icons.language_rounded, 'Apri portale manuale', 'http://192.168.4.1 (hotspot ESP)', () => _openCaptivePortal(context)),
                    ],
                  ),
                ),
              ),
              if (dm.hiddenDeviceCount > 0)
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  sliver: SliverToBoxAdapter(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        await dm.restoreHiddenDevices();
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Dispositivi nascosti ripristinati')),
                          );
                        }
                      },
                      icon: const Icon(Icons.restore_rounded),
                      label: Text('Ripristina ${dm.hiddenDeviceCount} nascost${dm.hiddenDeviceCount == 1 ? 'o' : 'i'}'),
                    ),
                  ),
                ),
              if (online.isNotEmpty) ...[
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 8),
                  sliver: SliverToBoxAdapter(
                    child: Text('Riconfigura WiFi (da casa)', style: AppTheme.mono(11, color: AppColors.muted)),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (ctx, i) {
                        final d = online[i];
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: Material(
                            color: AppColors.s1,
                            borderRadius: BorderRadius.circular(18),
                            child: ListTile(
                              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                              title: Text(d.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
                              subtitle: Text(d.baseUrl, style: AppTheme.mono(11, color: AppColors.muted)),
                              trailing: FilledButton.tonal(
                                onPressed: () => _confirmWifiReset(context, dm, d.mac, d.displayName),
                                child: const Text('WiFi'),
                              ),
                            ),
                          ),
                        );
                      },
                      childCount: online.length,
                    ),
                  ),
                ),
              ],
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
                sliver: SliverToBoxAdapter(
                  child: _tips(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _networkBanner() {
    final ok = _hasLan;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        gradient: LinearGradient(
          colors: ok
              ? [const Color(0xFF0F1A14), const Color(0xFF121C18)]
              : [const Color(0xFF1A1410), const Color(0xFF221A12)],
        ),
        border: Border.all(color: ok ? AppColors.green.withValues(alpha: 0.35) : AppColors.acc2.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(ok ? Icons.wifi_rounded : Icons.wifi_off_rounded, color: ok ? AppColors.green : AppColors.acc2, size: 28),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  ok ? 'Rete disponibile' : 'Controlla la connessione',
                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                ),
                const SizedBox(height: 4),
                Text(
                  ok
                      ? 'Il telefono sembra su Wi‑Fi o Ethernet. Gli ESP sulla stessa rete possono essere trovati.'
                      : 'Attiva il Wi‑Fi e collegati alla rete di casa (o all’hotspot RetroWave per la prima configurazione).',
                  style: TextStyle(color: AppColors.muted2, fontSize: 12, height: 1.4),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _scanCard(BuildContext context, DeviceManager dm, int onlineN, int pendingN) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: AppColors.s1,
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            blurRadius: 24,
            offset: const Offset(0, 8),
            color: AppColors.acc.withValues(alpha: 0.06),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 22,
                height: 22,
                child: dm.discoveryBusy
                    ? const CircularProgressIndicator(strokeWidth: 2, color: AppColors.acc)
                    : Icon(Icons.radar_rounded, color: AppColors.acc, size: 22),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Ricerca automatica',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 17),
                ),
              ),
              TextButton.icon(
                onPressed: dm.discoveryBusy ? null : () => dm.refreshDiscovery(),
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('Ora'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            '$onlineN online · $pendingN in attesa di risposta',
            style: AppTheme.mono(13, color: AppColors.muted2),
          ),
          const SizedBox(height: 8),
          Text(
            'Non vedi il dispositivo? Vai su Dispositivi e usa «IP» oppure inseriscilo qui sotto.',
            style: TextStyle(color: AppColors.muted2, fontSize: 12, height: 1.4),
          ),
        ],
      ),
    );
  }

  Widget _manualIpCard(BuildContext context, DeviceManager dm) {
    return Container(
      margin: const EdgeInsets.only(top: 16),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(20),
        color: AppColors.s2,
        border: Border.all(color: AppColors.border2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.pin_drop_rounded, color: AppColors.cyan, size: 22),
              const SizedBox(width: 10),
              const Text('Aggiungi con IP', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 16)),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Utile se mDNS non funziona (rete Android). L’IP è su Serial o sul router.',
            style: TextStyle(color: AppColors.muted2, fontSize: 12),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ipCtrl,
            keyboardType: TextInputType.url,
            style: const TextStyle(fontWeight: FontWeight.w600),
            decoration: InputDecoration(
              hintText: 'es. 192.168.99.25',
              filled: true,
              fillColor: AppColors.s1,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onSubmitted: (_) => _addByIp(context, dm),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => _addByIp(context, dm),
              child: const Text('Collega dispositivo'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _tile(IconData icon, String title, String sub, VoidCallback onTap) {
    return Material(
      color: AppColors.s1,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Icon(icon, color: AppColors.acc, size: 24),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: const TextStyle(fontWeight: FontWeight.w600)),
                    Text(sub, style: TextStyle(fontSize: 12, color: AppColors.muted2)),
                  ],
                ),
              ),
              Icon(Icons.chevron_right_rounded, color: AppColors.muted),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tips() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: AppColors.s1.withValues(alpha: 0.8),
        border: Border.all(color: AppColors.border2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Suggerimenti', style: AppTheme.mono(11, color: AppColors.muted)),
          const SizedBox(height: 8),
          Text(
            '• Dopo il primo setup l’hotspot RetroWave sparisce: è normale.\n'
            '• Se il captive non si apre, usa «Portale captive automatico» (rileva gateway) oppure http://192.168.4.1.\n'
            '• L’IP visto sul telefono è spesso diverso: è del telefono, non dell’ESP AP/gateway.\n'
            '• BOOT premuto al reset = cancella WiFi salvato sull’ESP.',
            style: TextStyle(color: AppColors.muted2, height: 1.5, fontSize: 12),
          ),
        ],
      ),
    );
  }
}
