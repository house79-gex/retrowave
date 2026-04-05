import 'package:flutter/material.dart';

import '../models/esp_device.dart';
import '../theme/app_theme.dart';

class DeviceCard extends StatelessWidget {
  const DeviceCard({
    super.key,
    required this.device,
    required this.onTap,
    required this.onLongPress,
  });

  final EspDevice device;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  String _macShort(String mac) {
    final p = mac.split(':');
    if (p.length >= 2) return '${p.take(2).join(':')}:...:${p.last}';
    return mac;
  }

  @override
  Widget build(BuildContext context) {
    final mode = device.mode.toLowerCase();
    final badgeColor = mode == 'bluetooth'
        ? const Color(0x1F7C6FF7)
        : mode == 'radio'
            ? const Color(0x1FF5C518)
            : AppColors.s2;
    final badgeBorder = mode == 'bluetooth'
        ? const Color(0x337C6FF7)
        : mode == 'radio'
            ? const Color(0x33F5C518)
            : AppColors.border;
    final label = mode == 'bluetooth'
        ? 'BT'
        : mode == 'radio'
            ? 'Radio'
            : 'Stop';
    final emoji = _emojiFor(device);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: Material(
        color: device.isSelected ? const Color(0xFF13140F) : AppColors.s1,
        borderRadius: BorderRadius.circular(22),
        child: InkWell(
          onTap: onTap,
          onLongPress: onLongPress,
          borderRadius: BorderRadius.circular(22),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(22),
              border: Border.all(
                color: device.isSelected ? const Color(0x80F5C518) : AppColors.border,
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                  child: Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(8),
                          color: device.isSelected ? AppColors.acc : Colors.transparent,
                          border: Border.all(color: AppColors.border2, width: 1.5),
                        ),
                        alignment: Alignment.center,
                        child: device.isSelected
                            ? const Icon(Icons.check, size: 14, color: Color(0xFF0A0B0E))
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Container(
                            width: 46,
                            height: 46,
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              gradient: LinearGradient(
                                colors: [
                                  Color.lerp(const Color(0xFF1A160A), const Color(0xFF0D1A14), (device.mac.hashCode % 100) / 100)!,
                                  Color.lerp(const Color(0xFF2A2010), const Color(0xFF102A1C), (device.mac.hashCode % 100) / 100)!,
                                ],
                              ),
                            ),
                            alignment: Alignment.center,
                            child: Text(emoji, style: const TextStyle(fontSize: 20)),
                          ),
                          Positioned(
                            right: 0,
                            bottom: 0,
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: BoxDecoration(
                                color: device.isOnline ? AppColors.green : AppColors.muted,
                                shape: BoxShape.circle,
                                border: Border.all(color: AppColors.s1, width: 2),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              device.displayName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'MAC · ${_macShort(device.mac)}',
                              style: AppTheme.mono(10, color: AppColors.muted),
                            ),
                          ],
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: badgeColor,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: badgeBorder),
                        ),
                        child: Text(
                          label,
                          style: AppTheme.mono(10, weight: FontWeight.w500).copyWith(
                            color: mode == 'bluetooth'
                                ? const Color(0xFFA89CF5)
                                : mode == 'radio'
                                    ? AppColors.acc
                                    : AppColors.muted,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: AppColors.border)),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text.rich(
                          TextSpan(
                            children: [
                              TextSpan(
                                text: device.playing ? '▶ ' : 'Ultima: ',
                                style: TextStyle(color: AppColors.muted2, fontSize: 12),
                              ),
                              TextSpan(
                                text: device.stationLabel ?? device.currentUrl ?? '—',
                                style: const TextStyle(
                                  color: AppColors.text,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Row(
                        children: [
                          const Text('🔊 ', style: TextStyle(fontSize: 11)),
                          SizedBox(
                            width: 48,
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(2),
                              child: LinearProgressIndicator(
                                value: device.volume / 21,
                                minHeight: 3,
                                backgroundColor: AppColors.border2,
                                color: AppColors.acc,
                              ),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text('${device.volume}', style: AppTheme.mono(11, color: AppColors.muted)),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _emojiFor(EspDevice d) {
    final n = d.displayName.toLowerCase();
    if (n.contains('cucina')) return '🍳';
    if (n.contains('salotto') || n.contains('living')) return '🛋';
    if (n.contains('camera') || n.contains('letto')) return '🛏';
    return '📻';
  }
}
