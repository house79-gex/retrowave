import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Visualizzazione a barre animata (placeholder livello audio).
class WaveformWidget extends StatefulWidget {
  const WaveformWidget({super.key, this.active = true, this.barCount = 12});

  final bool active;
  final int barCount;

  @override
  State<WaveformWidget> createState() => _WaveformWidgetState();
}

class _WaveformWidgetState extends State<WaveformWidget> with SingleTickerProviderStateMixin {
  late AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))..repeat();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.active) {
      return const SizedBox(height: 36);
    }
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return SizedBox(
          height: 36,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.end,
            children: List.generate(widget.barCount, (i) {
              final phase = (_c.value * 2 * math.pi) + (i * 0.45);
              final h = 6 + (26 * (0.5 + 0.5 * (1 + math.sin(phase)) / 2)).clamp(4.0, 32.0);
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 1.5),
                child: Container(
                  width: 3,
                  height: h,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(2),
                    gradient: const LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [AppColors.acc2, AppColors.acc],
                    ),
                  ),
                ),
              );
            }),
          ),
        );
      },
    );
  }
}
