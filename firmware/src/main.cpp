/**
 * RetroWave — firmware di riferimento ESP32-S3
 * Endpoints HTTP come da documentazione progetto.
 * Integrazione completa I2S/A2DP: collegare librerie e pin secondo l'hardware.
 */
#include <Arduino.h>
#include <WiFi.h>
#include <WebServer.h>
#include <Preferences.h>
#include <ESPmDNS.h>
#include <ArduinoJson.h>

// --- I2S verso GY-PCM5102 ---
// Board generiche DevKit: spesso si usano 25/26/27. La YD-ESP32-S3 NON espone 25–27 sui pinheader.
// Mapping provato per pinheader YD (GPIO 16, 17, 18 vicini sul lato destro della scheda):
#define I2S_BCLK 17
#define I2S_DOUT 18
#define I2S_LRC 16

WebServer server(80);
Preferences prefs;

String deviceName;
String lastUrl;
int volumeLevel = 12;
bool playing = false;
String mode = "radio"; // radio | bluetooth | idle

String macSuffix() {
  uint8_t m[6];
  WiFi.macAddress(m);
  char buf[5];
  snprintf(buf, sizeof(buf), "%02X%02X", m[4], m[5]);
  return String(buf);
}

void saveState() {
  prefs.begin("radio", false);
  prefs.putString("url", lastUrl);
  prefs.putInt("vol", volumeLevel);
  prefs.end();
  prefs.begin("device", false);
  prefs.putString("name", deviceName);
  prefs.end();
}

void loadState() {
  prefs.begin("radio", true);
  lastUrl = prefs.getString("url", "http://icecast.radiodeejay.it/radiodeejay");
  volumeLevel = prefs.getInt("vol", 12);
  prefs.end();
  prefs.begin("device", true);
  deviceName = prefs.getString("name", String("RetroWave-") + macSuffix());
  prefs.end();
}

void handleStatus() {
  DynamicJsonDocument doc(512);
  doc["name"] = deviceName;
  doc["mac"] = WiFi.macAddress();
  doc["mode"] = mode;
  doc["url"] = lastUrl;
  doc["volume"] = volumeLevel;
  doc["playing"] = playing;
  String out;
  serializeJson(doc, out);
  server.send(200, "application/json", out);
}

void handleStream() {
  if (!server.hasArg("url")) {
    server.send(400, "text/plain", "MISSING_URL");
    return;
  }
  lastUrl = server.arg("url");
  playing = true;
  mode = "radio";
  saveState();
  // TODO: audio.connecttohost(lastUrl.c_str());
  server.send(200, "text/plain", "OK");
}

void handleStop() {
  playing = false;
  mode = "idle";
  // TODO: audio.stopSong();
  server.send(200, "text/plain", "STOPPED");
}

void handleVolume() {
  if (!server.hasArg("v")) {
    server.send(400, "text/plain", "MISSING_V");
    return;
  }
  volumeLevel = constrain(server.arg("v").toInt(), 0, 21);
  saveState();
  // TODO: audio.setVolume(map(volumeLevel, 0, 21, 0, 21));
  server.send(200, "text/plain", "OK");
}

void handleBluetooth() {
  mode = (mode == "bluetooth") ? "radio" : "bluetooth";
  server.send(200, "text/plain", mode == "bluetooth" ? "BT_ON" : "RADIO");
}

void handleRename() {
  if (!server.hasArg("name")) {
    server.send(400, "text/plain", "MISSING_NAME");
    return;
  }
  deviceName = server.arg("name");
  saveState();
  MDNS.end();
  MDNS.begin(deviceName.c_str());
  MDNS.addService("retrowave", "tcp", 80);
  server.send(200, "text/plain", "OK");
}

void setup() {
  Serial.begin(115200);
  loadState();

  WiFi.mode(WIFI_STA);
  WiFi.begin(); // Credenziali già salvate da WiFiManager in produzione
  uint32_t start = millis();
  while (WiFi.status() != WL_CONNECTED && millis() - start < 8000) {
    delay(250);
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println(WiFi.localIP());
  } else {
    Serial.println("WiFi: modalità setup richiesta (WiFiManager non incluso in questo stub)");
  }

  // TODO: audio.setPinout(I2S_BCLK, I2S_LRC, I2S_DOUT);
  // TODO: audio.setVolume(volumeLevel);

  server.on("/status", HTTP_GET, handleStatus);
  server.on("/stream", HTTP_GET, handleStream);
  server.on("/stop", HTTP_GET, handleStop);
  server.on("/volume", HTTP_GET, handleVolume);
  server.on("/bluetooth", HTTP_GET, handleBluetooth);
  server.on("/rename", HTTP_POST, handleRename);
  server.begin();

  if (WiFi.status() == WL_CONNECTED) {
    MDNS.begin(deviceName.c_str());
    MDNS.addService("retrowave", "tcp", 80);
  }

  if (lastUrl.length() > 0 && WiFi.status() == WL_CONNECTED) {
    playing = true;
    mode = "radio";
    // TODO: autoplay audio.connecttohost(lastUrl.c_str());
  }
}

void loop() {
  server.handleClient();
  // TODO: audio.loop();
}
