/**
 * RetroWave — firmware unico per:
 * - ESP32-WROOM-32U (e DevKit classico): WiFi + HTTP + I2S + sink A2DP (PlatformIO `esp32-wroom-32u`);
 * - ESP32-S3: WiFi + HTTP + I2S, senza Bluetooth Classic (solo `mode` interno per BT).
 */
#include <Arduino.h>
#include <cstdio>
#include <cstring>
#include <WiFi.h>
#include <WebServer.h>
#include <Preferences.h>
#include <ESPmDNS.h>
#include <ArduinoJson.h>
#include <WiFiManager.h>
#include "Audio.h"
#include "a2dp_bridge.h"

// --- I2S verso GY-PCM5102 ---
// S3 (default): pinheader YD — GPIO 16, 17, 18.
// ESP32-WROOM-32U / DevKit: override da platformio.ini (default 16/5/17 per PCM5102: BCK/LRCK/DIN).
#ifndef I2S_BCLK
#define I2S_BCLK 17
#endif
#ifndef I2S_DOUT
#define I2S_DOUT 18
#endif
#ifndef I2S_LRC
#define I2S_LRC 16
#endif

// Stream HTTP diretto MP3 (no HLS/m3u8). Gli stream che rispondono solo con playlist m3u8 richiedono PSRAM abilitata nel firmware.
static const char kDefaultStreamUrl[] = "http://ice1.somafm.com/groovesalad-128-mp3";

WebServer server(80);
Preferences prefs;
Audio audio;

String deviceName;
String lastUrl;
int volumeLevel = 12;
bool playing = false;
String mode = "radio"; // radio | bluetooth | idle
String streamStation;
String streamTitle;
String streamIcyUrl;
String streamIcyDescription;

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
  prefs.putString("mode", mode);
  prefs.end();
  prefs.begin("device", false);
  prefs.putString("name", deviceName);
  prefs.end();
}

void loadState() {
  bool fixedInvalidBtMode = false;
  // Usa read-write anche al primo boot: evita errori NOT_FOUND se namespace ancora assente.
  prefs.begin("radio", false);
  lastUrl = prefs.getString("url", kDefaultStreamUrl);
  volumeLevel = prefs.getInt("vol", 12);
  {
    String m = prefs.getString("mode", "radio");
    if (m == "bluetooth" && !retroA2dpSupportsHardware()) {
      mode = "radio";
      fixedInvalidBtMode = true;
    } else if (m.length() > 0) {
      mode = m;
    }
  }
  prefs.end();
  if (fixedInvalidBtMode) {
    prefs.begin("radio", false);
    prefs.putString("mode", mode);
    prefs.end();
  }
  prefs.begin("device", false);
  deviceName = prefs.getString("name", String("RetroWave-") + macSuffix());
  prefs.end();

  // Icecast Deejay (e simili) spesso reindirizzano a HLS: senza PSRAM si ottiene "m3u8 playlists requires PSRAM".
  if (lastUrl.indexOf("radiodeejay.it") >= 0 || lastUrl.indexOf(".m3u8") >= 0) {
    lastUrl = kDefaultStreamUrl;
    saveState();
    Serial.println(F("URL radio: sostituito con stream MP3 diretto (l'URL precedente usava HLS/m3u8)."));
  }
}

static const char* chipModelString() {
#if defined(CONFIG_IDF_TARGET_ESP32S3)
  return "ESP32-S3";
#elif defined(CONFIG_IDF_TARGET_ESP32)
  return "ESP32";
#else
  return "ESP32-family";
#endif
}

#if defined(RETROWAVE_BOARD_WROOM32U)
static const char* boardProfileString() {
  return "ESP32-WROOM-32U";
}
#else
static const char* boardProfileString() {
  return "";
}
#endif

// Log diagnostici verso Serial (monitor PC a 115200 baud). Callback weak di ESP32-audioI2S 2.x.
void audio_info(const char* info) {
  if (info != nullptr) {
    Serial.printf("[Audio] %s\n", info);
  }
}

// Metadati stream (ICY/ID3) dal decoder audioI2S.
void audio_showstation(const char* info) {
  streamStation = (info == nullptr) ? "" : String(info);
}

void audio_showstreamtitle(const char* info) {
  streamTitle = (info == nullptr) ? "" : String(info);
}

void audio_icyurl(const char* info) {
  streamIcyUrl = (info == nullptr) ? "" : String(info);
}

