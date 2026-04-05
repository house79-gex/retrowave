import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const SizedBox(height: 8),
          const Text(
            'Aggiungi\ndispositivo',
            style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, height: 1.05),
          ),
          const SizedBox(height: 6),
          Text(
            'Segui i passaggi per configurare un nuovo ESP32',
            style: AppTheme.mono(13, color: AppColors.muted2),
          ),
          const SizedBox(height: 16),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: const LinearProgressIndicator(value: 0.45, minHeight: 4, color: AppColors.acc, backgroundColor: AppColors.s2),
          ),
          const SizedBox(height: 20),
          _step(
            done: true,
            active: false,
            numLabel: '✓',
            title: 'Alimenta l\'ESP32',
            desc: 'Collega l\'alimentatore. Il LED lampeggia: sta creando l\'hotspot di configurazione.',
          ),
          _step(
            done: false,
            active: true,
            numLabel: '2',
            title: 'Connettiti all\'hotspot',
            desc: 'Vai in Impostazioni → WiFi sul telefono e connettiti a:',
            extra: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppColors.s2,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border2),
              ),
              child: Row(
                children: [
                  const Text('📶', style: TextStyle(fontSize: 22)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('RetroWave-XXXX-Setup', style: AppTheme.mono(13, color: AppColors.acc, weight: FontWeight.w500)),
                        Text('Nessuna password richiesta', style: AppTheme.mono(11, color: AppColors.muted)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          _step(
            done: false,
            active: false,
            numLabel: '3',
            title: 'Inserisci il WiFi di casa',
            desc: 'Si aprirà un portale captive. Seleziona la tua rete WiFi e inserisci la password. L\'ESP32 la salva in memoria permanente.',
          ),
          _step(
            done: false,
            active: false,
            numLabel: '4',
            title: 'Dai un nome al dispositivo',
            desc: 'L\'app lo trova automaticamente sulla rete. Potrai rinominarlo (es. "Cucina") con un tap lungo sulla card.',
          ),
          const SizedBox(height: 12),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: AppColors.acc,
              foregroundColor: AppColors.bg,
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('Quando l\'ESP32 è online, apparirà in Dispositivi (mDNS).')),
              );
            },
            child: const Text('Ho capito', style: TextStyle(fontWeight: FontWeight.w800)),
          ),
        ],
      ),
    );
  }

  Widget _step({
    required bool done,
    required bool active,
    required String numLabel,
    required String title,
    required String desc,
    Widget? extra,
  }) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.s1,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: active
                ? const Color(0x66F5C518)
                : done
                    ? const Color(0x4D22D3A0)
                    : AppColors.border,
            width: 1.5,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(10),
                color: active
                    ? AppColors.acc
                    : done
                        ? AppColors.green
                        : AppColors.s2,
                border: Border.all(color: active || done ? Colors.transparent : AppColors.border2),
              ),
              child: Text(
                numLabel,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: active || done ? AppColors.bg : AppColors.muted,
                  fontSize: 13,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
            const SizedBox(height: 6),
            Text(desc, style: TextStyle(color: AppColors.muted2, height: 1.55, fontSize: 13)),
            ?extra,
          ],
        ),
      ),
    );
  }
}
