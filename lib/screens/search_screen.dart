import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/radio_station.dart';
import '../services/device_manager.dart';
import '../services/radio_service.dart';
import '../theme/app_theme.dart';

class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final _q = TextEditingController();
  final _radio = RadioService();
  List<RadioStation> _results = [];
  bool _loading = false;
  String _tag = 'Tutti';

  static const _tags = ['Tutti', 'Pop', 'Jazz', 'Rock', 'News', 'Classic', 'Electronic'];

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _run(DeviceManager dm) async {
    setState(() => _loading = true);
    try {
      if (_tag == 'Tutti') {
        _results = await _radio.searchByName(_q.text);
      } else {
        _results = await _radio.searchByTag(_tag);
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<DeviceManager>(
      builder: (context, dm, _) {
        return SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(24, 8, 24, 8),
                child: Text.rich(
                  TextSpan(
                    children: [
                      const TextSpan(text: 'Cerca ', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                      TextSpan(text: 'Radio', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, color: AppColors.acc)),
                    ],
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: TextField(
                  controller: _q,
                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
                  decoration: InputDecoration(
                    hintText: 'Stazione, genere, paese...',
                    prefixIcon: const Icon(Icons.search, color: AppColors.muted),
                    filled: true,
                    fillColor: AppColors.s2,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(18),
                      borderSide: const BorderSide(color: AppColors.border2, width: 1.5),
                    ),
                  ),
                  onSubmitted: (_) => _run(dm),
                ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 38,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: _tags.map((t) {
                    final on = _tag == t;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(t),
                        selected: on,
                        onSelected: (_) {
                          setState(() => _tag = t);
                          if (_q.text.isNotEmpty || t != 'Tutti') _run(dm);
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),
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
                    ActionChip(
                      label: const Text('Tutti'),
                      onPressed: () => dm.setAllTargets(),
                    ),
                  ],
                ),
              ),
              if (_loading) const LinearProgressIndicator(minHeight: 2),
              Expanded(
                child: ListView.builder(
                  itemCount: _results.length,
                  itemBuilder: (context, i) {
                    final s = _results[i];
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: AppColors.s2,
                        child: Text(_emoji(i), style: const TextStyle(fontSize: 20)),
                      ),
                      title: Text(s.name, maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(
                        '${s.tags ?? ''} · ${s.country ?? ''} · ${s.bitrate ?? '-'} kbps',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.mono(11),
                      ),
                      trailing: FilledButton.tonal(
                        onPressed: () => dm.playUrlOnTargets(s.url, label: s.name),
                        child: const Text('Invia'),
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

  String _emoji(int i) {
    const e = ['🎷', '🎺', '🥁', '🎹', '🎻', '📻'];
    return e[i % e.length];
  }
}
