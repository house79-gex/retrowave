import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../helpers/android_wifi_intent.dart';
import '../models/esp_device.dart';
import '../services/device_manager.dart';
import '../theme/app_theme.dart';

/// Bluetooth: su ESP32-WROOM-32U (firmware PlatformIO `esp32-wroom-32u`) sink A2DP dopo GET `/bluetooth`.
/// Su ESP32-S3 la richiesta BT restituisce `BT_NOT_SUPPORTED` (solo BLE, nessun Classic).
class BluetoothScreen extends StatelessWidget {
  const BluetoothScreen({super.key});

  static bool _anyA2dpCapable(List<EspDevice> list) => list.any((d) => d.a2dpSinkCapable == true);

  static bool _anyS3WithoutA2dp(List<EspDevice> list) => list.any((d) {
        final c = d.chip ?? '';
        return c.contains('S3') && d.a2dpSinkCapable != true;
      });

  static Future<void> _toggleWithFeedback(BuildContext context, DeviceManager dm) async {
    final r = await dm.broadcastBluetoothDetailed();
    if (!context.mounted) return;
    final total = r['total'] ?? 0;
    if (total == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Seleziona almeno un dispositivo online in Dispositivi.')),
      );
      return;
    }
    final on = r['bt_on'] ?? 0;
    final radio = r['radio'] ?? 0;
    final unsupported = r['unsupported'] ?? 0;
    final failed = r['failed'] ?? 0;
    final parts = <String>[];
    if (on > 0) parts.add('$on in modalità BT');
    if (radio > 0) parts.add('$radio tornati a Radio');
    if (unsupported > 0) parts.add('$unsupported senza supporto A2DP');
    if (failed > 0) parts.add('$failed non raggiungibili');
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(parts.isEmpty ? 'Comando inviato.' : parts.join(' · '))),
    );
  }

  static Widget _step({
    required int n,
    required String title,
    required String subtitle,
    required bool done,
  }) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 24,
          height: 24,
          decoration: BoxDecoration(
            color: done ? AppColors.green.withValues(alpha: 0.2) : AppColors.s2,
            shape: BoxShape.circle,
            border: Border.all(color: done ? AppColors.green : AppColors.border2),
          ),
          alignment: Alignment.center,
          child: done
              ? const Icon(Icons.check_rounded, size: 14, color: AppColors.green)
              : Text('$n', style: AppTheme.mono(11, color: AppColors.muted, weight: FontWeight.w700)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13)),
              const SizedBox(height: 2),
              Text(subtitle, style: AppTheme.mono(11, color: AppColors.muted2)),
            ],
          ),
        ),
      ],
    );
  }

  static Future<void> _openSpotify() async {
    final app = Uri.parse('spotify://');
    final web = Uri.parse('https://open.spotify.com/');
    final ok = await launchUrl(app, mode: LaunchMode.externalApplication);
    if (!ok) {
      await launchUrl(web, mode: LaunchMode.externalApplication);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DeviceManager>(
      builder: (context, dm, _) {
        final list = dm.devices.where((d) => !d.mac.startsWith('pending:')).toList();
        final anyBt = list.any((d) => d.mode.toLowerCase() == 'bluetooth');
        final hasA2dpHw = _anyA2dpCapable(list);
        final hasS3Limit = _anyS3WithoutA2dp(list);
        final anyConnected = list.any((d) => d.a2dpConnected);
        final selected = dm.selectedDevices.where((d) => d.isOnline && !d.mac.startsWith('pending:')).toList();
        final selectedA2dp = selected.where((d) => d.a2dpSinkCapable == true).toList();
        final step1Done = selectedA2dp.isNotEmpty && selectedA2dp.any((d) => d.mode.toLowerCase() == 'bluetooth');
        final step2Done = selectedA2dp.any((d) => d.a2dpSinkStarted);
        final step3Done = selectedA2dp.any((d) => d.a2dpConnected);

        return SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(text: 'Bluetooth ', style: AppTheme.displayTitle(size: 26)),
                          TextSpan(text: 'A2DP', style: AppTheme.displayTitle(size: 26, accent: AppColors.purple)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      hasA2dpHw
                          ? 'Accoppiamento dal telefono (Classic Bluetooth)'
                          : 'Stato da firmware e limiti hardware',
                      style: TextStyle(color: AppColors.muted2, fontSize: 14),
                    ),
                  ],
                ),
              ),
              if (hasA2dpHw)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF121A1C),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.cyan.withValues(alpha: 0.4)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.speaker_phone_rounded, color: AppColors.cyan, size: 22),
                            const SizedBox(width: 10),
                            const Expanded(
                              child: Text(
                                'Come usare l’audio dal cellulare',
                                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        const Text(
                          '1. Attiva la modalità Bluetooth qui sotto (GET /bluetooth sul dispositivo).\n'
                          '2. Apri Spotify/YouTube o altra app audio e scegli il dispositivo BT nelle impostazioni Bluetooth del telefono.\n'
                          '3. Cerca il nome mostrato in elenco qui sotto, accoppia e riproduci musica.\n'
                          '4. Per tornare alla radio WiFi, disattiva di nuovo la modalità BT.',
                          style: TextStyle(color: AppColors.muted2, height: 1.5, fontSize: 13),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            FilledButton.tonalIcon(
                              onPressed: openAndroidBluetoothSettings,
                              icon: const Icon(Icons.bluetooth_searching_rounded),
                              label: const Text('Apri Bluetooth telefono'),
                            ),
                            FilledButton.tonalIcon(
                              onPressed: () => _toggleWithFeedback(context, dm),
                              icon: const Icon(Icons.swap_calls_rounded),
                              label: const Text('Toggle BT su selezionati'),
                            ),
                          ],
                        ),
                        if (anyConnected) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Icon(Icons.link_rounded, color: AppColors.cyan, size: 18),
                              const SizedBox(width: 8),
                              Text(
                                'Almeno un ESP ha una sorgente A2DP collegata',
                                style: TextStyle(color: AppColors.cyan, fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              if (hasA2dpHw)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppColors.s1,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(color: AppColors.border2),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            const Icon(Icons.task_alt_rounded, color: AppColors.acc, size: 20),
                            const SizedBox(width: 8),
                            const Text('Wizard rapido A2DP', style: TextStyle(fontWeight: FontWeight.w800)),
                            const Spacer(),
                            Text(
                              selectedA2dp.isEmpty ? 'Seleziona device' : '${selectedA2dp.length} pronti',
                              style: AppTheme.mono(10, color: AppColors.muted),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        _step(
                          n: 1,
                          title: 'Attiva modalità Bluetooth',
                          subtitle: step1Done ? 'OK: almeno un dispositivo è in mode BT' : 'Tocca “Toggle BT su selezionati”',
                          done: step1Done,
                        ),
                        const SizedBox(height: 8),
                        _step(
                          n: 2,
                          title: 'Apri Bluetooth sul telefono e accoppia',
                          subtitle: step2Done ? 'OK: sink A2DP avviato' : 'Cerca il nome RetroWave in elenco',
                          done: step2Done,
                        ),
                        const SizedBox(height: 8),
                        _step(
                          n: 3,
                          title: 'Riproduci su Spotify/YouTube',
                          subtitle: step3Done ? 'OK: sorgente audio collegata' : 'Avvia un brano e seleziona output Bluetooth',
                          done: step3Done,
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            if (!step1Done)
                              FilledButton.icon(
                                onPressed: () => _toggleWithFeedback(context, dm),
                                icon: const Icon(Icons.bluetooth_audio_rounded),
                                label: const Text('1) Attiva BT su ESP'),
                              ),
                            if (step1Done && !step2Done)
                              FilledButton.tonalIcon(
                                onPressed: openAndroidBluetoothSettings,
                                icon: const Icon(Icons.settings_bluetooth_rounded),
                                label: const Text('2) Apri pairing telefono'),
                              ),
                            if (step2Done && !step3Done)
                              FilledButton.tonalIcon(
                                onPressed: _openSpotify,
                                icon: const Icon(Icons.play_circle_fill_rounded),
                                label: const Text('3) Apri Spotify'),
                              ),
                            if (step3Done)
                              FilledButton.tonalIcon(
                                onPressed: () => _toggleWithFeedback(context, dm),
                                icon: const Icon(Icons.radio_rounded),
                                label: const Text('Torna a Radio'),
                              ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              if (hasS3Limit || (!hasA2dpHw && list.isNotEmpty))
                Padding(
                  padding: EdgeInsets.fromLTRB(16, hasA2dpHw ? 12 : 0, 16, 0),
                  child: Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: const Color(0xFF1A1520),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppColors.acc2.withValues(alpha: 0.45)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.info_outline_rounded, color: AppColors.acc2, size: 22),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                hasS3Limit
                                    ? 'ESP32-S3: niente Bluetooth Classic / A2DP'
                                    : 'Firmware senza sink A2DP',
                                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),
                        Text(
                          hasS3Limit
                              ? 'Il chip ESP32-S3 integra solo Bluetooth Low Energy: non può comparire come altoparlante A2DP. '
                                  'Usa la scheda Radio (stream via WiFi) oppure un modulo ESP32 classico con firmware '
                                  'PlatformIO `esp32-wroom-32u` (o alias `esp32-wroom-a2dp`).'
                              : 'Aggiorna il firmware e compila l’ambiente `esp32-wroom-32u` su ESP32 con Bluetooth Classic (non ESP32-S3) per il pairing audio.',
                          style: const TextStyle(color: AppColors.muted2, height: 1.5, fontSize: 13),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF14121C), Color(0xFF18152A)],
                    ),
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: AppColors.purple.withValues(alpha: 0.35)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Modalità Bluetooth (HTTP)', style: AppTheme.mono(10, color: AppColors.purple)),
                                const SizedBox(height: 4),
                                Text(
                                  anyBt ? 'Almeno un ESP in mode=bluetooth' : 'Nessun ESP in mode bluetooth',
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                ),
                              ],
                            ),
                          ),
                          Switch(
                            value: anyBt,
                            onChanged: list.isEmpty
                                ? null
                                : (_) async {
                                    await _toggleWithFeedback(context, dm);
                                  },
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        list.isEmpty
                            ? 'Aggiungi prima un dispositivo (Dispositivi o Setup).'
                            : 'Chiama GET /bluetooth su ciascun ESP selezionato in Dispositivi.',
                        style: AppTheme.mono(11, color: AppColors.muted),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 18, 16, 8),
                child: Text('Dispositivi', style: AppTheme.mono(10, color: AppColors.muted)),
              ),
              Expanded(
                child: list.isEmpty
                    ? Center(
                        child: Text('Nessun ESP in lista', style: TextStyle(color: AppColors.muted2)),
                      )
                    : ListView.builder(
                        itemCount: list.length,
                        itemBuilder: (context, i) {
                          final d = list[i];
                          final sel = dm.selectedMacs.contains(d.mac);
                          final modeLow = d.mode.toLowerCase();
                          final a2dpLine = _deviceA2dpLine(d);
                          return Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                            child: Material(
                              color: AppColors.s1,
                              borderRadius: BorderRadius.circular(16),
                              child: InkWell(
                                onTap: () => dm.toggleSelection(d.mac),
                                borderRadius: BorderRadius.circular(16),
                                child: Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(16),
                                    border: Border.all(color: sel ? AppColors.purple.withValues(alpha: 0.5) : AppColors.border),
                                  ),
                                  child: Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Icon(
                                        sel ? Icons.check_circle_rounded : Icons.circle_outlined,
                                        color: sel ? AppColors.purple : AppColors.muted,
                                        size: 22,
                                      ),
                                      const SizedBox(width: 10),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(d.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
                                            const SizedBox(height: 4),
                                            Text(
                                              [
                                                d.chip ?? 'chip ?',
                                                if (d.boardProfile != null && d.boardProfile!.trim().isNotEmpty) d.boardProfile!.trim(),
                                                a2dpLine,
                                              ].join(' · '),
                                              style: AppTheme.mono(10, color: AppColors.muted),
                                            ),
                                          ],
                                        ),
                                      ),
                                      Column(
                                        crossAxisAlignment: CrossAxisAlignment.end,
                                        children: [
                                          Text(
                                            modeLow == 'bluetooth' ? 'mode BT' : (modeLow == 'radio' ? 'mode radio' : d.mode),
                                            style: AppTheme.mono(10, color: AppColors.muted),
                                          ),
                                          if (d.a2dpConnected)
                                            Padding(
                                              padding: const EdgeInsets.only(top: 4),
                                              child: Icon(Icons.bluetooth_connected_rounded, color: AppColors.cyan, size: 18),
                                            ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                child: FilledButton(
                  style: FilledButton.styleFrom(
                    backgroundColor: AppColors.purple,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  onPressed: list.isEmpty ? null : () => _toggleWithFeedback(context, dm),
                  child: const Text('Invia /bluetooth agli ESP selezionati', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  static String _deviceA2dpLine(EspDevice d) {
    if (d.a2dpSinkCapable == true) {
      if (d.a2dpSinkStarted) {
        final name = (d.a2dpPairingName != null && d.a2dpPairingName!.isNotEmpty) ? d.a2dpPairingName! : d.displayName;
        return d.a2dpConnected ? 'A2DP attivo · collegato · «$name»' : 'A2DP attivo · cerca «$name» nel telefono';
      }
      return 'A2DP disponibile (attiva mode BT)';
    }
    if (d.a2dpSinkCapable == false) {
      return 'Nessun sink A2DP su questo chip/firmware';
    }
    return 'A2DP: firmware non segnala capacità';
  }
}
