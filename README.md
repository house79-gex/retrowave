# RetroWave

App Flutter per controllare più dispositivi ESP32 (radio HTTP, volume, rinomina, mDNS) e **Bluetooth A2DP** su moduli **ESP32 classico** (es. **ESP32-WROOM-32U** con antenna esterna). L’**ESP32-S3** non supporta Bluetooth Classic: usa il profilo firmware dedicato solo per radio WiFi.

## Firmware (PlatformIO)

Dalla cartella `firmware/`:

```bash
pio run -e esp32-wroom-32u -t upload
```

Profilo predefinito (`default_envs`): **`esp32-wroom-32u`** (A2DP + WiFi + I2S verso PCM5102, pin di default **BCLK=16, LRCK=5, DOUT=17**). Alias: `esp32-wroom-a2dp`.

Per **ESP32-S3** (senza A2DP):

```bash
pio run -e esp32-s3-devkitc-1 -t upload
```

Schema cablaggio: [`docs/schema-collegamento-retrowave.md`](docs/schema-collegamento-retrowave.md).

## App Flutter

```bash
flutter pub get
flutter run
```

API dispositivo: `GET /status` (include `chip`, `board_profile`, `a2dp_*`), `GET /bluetooth`, `GET /stream`, ecc.
