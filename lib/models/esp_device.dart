/// Stato dispositivo ESP32 visto dall'app (da `/status` + discovery).
class EspDevice {
  EspDevice({
    required this.mac,
    required this.displayName,
    required this.host,
    required this.port,
    this.isOnline = false,
    this.mode = 'idle',
    this.currentUrl,
    this.volume = 10,
    this.playing = false,
    this.bitrate,
    this.codec,
    this.stationLabel,
    this.isSelected = false,
    this.pendingKey,
  });

  /// MAC univoco da firmware.
  final String mac;

  /// Nome mostrato (NVS o RetroWave-XXXX).
  String displayName;

  /// Hostname mDNS o IP.
  String host;

  int port;

  bool isOnline;

  /// `radio` | `bluetooth` | `idle` (estensioni ammesse dal firmware).
  String mode;

  String? currentUrl;

  /// 0–21 come da specifica.
  int volume;

  bool playing;

  int? bitrate;

  String? codec;

  /// Etichetta stazione derivata da UI o metadati.
  String? stationLabel;

  bool isSelected;

  /// Chiave temporanea pre-`/status` (es. host:port).
  final String? pendingKey;

  String get baseUrl => port == 80 ? 'http://$host' : 'http://$host:$port';

  EspDevice copyWith({
    String? mac,
    String? displayName,
    String? host,
    int? port,
    bool? isOnline,
    String? mode,
    String? currentUrl,
    int? volume,
    bool? playing,
    int? bitrate,
    String? codec,
    String? stationLabel,
    bool? isSelected,
    String? pendingKey,
  }) {
    return EspDevice(
      mac: mac ?? this.mac,
      displayName: displayName ?? this.displayName,
      host: host ?? this.host,
      port: port ?? this.port,
      isOnline: isOnline ?? this.isOnline,
      mode: mode ?? this.mode,
      currentUrl: currentUrl ?? this.currentUrl,
      volume: volume ?? this.volume,
      playing: playing ?? this.playing,
      bitrate: bitrate ?? this.bitrate,
      codec: codec ?? this.codec,
      stationLabel: stationLabel ?? this.stationLabel,
      isSelected: isSelected ?? this.isSelected,
      pendingKey: pendingKey ?? this.pendingKey,
    );
  }
}
