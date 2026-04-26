/**
 * Bridge A2DP — solo ESP32 Classic (su ESP32-S3 = stub no-op).
 *
 * Problema risolto (coex_core_enable abort):
 *   Il controller BT deve essere abilitato PRIMA che WiFi completi la
 *   connessione, altrimenti il modulo di coesistenza radio (coex) non accetta
 *   un BT enable tardivo e chiama abort().
 *
 * Sequenza corretta:
 *   1) WiFi.mode(WIFI_STA)          → esp_wifi_init() → coex_init()
 *   2) retroA2dpPreInitController() → esp_bt_controller_init/enable (Classic)
 *   3) wm.autoConnect()             → WiFi si connette (coex gia' attivo)
 *   4) retroA2dpEnterBluetooth()    → avvia A2DP sink + I2S manuale
 */
#include <Arduino.h>

#include "a2dp_bridge.h"

#if defined(CONFIG_IDF_TARGET_ESP32)

#include <esp_bt.h>
#include <driver/i2s.h>
#include "BluetoothA2DPSink.h"

#ifndef I2S_BCLK
#define I2S_BCLK 26
#endif
#ifndef I2S_LRC
#define I2S_LRC 25
#endif
#ifndef I2S_DOUT
#define I2S_DOUT 22
#endif

static BluetoothA2DPSink* g_sink = nullptr;
static volatile bool g_connected = false;
static volatile bool g_i2sInstalled = false;
static bool g_btControllerReady = false;

static void onConnectionState(esp_a2d_connection_state_t state, void*) {
  g_connected = (state == ESP_A2D_CONNECTION_STATE_CONNECTED);
}

static uint8_t mapVolume21to127(int v) {
  v = constrain(v, 0, 21);
  return static_cast<uint8_t>((v * 127 + 10) / 21);
}

// ---- I2S manuale (evita conflitto con Audio library) ------------------------

static void installI2S() {
  if (g_i2sInstalled) return;
  i2s_config_t cfg = {
      .mode = (i2s_mode_t)(I2S_MODE_MASTER | I2S_MODE_TX),
      .sample_rate = 44100,
      .bits_per_sample = I2S_BITS_PER_SAMPLE_16BIT,
      .channel_format = I2S_CHANNEL_FMT_RIGHT_LEFT,
      .communication_format = I2S_COMM_FORMAT_STAND_I2S,
      .intr_alloc_flags = 0,
      .dma_buf_count = 8,
      .dma_buf_len = 64,
      .use_apll = false,
      .tx_desc_auto_clear = true,
      .fixed_mclk = 0,
      .mclk_multiple = (i2s_mclk_multiple_t)0,
      .bits_per_chan = I2S_BITS_PER_CHAN_DEFAULT};
  esp_err_t err = i2s_driver_install(I2S_NUM_0, &cfg, 0, nullptr);
  if (err != ESP_OK) {
    Serial.printf("A2DP-bridge: i2s_driver_install err=%d\n", err);
    return;
  }
  i2s_pin_config_t pins = {.mck_io_num = I2S_PIN_NO_CHANGE,
                           .bck_io_num = I2S_BCLK,
                           .ws_io_num = I2S_LRC,
                           .data_out_num = I2S_DOUT,
                           .data_in_num = I2S_PIN_NO_CHANGE};
  i2s_set_pin(I2S_NUM_0, &pins);
  g_i2sInstalled = true;
  Serial.println(F("A2DP-bridge: I2S installato OK"));
}

static void uninstallI2S() {
  if (!g_i2sInstalled) return;
  i2s_driver_uninstall(I2S_NUM_0);
  g_i2sInstalled = false;
}

// ---- Callback PCM → I2S -----------------------------------------------------

static void audioDataCallback(const uint8_t* data, uint32_t len) {
  if (!g_i2sInstalled) return;
  size_t written = 0;
  i2s_write(I2S_NUM_0, data, len, &written, portMAX_DELAY);
}

