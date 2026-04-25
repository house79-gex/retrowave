/**
 * Bridge A2DP: implementato solo su ESP32 (Classic BT). Su ESP32-S3 sono stub no-op.
 */
#include <Arduino.h>

#include "a2dp_bridge.h"

#if defined(CONFIG_IDF_TARGET_ESP32)

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

static void onConnectionState(esp_a2d_connection_state_t state, void* /*obj*/) {
  g_connected = (state == ESP_A2D_CONNECTION_STATE_CONNECTED);
}

static uint8_t mapVolume21to127(int v) {
  v = constrain(v, 0, 21);
  return static_cast<uint8_t>((v * 127 + 10) / 21);
}

extern "C" bool retroA2dpSupportsHardware() {
  return true;
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
  delay(120);
}

extern "C" void retroA2dpEnterBluetooth(const char* deviceName, int volume0_21) {
  if (deviceName == nullptr || deviceName[0] == '\0') {
    return;
  }
  retroA2dpLeaveBluetooth();
  g_sink = new BluetoothA2DPSink();
  i2s_pin_config_t pins = {.mck_io_num = I2S_PIN_NO_CHANGE,
                           .bck_io_num = static_cast<gpio_num_t>(I2S_BCLK),
                           .ws_io_num = static_cast<gpio_num_t>(I2S_LRC),
                           .data_out_num = static_cast<gpio_num_t>(I2S_DOUT),
                           .data_in_num = I2S_PIN_NO_CHANGE};
  g_sink->set_pin_config(pins);
  g_sink->set_on_connection_state_changed(onConnectionState, nullptr);
  g_sink->set_volume(mapVolume21to127(volume0_21));
  g_sink->start(deviceName);
}

extern "C" void retroA2dpSetVolume(int volume0_21) {
  if (g_sink == nullptr) {
    return;
  }
  g_sink->set_volume(mapVolume21to127(volume0_21));
}

#else

extern "C" bool retroA2dpSupportsHardware() {
  return false;
}

extern "C" bool retroA2dpIsSinkRunning() {
  return false;
}

extern "C" bool retroA2dpIsConnected() {
  return false;
}

extern "C" void retroA2dpLeaveBluetooth() {}

extern "C" void retroA2dpEnterBluetooth(const char* /*deviceName*/, int /*volume0_21*/) {}

extern "C" void retroA2dpSetVolume(int /*volume0_21*/) {}

#endif
