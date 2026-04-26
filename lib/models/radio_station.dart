/// Stazione da radio-browser.info.
class RadioStation {
  RadioStation({
    required this.stationUuid,
    required this.name,
    required this.url,
    this.urlResolved,
    this.favicon,
    this.country,
    this.tags,
    this.bitrate,
    this.codec,
    this.homepage,
    this.language,
    this.votes,
    this.clickCount,
  });

  final String stationUuid;
  final String name;
  final String url;
  final String? urlResolved;
  final String? favicon;
  final String? country;
  final String? tags;
  final int? bitrate;
  final String? codec;
  final String? homepage;
  final String? language;
  final int? votes;
  final int? clickCount;

  /// URL migliore da usare verso il device (preferisce quello risolto da radio-browser).
  String get playableUrl {
    final resolved = (urlResolved ?? '').trim();
    if (resolved.isNotEmpty) return resolved;
    return url.trim();
  }

  factory RadioStation.fromJson(Map<String, dynamic> j) {
    return RadioStation(
      stationUuid: (j['stationuuid'] ?? j['stationUuid'] ?? '').toString(),
      name: (j['name'] ?? 'Sconosciuta').toString(),
      url: (j['url'] ?? '').toString(),
      urlResolved: (j['url_resolved'] ?? j['urlResolved'])?.toString(),
      favicon: j['favicon']?.toString(),
      country: j['country']?.toString(),
      tags: j['tags']?.toString(),
      bitrate: _intOrNull(j['bitrate']),
      codec: j['codec']?.toString(),
      homepage: j['homepage']?.toString(),
      language: j['language']?.toString(),
      votes: _intOrNull(j['votes']),
      clickCount: _intOrNull(j['clickcount']),
    );
  }

  static int? _intOrNull(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }
}
