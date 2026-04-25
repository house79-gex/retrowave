import 'dart:async';

import 'package:cached_network_image/cached_network_image.dart';
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

class _SearchScreenState extends State<SearchScreen> with SingleTickerProviderStateMixin {
  final _q = TextEditingController();
  final _radio = RadioService();
  final _focus = FocusNode();
  List<RadioStation> _searchResults = [];
  List<RadioStation> _popularResults = [];
  List<RadioStation> _italyResults = [];
  bool _loading = false;
  String? _error;
  String _tag = 'Tutti';
  String _sort = 'Rilevanza';
  Timer? _debounce;
  late TabController _tabController;
  int _reqCounter = 0;

  static const _tags = ['Tutti', 'Pop', 'Jazz', 'Rock', 'News', 'Classic', 'Electronic'];
  static const _sortModes = ['Rilevanza', 'Bitrate', 'Nome'];

  List<RadioStation> get _display {
    switch (_tabController.index) {
      case 0:
        return _searchResults;
      case 1:
        return _popularResults;
      case 2:
        return _italyResults;
      default:
        return [];
    }
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _tabController.addListener(() {
      if (!mounted || _tabController.indexIsChanging) return;
      setState(() {});
      if (_tabController.index == 1) unawaited(_loadPopular());
      if (_tabController.index == 2) unawaited(_loadItaly());
    });
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _tabController.dispose();
    _q.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _scheduleSearch() {
    _debounce?.cancel();
    _debounce = Timer(const Duration(milliseconds: 420), _run);
  }

  List<RadioStation> _applySort(List<RadioStation> list) {
    final out = [...list];
    if (_sort == 'Bitrate') {
      out.sort((a, b) => (b.bitrate ?? 0).compareTo(a.bitrate ?? 0));
    } else if (_sort == 'Nome') {
      out.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
    }
    return out;
  }

  Future<void> _run() async {
    if (_q.text.trim().isEmpty && _tag == 'Tutti') {
      setState(() {
        _searchResults = [];
        _error = null;
      });
      return;
    }
    final reqId = ++_reqCounter;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      List<RadioStation> got;
      if (_tag == 'Tutti') {
        got = await _radio.searchByName(_q.text, limit: 80);
      } else {
        got = await _radio.searchByTag(_tag, limit: 80);
      }
      if (!mounted || reqId != _reqCounter) return;
      setState(() {
        _searchResults = _applySort(got);
      });
    } catch (e) {
      if (!mounted || reqId != _reqCounter) return;
      setState(() {
        _error = 'Errore di rete. Riprova.';
        _searchResults = [];
      });
    } finally {
      if (mounted && reqId == _reqCounter) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _loadPopular() async {
    final reqId = ++_reqCounter;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final got = await _radio.fetchTopByVotes(limit: 120);
      if (!mounted || reqId != _reqCounter) return;
      setState(() => _popularResults = _applySort(got));
    } catch (_) {
      if (!mounted || reqId != _reqCounter) return;
      setState(() {
        _error = 'Impossibile caricare la classifica.';
        _popularResults = [];
      });
    } finally {
      if (mounted && reqId == _reqCounter) setState(() => _loading = false);
    }
  }

  Future<void> _loadItaly() async {
    final reqId = ++_reqCounter;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final got = await _radio.searchByCountry('it', limit: 120);
      if (!mounted || reqId != _reqCounter) return;
      setState(() => _italyResults = _applySort(got));
    } catch (_) {
      if (!mounted || reqId != _reqCounter) return;
      setState(() {
        _error = 'Impossibile caricare le radio italiane.';
        _italyResults = [];
      });
    } finally {
      if (mounted && reqId == _reqCounter) setState(() => _loading = false);
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
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text.rich(
                        TextSpan(
                          children: [
                            TextSpan(text: 'Radio ', style: AppTheme.displayTitle(size: 26)),
                            TextSpan(text: 'world', style: AppTheme.displayTitle(size: 26, accent: AppColors.acc)),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Aggiorna',
                      onPressed: _loading
                          ? null
                          : () {
                              if (_tabController.index == 0) {
                                _run();
                              } else if (_tabController.index == 1) {
                                _loadPopular();
                              } else {
                                _loadItaly();
                              }
                            },
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ],
                ),
              ),
              TabBar(
                controller: _tabController,
                labelColor: AppColors.acc,
                unselectedLabelColor: AppColors.muted,
                indicatorColor: AppColors.acc,
                tabs: const [
                  Tab(text: 'Cerca'),
                  Tab(text: 'Popolari'),
                  Tab(text: 'Italia'),
                ],
              ),
              if (_tabController.index == 0) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                  child: TextField(
                    controller: _q,
                    focusNode: _focus,
                    style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
                    decoration: InputDecoration(
                      hintText: 'Nome stazione, genere, città…',
                      prefixIcon: const Icon(Icons.search_rounded, color: AppColors.muted),
                      suffixIcon: _q.text.isNotEmpty
                          ? IconButton(
                              icon: const Icon(Icons.clear_rounded),
                              onPressed: () {
                                _q.clear();
                                setState(() => _searchResults = []);
                                _scheduleSearch();
                              },
                            )
                          : null,
                      filled: true,
                      fillColor: AppColors.s2,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(color: AppColors.border2),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(color: AppColors.border2),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(18),
                        borderSide: const BorderSide(color: AppColors.acc, width: 1.5),
                      ),
                    ),
                    onChanged: (_) {
                      setState(() {});
                      _scheduleSearch();
                    },
                    onSubmitted: (_) => _run(),
                  ),
                ),
                SizedBox(
                  height: 40,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    children: _tags.map((t) {
                      final on = _tag == t;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(t),
                          selected: on,
                          onSelected: (_) {
                            setState(() => _tag = t);
                            if (_q.text.isNotEmpty || t != 'Tutti') _run();
                          },
                          selectedColor: AppColors.accSoft,
                          checkmarkColor: AppColors.acc,
                          labelStyle: TextStyle(
                            color: on ? AppColors.acc : AppColors.text,
                            fontWeight: on ? FontWeight.w700 : FontWeight.w500,
                            fontSize: 13,
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                ),
                const SizedBox(height: 4),
              ],
              SizedBox(
                height: 36,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: _sortModes.map((s) {
                    final selected = _sort == s;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text('Ordina: $s'),
                        selected: selected,
                        onSelected: (_) {
                          setState(() => _sort = s);
                          _searchResults = _applySort(_searchResults);
                          _popularResults = _applySort(_popularResults);
                          _italyResults = _applySort(_italyResults);
                        },
                        selectedColor: AppColors.accSoft,
                      ),
                    );
                  }).toList(),
                ),
              ),
              const SizedBox(height: 8),
              _targetChips(dm),
              if (_loading) const LinearProgressIndicator(minHeight: 2, color: AppColors.acc),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Text(_error!, style: TextStyle(color: AppColors.red)),
                ),
              Expanded(
                child: _display.isEmpty && !_loading
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(Icons.radio_rounded, size: 56, color: AppColors.muted.withValues(alpha: 0.4)),
                              const SizedBox(height: 16),
                              Text(
                                _tabController.index == 0
                                    ? 'Cerca migliaia di stazioni\n(radio-browser.info)'
                                    : _tabController.index == 1
                                        ? 'Caricamento classifica… tocca Popolari'
                                        : 'Caricamento radio italiane…',
                                textAlign: TextAlign.center,
                                style: TextStyle(color: AppColors.muted2, height: 1.5),
                              ),
                            ],
                          ),
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: _display.length,
                        itemBuilder: (context, i) => _stationTile(context, dm, _display[i]),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _targetChips(DeviceManager dm) {
    return SizedBox(
      height: 40,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        children: [
          Text('A:', style: AppTheme.mono(11, color: AppColors.muted)),
          const SizedBox(width: 8),
          ...dm.devices.where((d) => !d.mac.startsWith('pending:')).map(
                (d) => Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: FilterChip(
                    label: Text(d.displayName, style: const TextStyle(fontSize: 12)),
                    selected: dm.targetMacs.isEmpty || dm.targetMacs.contains(d.mac),
                    onSelected: (_) => dm.toggleTarget(d.mac),
                    visualDensity: VisualDensity.compact,
                  ),
                ),
              ),
          ActionChip(
            label: const Text('Tutti'),
            onPressed: () => dm.setAllTargets(),
            visualDensity: VisualDensity.compact,
          ),
        ],
      ),
    );
  }

  Widget _stationTile(BuildContext context, DeviceManager dm, RadioStation s) {
    final https = s.url.toLowerCase().startsWith('https:');
    final subtitle = <String>[
      if ((s.country ?? '').trim().isNotEmpty) s.country!.trim(),
      if ((s.language ?? '').trim().isNotEmpty) s.language!.trim(),
      if (s.bitrate != null) '${s.bitrate} kbps',
      if ((s.codec ?? '').trim().isNotEmpty) s.codec!.trim(),
    ].join(' · ');
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: AppColors.s1,
        borderRadius: BorderRadius.circular(20),
        child: InkWell(
          onTap: () {
            dm.markNowPlaying(url: s.url, name: s.name, logoUrl: s.favicon);
            dm.playUrlOnTargets(s.url, label: s.name);
          },
          borderRadius: BorderRadius.circular(20),
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(14),
                  child: SizedBox(
                    width: 56,
                    height: 56,
                    child: s.favicon != null && s.favicon!.startsWith('http')
                        ? CachedNetworkImage(
                            imageUrl: s.favicon!,
                            fit: BoxFit.cover,
                            placeholder: (ctx, url) => ColoredBox(
                              color: AppColors.s2,
                              child: Icon(Icons.radio_rounded, color: AppColors.muted.withValues(alpha: 0.5)),
                            ),
                            errorWidget: (ctx, url, err) => ColoredBox(
                              color: AppColors.s2,
                              child: const Icon(Icons.music_note_rounded, color: AppColors.acc),
                            ),
                          )
                        : ColoredBox(
                            color: AppColors.s2,
                            child: const Icon(Icons.music_note_rounded, color: AppColors.acc),
                          ),
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        s.name,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle.isEmpty ? 'Metadati non disponibili' : subtitle,
                        style: AppTheme.mono(11, color: AppColors.muted2),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Voti ${s.votes ?? 0} · Click ${s.clickCount ?? 0}',
                        style: AppTheme.mono(10, color: AppColors.muted),
                      ),
                      if (https)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(
                            'HTTPS: l’ESP la supporta se il firmware ha SSL attivo',
                            style: AppTheme.mono(10, color: AppColors.cyan),
                          ),
                        ),
                    ],
                  ),
                ),
                FilledButton.tonal(
                  onPressed: () {
                    dm.markNowPlaying(url: s.url, name: s.name, logoUrl: s.favicon);
                    dm.playUrlOnTargets(s.url, label: s.name);
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Inviato: ${s.name}')),
                    );
                  },
                  child: const Icon(Icons.play_arrow_rounded),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
