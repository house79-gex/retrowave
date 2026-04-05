/// Stazione da radio-browser.info.
class RadioStation {
  RadioStation({
    required this.stationUuid,
    required this.name,
    required this.url,
    this.favicon,
    this.country,
    this.tags,
    this.bitrate,
    this.codec,
  });

  final String stationUuid;
  final String name;
  final String url;
  final String? favicon;
  final String? country;
  final String? tags;
  final int? bitrate;
  final String? codec;

  factory RadioStation.fromJson(Map<String, dynamic> j) {
    return RadioStation(
      stationUuid: (j['stationuuid'] ?? j['stationUuid'] ?? '').toString(),
      name: (j['name'] ?? 'Sconosciuta').toString(),
      url: (j['url'] ?? '').toString(),
      favicon: j['favicon']?.toString(),
      country: j['country']?.toString(),
      tags: j['tags']?.toString(),
      bitrate: _intOrNull(j['bitrate']),
      codec: j['codec']?.toString(),
    );
  }

  static int? _intOrNull(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    return int.tryParse(v.toString());
  }
}
