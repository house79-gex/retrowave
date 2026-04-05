import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Bottom sheet per rinominare un dispositivo (POST /rename sul firmware).
class RenameSheet extends StatefulWidget {
  const RenameSheet({
    super.key,
    required this.initialName,
    required this.macHint,
    required this.onSave,
  });

  final String initialName;
  final String macHint;
  final Future<bool> Function(String name) onSave;

  @override
  State<RenameSheet> createState() => _RenameSheetState();
}

class _RenameSheetState extends State<RenameSheet> {
  late final TextEditingController _c;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _c = TextEditingController(text: widget.initialName);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _busy = true);
    final ok = await widget.onSave(_c.text.trim());
    if (!mounted) return;
    setState(() => _busy = false);
    if (ok) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 20,
        right: 20,
        bottom: MediaQuery.paddingOf(context).bottom + 16,
        top: 8,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.border2,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),
          const Text(
            'Rinomina dispositivo',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(widget.macHint, style: AppTheme.mono(12)),
          const SizedBox(height: 14),
          TextField(
            controller: _c,
            style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.s3,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(14),
                borderSide: const BorderSide(color: AppColors.acc, width: 1.5),
              ),
            ),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _busy ? null : () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    side: const BorderSide(color: AppColors.border2),
                  ),
                  child: Text('Annulla', style: TextStyle(color: AppColors.muted2, fontWeight: FontWeight.w700)),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: FilledButton(
                  onPressed: _busy ? null : _save,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    backgroundColor: AppColors.acc,
                    foregroundColor: AppColors.bg,
                  ),
                  child: _busy
                      ? const SizedBox(
                          height: 20,
                          width: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.bg),
                        )
                      : const Text('Salva nome', style: TextStyle(fontWeight: FontWeight.w800)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