void audio_icydescription(const char* info) {
  streamIcyDescription = (info == nullptr) ? "" : String(info);
}

static void startRadioStream(const char* url) {
  if (url == nullptr || strlen(url) == 0) {
    return;
  }
  streamStation = "";
  streamTitle = "";
  streamIcyUrl = "";
  streamIcyDescription = "";
  Serial.printf("Audio: avvio stream %s\n", url);
  audio.stopSong();
  delay(150);
  audio.connecttohost(url);
}

void handleStatus() {
  JsonDocument doc;
  doc["name"] = deviceName;
  doc["mac"] = WiFi.macAddress();
  doc["chip"] = chipModelString();
  doc["mode"] = mode;
  doc["url"] = lastUrl;
  doc["volume"] = volumeLevel;
  doc["playing"] = playing;
  doc["stream_station"] = streamStation;
  doc["stream_title"] = streamTitle;
  doc["stream_icy_url"] = streamIcyUrl;
  doc["stream_icy_description"] = streamIcyDescription;
  doc["a2dp_sink_capable"] = retroA2dpSupportsHardware();
  doc["a2dp_sink_started"] = retroA2dpIsSinkRunning();
  doc["a2dp_connected"] = retroA2dpIsConnected();
  doc["a2dp_pairing_name"] = deviceName;
  {
    const char* bp = boardProfileString();
    if (bp != nullptr && bp[0] != '\0') {
      doc["board_profile"] = bp;
    }
  }
  String out;
  serializeJson(doc, out);
  server.send(200, "application/json", out);
}

// Diagnostica: WiFi, pin I2S attesi, stato decoder/buffer (non sostituisce il multimetro sul DAC).
void handleDiag() {
  JsonDocument doc;

  doc["serial"]["baud"] = 115200;
  doc["serial"]["hint"] =
      "Windows: Gestione dispositivi -> Porte (COM e LPT); CP2104/CH343/CP2102 spesso COM3–COM15. "
      "Apri monitor a 115200 baud e guarda le righe [Audio].";

  doc["http"]["diag_url"] = "GET /diag";
  doc["http"]["status_url"] = "GET /status";

  JsonObject w = doc["wifi"].to<JsonObject>();
  w["connected"] = (WiFi.status() == WL_CONNECTED);
  w["ip"] = WiFi.localIP().toString();
  w["ssid"] = WiFi.SSID();
  w["rssi_dbm"] = (WiFi.status() == WL_CONNECTED) ? WiFi.RSSI() : 0;
  w["gateway"] = WiFi.gatewayIP().toString();

  JsonObject i2s = doc["i2s_expected"].to<JsonObject>();
  i2s["bclk_gpio"] = I2S_BCLK;
  i2s["lrck_ws_gpio"] = I2S_LRC;
  i2s["dout_from_esp_gpio"] = I2S_DOUT;
  i2s["dac_module"] = "GY-PCM5102: BCK<-BCLK, LCK<-LRCK, DIN<-DOUT_ESP, SCK->GND, VIN<-3V3, GND comune";
  i2s["i2s_port"] = audio.getI2sPort();

  JsonObject au = doc["audio_engine"].to<JsonObject>();
  au["running"] = audio.isRunning();
  au["volume_0_21"] = audio.getVolume();
  au["psram_size_kb"] = ESP.getPsramSize() / 1024;
  au["codec"] = audio.getCodecname();
  au["sample_rate_hz"] = audio.getSampleRate();
  au["bits_per_sample"] = audio.getBitsPerSample();
  au["channels"] = audio.getChannels();
  au["bitrate_bps"] = audio.getBitRate(true);
  au["in_buffer_filled"] = audio.inBufferFilled();
  au["in_buffer_free"] = audio.inBufferFree();

  JsonObject st = doc["app_state"].to<JsonObject>();
  st["playing_flag"] = playing;
  st["mode"] = mode;
  st["stream_url"] = lastUrl;
  st["stream_station"] = streamStation;
  st["stream_title"] = streamTitle;
  st["a2dp_sink_capable"] = retroA2dpSupportsHardware();
  st["a2dp_connected"] = retroA2dpIsConnected();

  JsonObject sys = doc["system"].to<JsonObject>();
  sys["free_heap"] = ESP.getFreeHeap();
  sys["min_free_heap"] = ESP.getMinFreeHeap();
  sys["uptime_ms"] = millis();
  sys["chip"] = chipModelString();
  {
    const char* bp = boardProfileString();
    if (bp != nullptr && bp[0] != '\0') {
      sys["board_profile"] = bp;
    }
  }

  JsonArray hints = doc["how_to_read"].to<JsonArray>();
  hints.add(
      "Se wifi.connected e' true ma audio_engine.running e' false a lungo: lo stream non arriva o l'URL non e' "
      "decodificabile (controlla Serial [Audio]).");
  hints.add("Se in_buffer_filled resta 0: nessun byte dal server (URL, HTTPS obbligatorio, firewall).");
  hints.add("Se running true e sample_rate_hz > 0 ma non senti nulla: verifica fili I2S e SCK del DAC a GND.");

  JsonArray wire = doc["wiring_checklist"].to<JsonArray>();
  {
    char line[140];
    snprintf(line, sizeof(line),
             "GPIO%d -> BCK, GPIO%d -> LRCK/LCK, GPIO%d -> DIN (dati ESP -> DAC)",
             static_cast<int>(I2S_BCLK), static_cast<int>(I2S_LRC), static_cast<int>(I2S_DOUT));
    wire.add(line);
  }
  wire.add("GND -> GND; 3V3 -> VIN sul modulo viola");
  wire.add("SCK del PCM5102 -> GND (senza MCLK da ESP)");

  String out;
  serializeJson(doc, out);
  server.send(200, "application/json", out);
}

