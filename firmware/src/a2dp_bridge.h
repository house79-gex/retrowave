#pragma once

#ifdef __cplusplus
extern "C" {
#endif

/// True solo su ESP32 con Bluetooth Classic (non ESP32-S3 / -C3).
bool retroA2dpSupportsHardware(void);

/// Inizializza il controller BT (Classic-only) PRIMA che WiFi si connetta.
/// Deve essere chiamato dopo WiFi.mode() ma prima di wm.autoConnect().
bool retroA2dpPreInitController(void);

bool retroA2dpIsSinkRunning(void);
bool retroA2dpIsConnected(void);

void retroA2dpLeaveBluetooth(void);

/// Avvia sink A2DP con nome visibile al telefono; volume firmware 0..21 → mappato internamente.
void retroA2dpEnterBluetooth(const char* deviceName, int volume0_21);

/// Allinea volume sink (0..21) se A2DP attivo.
void retroA2dpSetVolume(int volume0_21);

#ifdef __cplusplus
}
#endif
