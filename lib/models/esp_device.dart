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
    this.chip,
    this.a2dpSinkCapable,
    this.a2dpSinkStarted = false,
    this.a2dpConnected = false,
    this.a2dpPairingName,
    this.boardProfile,
    this.streamTitle,
    this.streamStation,
    this.streamIcyUrl,
    this.streamIcyDescription,
    this.stationLogoUrl,
    this.lastSeenMs = 0,
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

  /// Da `/status` (`chip`), es. `ESP32-S3` / `ESP32`.
  final String? chip;

  /// `true` se il firmware espone sink A2DP (ESP32 Classic); su S3 è `false`.
  final bool? a2dpSinkCapable;

  /// Sink A2DP avviato (mode bluetooth + stack attivo).
  final bool a2dpSinkStarted;

  /// Telefono sorgente collegato in A2DP.
  final bool a2dpConnected;

  /// Nome Bluetooth visibile in accoppiamento (di solito uguale al nome dispositivo).
  final String? a2dpPairingName;

  /// Da `/status` (`board_profile`), es. `ESP32-WROOM-32U`.
  final String? boardProfile;

  /// Metadati runtime dallo stream (ICY/ID3) esposti dal firmware.
  final String? streamTitle;
  final String? streamStation;
  final String? streamIcyUrl;
  final String? streamIcyDescription;

  /// Logo associato dalla UI (radio-browser) per visualizzazione schede.
  final String? stationLogoUrl;

  /// Epoch ms ultimo aggiornamento riuscito da discovery/poll.
  final int lastSeenMs;

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
    String? chip,
    bool? a2dpSinkCapable,
    bool? a2dpSinkStarted,
    bool? a2dpConnected,
    String? a2dpPairingName,
    String? boardProfile,
    String? streamTitle,
    String? streamStation,
    String? streamIcyUrl,
    String? streamIcyDescription,
    String? stationLogoUrl,
    int? lastSeenMs,
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
      chip: chip ?? this.chip,
      a2dpSinkCapable: a2dpSinkCapable ?? this.a2dpSinkCapable,
      a2dpSinkStarted: a2dpSinkStarted ?? this.a2dpSinkStarted,
      a2dpConnected: a2dpConnected ?? this.a2dpConnected,
      a2dpPairingName: a2dpPairingName ?? this.a2dpPairingName,
      boardProfile: boardProfile ?? this.boardProfile,
      streamTitle: streamTitle ?? this.streamTitle,
      streamStation: streamStation ?? this.streamStation,
      streamIcyUrl: streamIcyUrl ?? this.streamIcyUrl,
      streamIcyDescription: streamIcyDescription ?? this.streamIcyDescription,
      stationLogoUrl: stationLogoUrl ?? this.stationLogoUrl,
      lastSeenMs: lastSeenMs ?? this.lastSeenMs,
    );
  }
}
