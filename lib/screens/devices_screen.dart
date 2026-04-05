import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/device_manager.dart';
import '../theme/app_theme.dart';
import '../widgets/device_card.dart';
import '../widgets/rename_sheet.dart';

class DevicesScreen extends StatefulWidget {
  const DevicesScreen({super.key});

  @override
  State<DevicesScreen> createState() => _DevicesScreenState();
}

class _DevicesScreenState extends State<DevicesScreen> {
  final _manualCtrl = TextEditingController();
  bool _manualOpen = false;
  /// `null` = chip "Tutti".
  String? _activeGroupId;

  @override
  void dispose() {
    _manualCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DeviceManager>(
      builder: (context, dm, _) {
        final sel = dm.selectedDevices.length;
        final online = dm.onlineCount;
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
                          const TextSpan(text: 'I miei\n', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                          TextSpan(
                            text: 'Dispositivi',
                            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.acc),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$online online · $sel selezionati',
                      style: AppTheme.mono(12),
                    ),
                  ],
                ),
              ),
              if (sel >= 2) _broadcastBar(sel, dm),
              _groupsRow(dm),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.only(top: 4, bottom: 24),
                  children: [
                    ...dm.devices.map(
                      (d) => DeviceCard(
                        device: d,
                        onTap: () => dm.toggleSelection(d.mac),
                        onLongPress: d.mac.startsWith('pending:')
                            ? () {}
                            : () => _rename(context, dm, d.mac, d.displayName),
                      ),
                    ),
                    if (sel >= 2) _multiBar(dm),
                    _addDevice(context),
                    _manualSection(dm),
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: Text(
                        'Tieni premuto per rinominare',
                        textAlign: TextAlign.center,
                        style: AppTheme.mono(11, color: AppColors.muted),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _broadcastBar(int sel, DeviceManager dm) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          gradient: const LinearGradient(colors: [Color(0xFF1A1C12), Color(0xFF1E1F14)]),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: const Color(0x40F5C518)),
        ),
        child: Row(
          children: [
            const Text('📡', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Trasmissione attiva', style: TextStyle(fontWeight: FontWeight.w700, color: AppColors.acc, fontSize: 13)),
                  Text(
                    '${dm.selectedDevices.map((e) => e.displayName).join(' + ')} selezionati',
                    style: AppTheme.mono(11),
                  ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
              decoration: BoxDecoration(color: AppColors.acc, borderRadius: BorderRadius.circular(10)),
              child: Text('$sel', style: AppTheme.mono(12, color: AppColors.bg, weight: FontWeight.w500)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _groupsRow(DeviceManager dm) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          _chip('Tutti', _activeGroupId == null, () {
            setState(() => _activeGroupId = null);
            dm.selectGroup(null);
          }),
          ...dm.groups.map(
            (g) => Padding(
              padding: const EdgeInsets.only(left: 8),
              child: _chip(g.name, _activeGroupId == g.id, () {
                setState(() => _activeGroupId = g.id);
                dm.selectGroup(g);
              }),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(left: 8),
            child: _chip('+ Gruppo', false, () => _newGroup(context, dm)),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, bool selected, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? const Color(0x26F5C518) : AppColors.s2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? const Color(0x66F5C518) : AppColors.border2),
        ),
        child: Row(
          children: [
            Container(
              width: 7,
              height: 7,
              decoration: BoxDecoration(
                color: selected ? AppColors.acc : AppColors.muted,
                shape: BoxShape.circle,
              ),
            ),
            const SizedBox(width: 6),
            Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  Widget _multiBar(DeviceManager dm) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.s2,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border2),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('AZIONI SUI SELEZIONATI', style: AppTheme.mono(11)),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _mact('📻', 'Stessa radio', () async {
                  final url = dm.recentStations.isNotEmpty ? dm.recentStations.first['url'] : null;
                  if (url == null || url.isEmpty) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Scegli una stazione dalla scheda Cerca o Home.')),
                    );
                    return;
                  }
                  await dm.broadcastSameRadio(url, label: dm.recentStations.first['name']);
                }),
                _mact('🔵', 'BT su tutti', () => dm.broadcastBluetooth()),
                _mact('🔊', 'Volume sync', () => dm.syncVolumeSelected()),
                _mact('⏹', 'Stop tutti', () => dm.stopSelected()),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _mact(String icon, String label, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        width: (MediaQuery.sizeOf(context).width - 64) / 2,
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.s3,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border2),
        ),
        child: Column(
          children: [
            Text(icon, style: const TextStyle(fontSize: 18)),
            const SizedBox(height: 4),
            Text(label, textAlign: TextAlign.center, style: AppTheme.mono(10)),
          ],
        ),
      ),
    );
  }

  Widget _addDevice(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
      child: InkWell(
        onTap: () {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Apri la scheda Setup in basso per la procedura guidata WiFi.')),
          );
        },
        borderRadius: BorderRadius.circular(22),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppColors.border2, width: 1.5),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text('➕', style: TextStyle(fontSize: 20)),
              const SizedBox(width: 10),
              Text('Aggiungi dispositivo', style: TextStyle(color: AppColors.muted2, fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _manualSection(DeviceManager dm) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        children: [
          InkWell(
            onTap: () => setState(() => _manualOpen = !_manualOpen),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(_manualOpen ? Icons.expand_less : Icons.expand_more, color: AppColors.muted2),
                Text(
                  'Aggiungi manualmente (IP)',
                  style: AppTheme.mono(12, color: AppColors.muted2),
                ),
              ],
            ),
          ),
          if (_manualOpen) ...[
            const SizedBox(height: 8),
            TextField(
              controller: _manualCtrl,
              style: const TextStyle(fontWeight: FontWeight.w600),
              decoration: InputDecoration(
                hintText: 'es. 192.168.1.50',
                filled: true,
                fillColor: AppColors.s2,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(16)),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: () async {
                final messenger = ScaffoldMessenger.of(context);
                final ok = await dm.addManualHost(_manualCtrl.text.trim());
                if (!context.mounted) return;
                messenger.showSnackBar(
                  SnackBar(content: Text(ok ? 'Dispositivo aggiunto' : 'Connessione fallita')),
                );
              },
              child: const Text('Connetti'),
            ),
          ],
        ],
      ),
    );
  }

  Future<void> _rename(BuildContext context, DeviceManager dm, String mac, String name) async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.s2,
      isScrollControlled: true,
      showDragHandle: false,
      builder: (ctx) {
        return RenameSheet(
          initialName: name,
          macHint: 'MAC · $mac',
          onSave: (n) => dm.renameDevice(mac, n),
        );
      },
    );
  }

  Future<void> _newGroup(BuildContext context, DeviceManager dm) async {
    final nameCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.s2,
        title: const Text('Nuovo gruppo'),
        content: TextField(
          controller: nameCtrl,
          decoration: const InputDecoration(hintText: 'Nome gruppo'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Annulla')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Crea')),
        ],
      ),
    );
    if (ok == true && nameCtrl.text.trim().isNotEmpty) {
      await dm.addGroup(nameCtrl.text.trim(), dm.selectedMacs.toList());
    }
  }
}