// ---- API pubblica -----------------------------------------------------------

extern "C" bool retroA2dpSupportsHardware() {
  return true;
}

extern "C" bool retroA2dpPreInitController() {
  if (g_btControllerReady) return true;

  esp_err_t err;

  err = esp_bt_controller_mem_release(ESP_BT_MODE_BLE);
  Serial.printf("A2DP-bridge: mem_release BLE %s\n",
                (err == ESP_OK) ? "OK" : "skip (non fatale)");

  esp_bt_controller_config_t cfg = BT_CONTROLLER_INIT_CONFIG_DEFAULT();
  cfg.mode = ESP_BT_MODE_CLASSIC_BT;

  if (esp_bt_controller_get_status() == ESP_BT_CONTROLLER_STATUS_IDLE) {
    err = esp_bt_controller_init(&cfg);
    if (err != ESP_OK) {
      Serial.printf("A2DP-bridge: bt_controller_init FAILED: %d\n", err);
      return false;
    }
    while (esp_bt_controller_get_status() == ESP_BT_CONTROLLER_STATUS_IDLE) {
      delay(10);
    }
    Serial.println(F("A2DP-bridge: bt_controller_init OK"));
  }

  if (esp_bt_controller_get_status() == ESP_BT_CONTROLLER_STATUS_INITED) {
    err = esp_bt_controller_enable(ESP_BT_MODE_CLASSIC_BT);
    if (err != ESP_OK) {
      Serial.printf("A2DP-bridge: bt_controller_enable FAILED: %d\n", err);
      return false;
    }
    Serial.println(F("A2DP-bridge: bt_controller_enable OK"));
  }

  g_btControllerReady =
      (esp_bt_controller_get_status() == ESP_BT_CONTROLLER_STATUS_ENABLED);
  Serial.printf("A2DP-bridge: controller %s (Classic-only, pre-WiFi)\n",
                g_btControllerReady ? "PRONTO" : "FALLITO");
  return g_btControllerReady;
}

extern "C" bool retroA2dpIsSinkRunning() {
  return g_sink != nullptr;
}

extern "C" bool retroA2dpIsConnected() {
  return g_connected;
}

extern "C" void retroA2dpLeaveBluetooth() {
  g_connected = false;
  if (g_sink != nullptr) {
    g_sink->end(false);
    delete g_sink;
    g_sink = nullptr;
  }
  uninstallI2S();
  delay(120);
}

extern "C" void retroA2dpEnterBluetooth(const char* deviceName, int volume0_21) {
  if (deviceName == nullptr || deviceName[0] == '\0') return;
  retroA2dpLeaveBluetooth();

  if (!g_btControllerReady) {
    Serial.println(F("A2DP-bridge: controller non pronto! Chiamare retroA2dpPreInitController() prima di WiFi."));
    return;
  }

  installI2S();

  g_sink = new BluetoothA2DPSink();
  g_sink->set_stream_reader(audioDataCallback, false);
  g_sink->set_on_connection_state_changed(onConnectionState, nullptr);
  g_sink->set_volume(mapVolume21to127(volume0_21));
  g_sink->start(deviceName);
  Serial.println(F("A2DP-bridge: sink avviato (Classic BT + I2S manuale)"));
}

extern "C" void retroA2dpSetVolume(int volume0_21) {
  if (g_sink == nullptr) return;
  g_sink->set_volume(mapVolume21to127(volume0_21));
}

#else

extern "C" bool retroA2dpSupportsHardware() { return false; }
extern "C" bool retroA2dpPreInitController() { return false; }
extern "C" bool retroA2dpIsSinkRunning() { return false; }
extern "C" bool retroA2dpIsConnected() { return false; }
extern "C" void retroA2dpLeaveBluetooth() {}
extern "C" void retroA2dpEnterBluetooth(const char*, int) {}
extern "C" void retroA2dpSetVolume(int) {}

#endif
