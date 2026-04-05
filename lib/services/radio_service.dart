import 'dart:convert';

import 'package:http/http.dart' as http;

import '../models/radio_station.dart';

/// API pubblica radio-browser (server rotazione de1).
class RadioService {
  static const String _base = 'https://de1.api.radio-browser.info/json';

  Future<List<RadioStation>> searchByName(String query, {int limit = 40}) async {
    if (query.trim().isEmpty) return [];
    final uri = Uri.parse('$_base/stations/search').replace(queryParameters: {
      'name': query.trim(),
      'limit': '$limit',
      'hidebroken': 'true',
    });
    final r = await http.get(uri, headers: {'User-Agent': 'RetroWaveApp/1.0'});
    if (r.statusCode != 200) return [];
    final list = jsonDecode(r.body);
    if (list is! List) return [];
    return list.map((e) => RadioStation.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }

  Future<List<RadioStation>> searchByTag(String tag, {int limit = 40}) async {
    final uri = Uri.parse('$_base/stations/search').replace(queryParameters: {
      'tag': tag,
      'limit': '$limit',
      'hidebroken': 'true',
    });
    final r = await http.get(uri, headers: {'User-Agent': 'RetroWaveApp/1.0'});
    if (r.statusCode != 200) return [];
    final list = jsonDecode(r.body);
    if (list is! List) return [];
    return list.map((e) => RadioStation.fromJson(Map<String, dynamic>.from(e as Map))).toList();
  }
}
