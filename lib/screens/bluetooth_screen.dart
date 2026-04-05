import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/device_manager.dart';
import '../theme/app_theme.dart';

class BluetoothScreen extends StatelessWidget {
  const BluetoothScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DeviceManager>(
      builder: (context, dm, _) {
        final list = dm.devices.where((d) => !d.mac.startsWith('pending:')).toList();
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
                          TextSpan(
                            text: 'Spotify',
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w800,
                              color: const Color(0xFFC4BBFF),
                            ),
                          ),
                          const TextSpan(text: ' &\nBluetooth', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text('Streaming diretto dallo smartphone', style: AppTheme.mono(12)),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(colors: [Color(0xFF0F0D1A), Color(0xFF130F20)]),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: const Color(0x407C6FF7)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text('A2DP', style: AppTheme.mono(10, color: AppColors.purple).copyWith(letterSpacing: 1)),
                          Switch(
                            value: list.any((d) => d.mode.toLowerCase() == 'bluetooth'),
                            onChanged: (_) async {
                              await dm.broadcastBluetooth();
                            },
                          ),
                        ],
                      ),
                      const Text('🎧', style: TextStyle(fontSize: 52)),
                      const SizedBox(height: 8),
                      Text(
                        list.isNotEmpty ? list.first.displayName : 'RetroWave',
                        style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Color(0xFFC4BBFF)),
                      ),
                      const SizedBox(height: 6),
                      Text('Visibile come dispositivo BT (nome firmware)', style: AppTheme.mono(12)),
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: const Color(0x1A7C6FF7),
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: const Color(0x337C6FF7)),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 8,
                              height: 8,
                              decoration: const BoxDecoration(color: AppColors.purple, shape: BoxShape.circle),
                            ),
                            const SizedBox(width: 8),
                            const Expanded(
                              child: Text(
                                'Stato connessione: vedi telefono (Bluetooth)',
                                style: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFFC4BBFF)),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: Text('Attiva BT anche su', style: AppTheme.mono(10, color: AppColors.muted).copyWith(letterSpacing: 0.8)),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (context, i) {
                    final d = list[i];
                    final sel = dm.selectedMacs.contains(d.mac);
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
                              border: Border.all(color: sel ? const Color(0x667C6FF7) : AppColors.border),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  width: 22,
                                  height: 22,
                                  alignment: Alignment.center,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(6),
                                    color: sel ? AppColors.purple : Colors.transparent,
                                    border: Border.all(color: AppColors.border2),
                                  ),
                                  child: sel ? const Icon(Icons.check, size: 14, color: Color(0xFF0A0B0E)) : null,
                                ),
                                const SizedBox(width: 10),
                                const Text('📻', style: TextStyle(fontSize: 20)),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(d.displayName, style: const TextStyle(fontWeight: FontWeight.w700)),
                                ),
                                Text(
                                  d.mode.toLowerCase() == 'bluetooth' ? 'BT pronto' : 'Radio',
                                  style: AppTheme.mono(10, color: AppColors.muted),
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
                  onPressed: () => dm.broadcastBluetooth(),
                  child: const Text('Attiva BT sui selezionati', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
