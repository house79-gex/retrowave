import 'dart:convert';

import 'package:http/http.dart' as http;

/// Client HTTP verso un singolo ESP32 (base URL da discovery).
class Esp32Controller {
  Esp32Controller(this.baseUrl);

  final String baseUrl;

  Uri _u(String path, [Map<String, String>? query]) {
    final base = Uri.parse(baseUrl);
    final p = path.startsWith('/') ? path : '/$path';
    return base.replace(
      path: p,
      queryParameters: query,
    );
  }

  Future<Map<String, dynamic>?> getStatus({Duration timeout = const Duration(seconds: 4)}) async {
    try {
      final r = await http.get(_u('/status')).timeout(timeout);
      if (r.statusCode != 200) return null;
      final data = jsonDecode(r.body);
      if (data is Map<String, dynamic>) return data;
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<bool> playStream(String url, {Duration timeout = const Duration(seconds: 8)}) async {
    try {
      final r = await http.get(_u('/stream', {'url': url})).timeout(timeout);
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> stop({Duration timeout = const Duration(seconds: 6)}) async {
    try {
      final r = await http.get(_u('/stop')).timeout(timeout);
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> setVolume(int v, {Duration timeout = const Duration(seconds: 4)}) async {
    final clamped = v.clamp(0, 21);
    try {
      final r = await http.get(_u('/volume', {'v': '$clamped'})).timeout(timeout);
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> toggleBluetooth({Duration timeout = const Duration(seconds: 8)}) async {
    try {
      final r = await http.get(_u('/bluetooth')).timeout(timeout);
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }

  Future<bool> rename(String name, {Duration timeout = const Duration(seconds: 6)}) async {
    try {
      final r = await http
          .post(
            _u('/rename'),
            headers: {'Content-Type': 'application/x-www-form-urlencoded'},
            body: 'name=${Uri.encodeComponent(name)}',
          )
          .timeout(timeout);
      return r.statusCode == 200;
    } catch (_) {
      return false;
    }
  }
}
