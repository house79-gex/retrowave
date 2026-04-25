import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:provider/provider.dart';

import '../models/esp_device.dart';
import '../services/device_manager.dart';
import '../theme/app_theme.dart';
import '../widgets/waveform_widget.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DeviceManager>(
      builder: (context, dm, _) {
        final playing = dm.devices.where((d) => d.playing && d.isOnline).toList();
        EspDevice? primary;
        if (playing.isNotEmpty) {
          primary = playing.first;
        } else {
          for (final d in dm.devices) {
            if (d.isOnline && !d.mac.startsWith('pending:')) {
              primary = d;
              break;
            }
          }
        }
        final station = primary != null ? (primary.stationLabel ?? primary.streamStation ?? primary.currentUrl ?? '—') : '—';
        final title = primary != null ? (primary.streamTitle ?? primary.streamIcyDescription ?? '—') : '—';
        final vol = primary != null ? primary.volume : 10;
        final active = primary != null && primary.playing;
        final primaryMac = primary?.mac;

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
                          const TextSpan(text: 'Retro', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                          TextSpan(text: 'Wave', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.acc)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${dm.targetsResolved.length} attivi · invio a ${dm.targetMacs.isEmpty ? "tutti" : "${dm.targetMacs.length}"}',
                      style: AppTheme.mono(12),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Container(
                  padding: const EdgeInsets.all(22),
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [Color(0xFF141209), Color(0xFF1A1810), Color(0xFF141209)],
                    ),
                    borderRadius: BorderRadius.circular(28),
                    border: Border.all(color: const Color(0x2EF5C518)),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              color: active ? AppColors.green : AppColors.muted,
                              shape: BoxShape.circle,
                              boxShadow: active
                                  ? [BoxShadow(blurRadius: 8, spreadRadius: 1, color: AppColors.green.withValues(alpha: 0.5))]
                                  : null,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            active ? 'IN ASCOLTO' : 'PRONTO',
                            style: AppTheme.mono(9, color: active ? AppColors.green : AppColors.muted).copyWith(letterSpacing: 1.4),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: SizedBox(
                              width: 62,
                              height: 62,
                              child: primary?.stationLogoUrl != null && primary!.stationLogoUrl!.startsWith('http')
                                  ? CachedNetworkImage(
                                      imageUrl: primary.stationLogoUrl!,
                                      fit: BoxFit.cover,
                                      errorWidget: (context, url, error) => Container(
                                        decoration: BoxDecoration(
                                          borderRadius: BorderRadius.circular(18),
                                          gradient: const LinearGradient(colors: [AppColors.acc, AppColors.acc2]),
                                          boxShadow: const [BoxShadow(blurRadius: 24, color: Color(0x40F5C518))],
                                        ),
                                        alignment: Alignment.center,
                                        child: const Text('📻', style: TextStyle(fontSize: 26)),
                                      ),
                                    )
                                  : Container(
                                      decoration: BoxDecoration(
                                        borderRadius: BorderRadius.circular(18),
                                        gradient: const LinearGradient(colors: [AppColors.acc, AppColors.acc2]),
                                        boxShadow: const [BoxShadow(blurRadius: 24, color: Color(0x40F5C518))],
                                      ),
                                      alignment: Alignment.center,
                                      child: const Text('📻', style: TextStyle(fontSize: 26)),
                                    ),
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  station,
                                  style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Text('Streaming · LAN', style: AppTheme.mono(12)),
                                const SizedBox(height: 4),
                                Text(title, style: AppTheme.mono(10, color: AppColors.acc), maxLines: 1, overflow: TextOverflow.ellipsis),
                              ],
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      WaveformWidget(active: active),
                      Row(
                        children: [
                          const Text('🔈', style: TextStyle(fontSize: 14)),
                          Expanded(
                            child: Slider(
                              value: vol.clamp(0, 21).toDouble(),
                              min: 0,
                              max: 21,
                              divisions: 21,
                              label: '$vol',
                              onChanged: primaryMac == null || primaryMac.startsWith('pending:')
                                  ? null
                                  : (v) => dm.setVolumeForDevice(primaryMac, v.round()),
                            ),
                          ),
                          const Text('🔊', style: TextStyle(fontSize: 14)),
                          IconButton(
                            onPressed: primary == null ? null : () => dm.stopTargets(),
                            icon: const Icon(Icons.stop_rounded, color: AppColors.red),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 8),
                child: Text('Invia a', style: AppTheme.mono(10, color: AppColors.muted).copyWith(letterSpacing: 0.8)),
              ),
              SizedBox(
                height: 40,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    ...dm.devices.where((d) => !d.mac.startsWith('pending:')).map(
                          (d) => Padding(
                            padding: const EdgeInsets.only(right: 6),
                            child: FilterChip(
                              label: Text(d.displayName),
                              selected: dm.targetMacs.isEmpty || dm.targetMacs.contains(d.mac),
                              onSelected: (_) => dm.toggleTarget(d.mac),
                            ),
                          ),
                        ),
                    Padding(
                      padding: const EdgeInsets.only(left: 4),
                      child: ActionChip(
                        label: const Text('Tutti'),
                        onPressed: () => dm.setAllTargets(),
                      ),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                child: Text('Recenti', style: AppTheme.mono(10, color: AppColors.muted).copyWith(letterSpacing: 0.8)),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: dm.recentStations.length,
                  itemBuilder: (context, i) {
                    final r = dm.recentStations[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.s2,
                        child: const Text('📻'),
                      ),
                      title: Text(r['name'] ?? ''),
                      subtitle: Text(r['url'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis),
                      trailing: IconButton(
                        icon: const Icon(Icons.play_arrow_rounded),
                        onPressed: () => dm.playUrlOnTargets(r['url'] ?? '', label: r['name']),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