// Risposta minima: utile da PC (curl, script) per verificare raggiungibilita' HTTP.
void handlePing() {
  JsonDocument doc;
  doc["ok"] = true;
  doc["ip"] = WiFi.localIP().toString();
  doc["name"] = deviceName;
  doc["mac"] = WiFi.macAddress();
  doc["rssi"] = (WiFi.status() == WL_CONNECTED) ? WiFi.RSSI() : 0;
  String out;
  serializeJson(doc, out);
  server.send(200, "application/json", out);
}

// Pagina leggera: controlli da browser sul PC (stessa LAN). I2S non e' un GPIO "toggle":
// la verifica cablaggio e' stream + /diag + uscita analogica sul DAC.
void handleConsole() {
  static const char kPage[] PROGMEM = R"CONSOLE(
<!DOCTYPE html><html lang="it"><head>
<meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>RetroWave — console LAN</title>
<style>
body{font-family:system-ui,Segoe UI,sans-serif;max-width:640px;margin:24px;line-height:1.45;background:#111;color:#eee}
a{color:#7dd3fc} code{background:#222;padding:2px 6px;border-radius:4px}
h1{font-size:1.25rem} .box{background:#1a1a1a;border:1px solid #333;border-radius:12px;padding:16px;margin:12px 0}
input[type=text]{width:100%;max-width:100%;box-sizing:border-box;padding:8px;margin:8px 0;background:#222;border:1px solid #444;color:#fff;border-radius:8px}
button,.btn{display:inline-block;padding:10px 16px;margin:6px 6px 0 0;border-radius:8px;border:none;cursor:pointer;font-weight:600;background:#0ea5e9;color:#111;text-decoration:none}
.btn2{background:#334155;color:#e2e8f0}
</style></head><body>
<h1>RetroWave — prova da PC</h1>
<p>Stesso WiFi del computer. Se il telefono non trova il dispositivo (mDNS), usa comunque questa pagina con l'<strong>IP</strong> stampato su Serial.</p>
<div class="box">
<p><strong>Link rapidi</strong></p>
<p><a href="/ping">/ping</a> · <a href="/status">/status</a> · <a href="/diag">/diag</a></p>
</div>
<div class="box">
<p><strong>Riproduci stream</strong> (meglio URL <code>MP3</code> HTTP diretto, no solo HLS senza PSRAM)</p>
<form action="/stream" method="get">
<input type="text" name="url" value="http://ice1.somafm.com/groovesalad-128-mp3" autocomplete="off">
<button type="submit">Play</button>
</form>
<p><a class="btn btn2" href="/stop">Stop</a></p>
</div>
<div class="box">
<p><strong>Volume</strong> (0–21)</p>
<p><a href="/volume?v=18">18</a> · <a href="/volume?v=21">max 21</a></p>
</div>
<div class="box">
<p><strong>I2S nel firmware</strong>: i GPIO attivi sono in <a href="/diag"><code>/diag</code></a> sotto <code>i2s_expected</code> (campi <code>bclk_gpio</code>, <code>lrck_ws_gpio</code>, <code>dout_from_esp_gpio</code>). Su ESP32-WROOM-32U in questo progetto BCLK/LRCK/DOUT = 16/5/17; su ESP32-S3 spesso 17/16/18. Se <code>/diag</code> mostra stream attivo e sample rate ma non senti nulla: DAC, <code>SCK→GND</code>, jack AUX.</p>
</div>
</body></html>
)CONSOLE";
  server.send_P(200, "text/html; charset=utf-8", kPage);
}

void handleStream() {
  if (!server.hasArg("url")) {
    server.send(400, "text/plain", "MISSING_URL");
    return;
  }
  retroA2dpLeaveBluetooth();
  lastUrl = server.arg("url");
  playing = true;
  mode = "radio";
  saveState();
  startRadioStream(lastUrl.c_str());
  server.send(200, "text/plain", "OK");
}

void handleStop() {
  playing = false;
  mode = "idle";
  audio.stopSong();
  retroA2dpLeaveBluetooth();
  saveState();
  server.send(200, "text/plain", "STOPPED");
}

void handleVolume() {
  if (!server.hasArg("v")) {
    server.send(400, "text/plain", "MISSING_V");
    return;
  }
  volumeLevel = constrain(server.arg("v").toInt(), 0, 21);
  saveState();
  audio.setVolume(static_cast<uint8_t>(volumeLevel));
  retroA2dpSetVolume(volumeLevel);
  server.send(200, "text/plain", "OK");
}

void handleBluetooth() {
  if (mode == "bluetooth") {
    retroA2dpLeaveBluetooth();
    delay(150);
    mode = "radio";
    if (lastUrl.length() > 0) {
      playing = true;
      startRadioStream(lastUrl.c_str());
    } else {
      playing = false;
      mode = "idle";
    }
    saveState();
    server.send(200, "text/plain", "RADIO");
    return;
  }
  // Passaggio a modalità bluetooth: richiede stack Classic (non disponibile su ESP32-S3).
  if (!retroA2dpSupportsHardware()) {
    server.send(200, "text/plain", "BT_NOT_SUPPORTED");
    return;
  }
  audio.stopSong();
  playing = false;
  mode = "bluetooth";
  delay(150);
  retroA2dpEnterBluetooth(deviceName.c_str(), volumeLevel);
  saveState();
  server.send(200, "text/plain", "BT_ON");
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
  // Il nome Bluetooth A2DP e' quello passato a start(): riavvio sink se attivo.
  if (mode == "bluetooth" && retroA2dpSupportsHardware()) {
    retroA2dpLeaveBluetooth();
    delay(150);
    retroA2dpEnterBluetooth(deviceName.c_str(), volumeLevel);
  }
  server.send(200, "text/plain", "OK");
}

// Cancella credenziali WiFi e riavvia → l'ESP torna in AP RetroWave-XXXX-Setup (solo rete locale).
void handleWifiReset() {
  Serial.println(F("HTTP /wifi_reset: cancello WiFi e riavvio tra breve"));
  audio.stopSong();
  retroA2dpLeaveBluetooth();
  server.send(200, "application/json", "{\"ok\":true,\"next\":\"ap_setup\"}");
  server.client().stop();
  delay(400);
  WiFiManager wm;
  wm.resetSettings();
  delay(200);
  ESP.restart();
}

void setup() {
  Serial.begin(115200);
  delay(200);
  // Prima riga utile: se non la vedi, la COM non e' quella dell'UART dell'ESP (o cavo solo carica).
  Serial.println();
  Serial.println(F("RetroWave: firmware avviato (115200). Premi RST se non vedi altro."));
  Serial.flush();
  delay(300);
  loadState();

  // Hotspot di configurazione se non ci sono credenziali o la rete non è raggiungibile.
  // Nome rete visibile dal telefono: RetroWave-XXXX-Setup (XXXX = ultimi byte MAC).
  WiFi.mode(WIFI_STA);

  WiFiManager wm;
  // Tieni premuto BOOT (GPIO0) all’accensione per cancellare il WiFi salvato e forzare di nuovo il portale.
  pinMode(0, INPUT_PULLUP);
  delay(300);
  if (digitalRead(0) == LOW) {
    Serial.println(F("BOOT premuto: elimino credenziali WiFi salvate."));
    wm.resetSettings();
    delay(400);
  }

  wm.setDebugOutput(true);
  wm.setTitle("RetroWave WiFi");
  wm.setCountry("IT");
  wm.setCaptivePortalEnable(true);
  // Più tentativi prima di aprire il portale se la rete salvata non risponde / password errata.
  wm.setConnectTimeout(45);
  wm.setConnectRetries(5);
  // IP noti: il telefono spesso NON apre da solo il captive portal — apri il browser su http://192.168.4.1
  wm.setAPStaticIPConfig(IPAddress(192, 168, 4, 1), IPAddress(192, 168, 4, 1), IPAddress(255, 255, 255, 0));
  wm.setConfigPortalTimeout(0); // 0 = nessun timeout (portale resta attivo)
  wm.setWiFiAutoReconnect(true);

  WiFi.setSleep(false);
  WiFi.persistent(true);

  const String apName = String("RetroWave-") + macSuffix() + "-Setup";
  Serial.println(F("========================================"));
  Serial.printf("WiFi: connessione salvata o AP \"%s\"\n", apName.c_str());
  Serial.println(F("Se compare l'AP ma non si apre la pagina:"));
  Serial.println(F("  1) Connettiti alla rete RetroWave-...-Setup (senza password)"));
  Serial.println(F("  2) Apri Chrome e vai a: http://192.168.4.1"));
  Serial.println(F("  3) Disattiva 'DNS privato' / VPN sul telefono se il sito non carica"));
  Serial.println(F("Per rifare setup: tieni BOOT premuto, premi RST, rilascia RST, poi rilascia BOOT."));
  Serial.println(F("========================================"));
  if (!wm.autoConnect(apName.c_str())) {
    Serial.println("WiFi: configurazione annullata, riavvio tra 3s");
    delay(3000);
    ESP.restart();
  }
  Serial.print("WiFi: connesso, IP LAN: ");
  Serial.println(WiFi.localIP());

  audio.setPinout(I2S_BCLK, I2S_LRC, I2S_DOUT);
  audio.setVolume(static_cast<uint8_t>(volumeLevel));
  Serial.printf("I2S: BCLK=%d LRC=%d DOUT=%d (verifica cablaggio DAC)\n", I2S_BCLK, I2S_LRC, I2S_DOUT);
  if (retroA2dpSupportsHardware()) {
    Serial.println(F("A2DP: hardware supportato — in mode bluetooth il telefono puo' accoppiarsi come altoparlante."));
  } else {
    Serial.println(F("A2DP: non disponibile su questo chip (es. ESP32-S3 = solo BLE). /bluetooth imposta solo lo stato."));
  }
  Serial.println(F("Test da PC: apri nel browser http://<IP>/  (console) oppure /ping /status /diag"));
  Serial.println(F("Monitor seriale: 115200 baud (CP2104/CH343, numero COM da Gestione dispositivi)."));

  server.on("/", HTTP_GET, handleConsole);
  server.on("/console", HTTP_GET, handleConsole);
  server.on("/ping", HTTP_GET, handlePing);
  server.on("/status", HTTP_GET, handleStatus);
  server.on("/diag", HTTP_GET, handleDiag);
  server.on("/stream", HTTP_GET, handleStream);
  server.on("/stop", HTTP_GET, handleStop);
  server.on("/volume", HTTP_GET, handleVolume);
  server.on("/bluetooth", HTTP_GET, handleBluetooth);
  server.on("/rename", HTTP_POST, handleRename);
  server.on("/wifi_reset", HTTP_GET, handleWifiReset);
  server.on("/wifi_reset", HTTP_POST, handleWifiReset);
  server.begin();

  if (WiFi.status() == WL_CONNECTED) {
    MDNS.begin(deviceName.c_str());
    MDNS.addService("retrowave", "tcp", 80);
  }

  if (WiFi.status() == WL_CONNECTED) {
    if (mode == "bluetooth" && retroA2dpSupportsHardware()) {
      playing = false;
      retroA2dpEnterBluetooth(deviceName.c_str(), volumeLevel);
    } else if (lastUrl.length() > 0) {
      mode = "radio";
      playing = true;
      startRadioStream(lastUrl.c_str());
    }
  }
}

void loop() {
  audio.loop();
  server.handleClient();
}
