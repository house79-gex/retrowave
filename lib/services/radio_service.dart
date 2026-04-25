import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/radio_station.dart';

/// API pubblica radio-browser (server rotazione de1).
class RadioService {
  static const String _base = 'https://de1.api.radio-browser.info/json';
  static const _ua = {'User-Agent': 'RetroWaveApp/2.0'};

  List<RadioStation> _parseList(String body) {
    final list = jsonDecode(body);
    if (list is! List) return [];
    final parsed = list
        .map((e) => RadioStation.fromJson(Map<String, dynamic>.from(e as Map)))
        .where((s) => s.url.trim().isNotEmpty)
        .toList();
    final byUuid = <String, RadioStation>{};
    for (final s in parsed) {
      final k = s.stationUuid.isEmpty ? '${s.name}-${s.url}' : s.stationUuid;
      byUuid[k] = s;
    }
    final out = byUuid.values.toList();
    out.sort((a, b) {
      final av = a.votes ?? 0;
      final bv = b.votes ?? 0;
      if (bv != av) return bv.compareTo(av);
      final ac = a.clickCount ?? 0;
      final bc = b.clickCount ?? 0;
      return bc.compareTo(ac);
    });
    return out;
  }

  Future<List<RadioStation>> searchByName(String query, {int limit = 40}) async {
    if (query.trim().isEmpty) return [];
    final uri = Uri.parse('$_base/stations/search').replace(queryParameters: {
      'name': query.trim(),
      'limit': '$limit',
      'hidebroken': 'true',
    });
    final r = await http.get(uri, headers: _ua);
    if (r.statusCode != 200) return [];
    return _parseList(r.body);
  }

  Future<List<RadioStation>> searchByTag(String tag, {int limit = 40}) async {
    final uri = Uri.parse('$_base/stations/search').replace(queryParameters: {
      'tag': tag,
      'limit': '$limit',
      'hidebroken': 'true',
    });
    final r = await http.get(uri, headers: _ua);
    if (r.statusCode != 200) return [];
    return _parseList(r.body);
  }

  /// Stazioni piu votate (radio-browser): utile senza digitare testo.
  Future<List<RadioStation>> fetchTopByVotes({int limit = 80}) async {
    final uri = Uri.parse('$_base/stations/topvote/$limit');
    final r = await http.get(uri, headers: _ua);
    if (r.statusCode != 200) return [];
    return _parseList(r.body);
  }

  /// Ricerca per paese (codice ISO, es. IT).
  Future<List<RadioStation>> searchByCountry(String countryCode, {int limit = 50}) async {
    final cc = countryCode.trim().toLowerCase();
    if (cc.length != 2) return [];
    final uri = Uri.parse('$_base/stations/bycountrycodeexact/$cc').replace(queryParameters: {
      'limit': '$limit',
      'hidebroken': 'true',
    });
    final r = await http.get(uri, headers: _ua);
    if (r.statusCode != 200) return [];
    return _parseList(r.body);
  }
}
