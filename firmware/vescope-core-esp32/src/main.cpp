#include <Arduino.h>
#include <ArduinoJson.h>
#include <PubSubClient.h>
#include <WebServer.h>
#include <WiFi.h>
#include <time.h>
#include <sys/time.h>

#include "ble_service.h"
#include "board_ui.h"
#include "config.h"
#include "field_connectivity.h"
#include "pzem_modbus.h"

#if __has_include("secrets.h")
#include "secrets.h"
#else
#include "secrets.example.h"
#endif

using namespace vescope;

HardwareSerial pzem_uart(1);
PzemModbus pzem(pzem_uart, PZEM_ADDRESS, PZEM_TIMEOUT_MS);
WiFiClient wifi_client;
PubSubClient mqtt(wifi_client);
WebServer web(80);
BleService ble;
FieldConnectivity connectivity;
BoardUi board_ui;

PzemMeasurement last_measurement;
bool have_measurement = false;
uint32_t sequence_number = 0;
uint32_t last_measurement_ms = 0;
uint32_t last_telemetry_ms = 0;
uint32_t last_status_ms = 0;
uint32_t last_diagnostics_ms = 0;
uint32_t last_mqtt_attempt_ms = 0;
uint32_t mqtt_retry_ms = MQTT_RETRY_MIN_MS;

struct SessionTracker {
  bool active = false;
  String id;
  String started_at;
  uint32_t started_ms = 0;
  float start_energy_total_wh = 0.0F;
  uint32_t samples = 0;
  double sum_power_w = 0.0;
  double sum_pf = 0.0;
  float max_power_w = 0.0F;
  float max_current_a = 0.0F;
  float min_voltage_v = 10000.0F;
  float max_voltage_v = 0.0F;
  float min_pf = 1.0F;
  float min_frequency_hz = 1000.0F;
  float max_frequency_hz = 0.0F;
  uint8_t start_confirm = 0;
  uint8_t stop_confirm = 0;
} session;

String topic(const char* suffix) {
  return String("vescope/") + DEVICE_ID + "/" + suffix;
}

void logLine(const String& message) {
  Serial.println(String("[VE-SCOPE] ") + message);
}

void seedClockFromBuild() {
  if (time(nullptr) > 1700000000) return;

  static const char* months = "JanFebMarAprMayJunJulAugSepOctNovDec";
  char month_name[4] = {};
  int day = 1;
  int year = 2026;
  int hour = 0;
  int minute = 0;
  int second = 0;
  sscanf(__DATE__, "%3s %d %d", month_name, &day, &year);
  sscanf(__TIME__, "%d:%d:%d", &hour, &minute, &second);

  int month = 0;
  const char* found = strstr(months, month_name);
  if (found) month = static_cast<int>((found - months) / 3);

  setenv("TZ", "UTC0", 1);
  tzset();
  tm build_tm{};
  build_tm.tm_year = year - 1900;
  build_tm.tm_mon = month;
  build_tm.tm_mday = day;
  build_tm.tm_hour = hour;
  build_tm.tm_min = minute;
  build_tm.tm_sec = second;
  const time_t build_epoch = mktime(&build_tm);
  timeval tv{build_epoch, 0};
  settimeofday(&tv, nullptr);
}

String isoNow() {
  time_t now = time(nullptr);
  tm utc{};
  gmtime_r(&now, &utc);
  char buffer[25];
  strftime(buffer, sizeof(buffer), "%Y-%m-%dT%H:%M:%SZ", &utc);
  return String(buffer);
}

String makeSessionId() {
  time_t now = time(nullptr);
  tm utc{};
  gmtime_r(&now, &utc);
  char buffer[40];
  strftime(buffer, sizeof(buffer), "VE01-%Y%m%d-%H%M%S", &utc);
  return String(buffer);
}

bool measurementPhysicallyValid(const PzemMeasurement& m) {
  return m.valid &&
         m.voltage_v >= VALID_VOLTAGE_MIN_V && m.voltage_v <= VALID_VOLTAGE_MAX_V &&
         m.current_a >= 0.0F && m.current_a <= VALID_CURRENT_MAX_A &&
         m.active_power_w >= 0.0F &&
         m.frequency_hz >= VALID_FREQUENCY_MIN_HZ && m.frequency_hz <= VALID_FREQUENCY_MAX_HZ &&
         m.power_factor >= 0.0F && m.power_factor <= 1.0F;
}

void fillTelemetry(JsonDocument& doc, const PzemMeasurement& m) {
  const float apparent = m.voltage_v * m.current_a;
  const float q_squared = max(0.0F, apparent * apparent - m.active_power_w * m.active_power_w);

  doc["schema"] = 1;
  doc["device_id"] = DEVICE_ID;
  doc["timestamp"] = isoNow();
  doc["sequence"] = sequence_number;
  doc["quality"] = "GOOD";
  doc["voltage_v"] = m.voltage_v;
  doc["current_a"] = m.current_a;
  doc["active_power_w"] = m.active_power_w;
  doc["apparent_power_va"] = apparent;
  doc["non_active_power_var_est"] = sqrtf(q_squared);
  doc["power_factor"] = m.power_factor;
  doc["frequency_hz"] = m.frequency_hz;
  doc["energy_total_wh"] = m.energy_total_wh;
}

String jsonString(JsonDocument& doc) {
  String output;
  serializeJson(doc, output);
  return output;
}

bool publishJson(const String& mqtt_topic, JsonDocument& doc, bool retained = false) {
  if (!mqtt.connected()) return false;
  const String payload = jsonString(doc);
  return mqtt.publish(mqtt_topic.c_str(), payload.c_str(), retained);
}

String stationState() {
  return session.active ? "CHARGING" : "IDLE";
}

void publishStatus() {
  JsonDocument doc;
  doc["schema"] = 1;
  doc["device_id"] = DEVICE_ID;
  doc["timestamp"] = isoNow();
  doc["online"] = true;
  doc["state"] = stationState();
  doc["firmware"] = FIRMWARE_VERSION;
  doc["pzem_online"] = have_measurement && (millis() - last_measurement_ms < 3000);
  doc["transport_wifi"] = connectivity.staConnected();
  doc["transport_ap"] = connectivity.apActive();
  doc["transport_ble"] = ble.connected();
  const String payload = jsonString(doc);
  ble.updateStatus(payload);
  if (mqtt.connected()) mqtt.publish(topic("status").c_str(), payload.c_str(), true);
}

void publishDiagnostics() {
  JsonDocument doc;
  doc["schema"] = 1;
  doc["device_id"] = DEVICE_ID;
  doc["timestamp"] = isoNow();
  doc["firmware"] = FIRMWARE_VERSION;
  doc["uptime_s"] = millis() / 1000;
  doc["free_heap_bytes"] = ESP.getFreeHeap();
  doc["wifi_connected"] = WiFi.status() == WL_CONNECTED;
  doc["wifi_rssi_dbm"] = WiFi.status() == WL_CONNECTED ? WiFi.RSSI() : -127;
  doc["wifi_ip"] = WiFi.status() == WL_CONNECTED ? WiFi.localIP().toString() : "";
  doc["ap_ip"] = connectivity.apIp();
  doc["fallback_ap_active"] = connectivity.apActive();
  doc["mdns"] = connectivity.mdnsHost() + ".local";
  doc["mqtt_connected"] = mqtt.connected();
  doc["ble_connected"] = ble.connected();
  doc["pzem_reads_ok"] = pzem.successCount();
  doc["pzem_errors"] = pzem.errorCount();
  doc["pzem_last_error"] = pzem.lastError();
  publishJson(topic("diagnostics"), doc, false);
}

void startSession(const PzemMeasurement& m) {
  session.active = true;
  session.id = makeSessionId();
  session.started_at = isoNow();
  session.started_ms = millis();
  session.start_energy_total_wh = m.energy_total_wh;
  session.samples = 0;
  session.sum_power_w = 0.0;
  session.sum_pf = 0.0;
  session.max_power_w = 0.0F;
  session.max_current_a = 0.0F;
  session.min_voltage_v = 10000.0F;
  session.max_voltage_v = 0.0F;
  session.min_pf = 1.0F;
  session.min_frequency_hz = 1000.0F;
  session.max_frequency_hz = 0.0F;
  session.start_confirm = 0;
  session.stop_confirm = 0;
  logLine(String("Session started: ") + session.id);
  publishStatus();
}

float sessionEnergyWh(const PzemMeasurement& m) {
  const float delta = m.energy_total_wh - session.start_energy_total_wh;
  return max(0.0F, delta);
}

void updateSessionStats(const PzemMeasurement& m) {
  if (!session.active) return;
  ++session.samples;
  session.sum_power_w += m.active_power_w;
  session.sum_pf += m.power_factor;
  session.max_power_w = max(session.max_power_w, m.active_power_w);
  session.max_current_a = max(session.max_current_a, m.current_a);
  session.min_voltage_v = min(session.min_voltage_v, m.voltage_v);
  session.max_voltage_v = max(session.max_voltage_v, m.voltage_v);
  session.min_pf = min(session.min_pf, m.power_factor);
  session.min_frequency_hz = min(session.min_frequency_hz, m.frequency_hz);
  session.max_frequency_hz = max(session.max_frequency_hz, m.frequency_hz);
}

void fillSession(JsonDocument& doc, const PzemMeasurement& m, bool summary) {
  const uint32_t duration_s = (millis() - session.started_ms) / 1000;
  const double avg_power = session.samples ? session.sum_power_w / session.samples : 0.0;
  const double avg_pf = session.samples ? session.sum_pf / session.samples : 0.0;

  doc["schema"] = 1;
  doc["device_id"] = DEVICE_ID;
  doc["session_id"] = session.id;
  doc["state"] = summary ? "COMPLETE" : "CHARGING";
  doc["started_at"] = session.started_at;
  if (summary) doc["ended_at"] = isoNow();
  doc["duration_s"] = duration_s;
  doc["energy_wh"] = sessionEnergyWh(m);
  doc["average_power_w"] = avg_power;
  doc["max_power_w"] = session.max_power_w;
  doc["max_current_a"] = session.max_current_a;
  doc["average_power_factor"] = avg_pf;
  if (summary) {
    doc["min_voltage_v"] = session.min_voltage_v;
    doc["max_voltage_v"] = session.max_voltage_v;
    doc["min_power_factor"] = session.min_pf;
    doc["min_frequency_hz"] = session.min_frequency_hz;
    doc["max_frequency_hz"] = session.max_frequency_hz;
    doc["interruptions"] = 0;
    doc["end_reason"] = "CURRENT_BELOW_THRESHOLD";
  }
}

void publishSessionLive(const PzemMeasurement& m) {
  if (!session.active) return;
  JsonDocument doc;
  fillSession(doc, m, false);
  publishJson(topic("session/live"), doc, false);
}

void finishSession(const PzemMeasurement& m) {
  if (!session.active) return;
  JsonDocument doc;
  fillSession(doc, m, true);
  publishJson(topic("session/summary"), doc, false);
  logLine(String("Session completed: ") + session.id);
  session.active = false;
  session.stop_confirm = 0;
  publishStatus();
}

void processSession(const PzemMeasurement& m) {
  if (!session.active) {
    const bool charging = m.active_power_w >= SESSION_START_POWER_W && m.current_a >= SESSION_START_CURRENT_A;
    session.start_confirm = charging ? min<uint8_t>(255, session.start_confirm + 1) : 0;
    if (session.start_confirm >= SESSION_START_CONFIRM_SAMPLES) startSession(m);
    return;
  }

  updateSessionStats(m);
  const bool stopped = m.active_power_w <= SESSION_STOP_POWER_W && m.current_a <= SESSION_STOP_CURRENT_A;
  session.stop_confirm = stopped ? min<uint8_t>(255, session.stop_confirm + 1) : 0;
  if (session.stop_confirm >= SESSION_STOP_CONFIRM_SAMPLES) finishSession(m);
}

void publishTelemetry(const PzemMeasurement& m) {
  ++sequence_number;
  JsonDocument doc;
  fillTelemetry(doc, m);
  const String payload = jsonString(doc);

  // USB série : une trame JSON par ligne, directement exploitable par un PC.
  Serial.println(payload);

  ble.updateTelemetry(payload);
  if (mqtt.connected()) {
    mqtt.publish(topic("telemetry/ac").c_str(), payload.c_str(), false);
  }
}

void connectMqttIfNeeded() {
  if (mqtt.connected() || WiFi.status() != WL_CONNECTED) return;
  if (millis() - last_mqtt_attempt_ms < mqtt_retry_ms) return;
  last_mqtt_attempt_ms = millis();

  JsonDocument offline_doc;
  offline_doc["schema"] = 1;
  offline_doc["device_id"] = DEVICE_ID;
  offline_doc["online"] = false;
  offline_doc["state"] = "OFFLINE";
  const String offline_payload = jsonString(offline_doc);
  const String status_topic = topic("status");
  const String client_id = String("vescope-core-") + DEVICE_ID;

  const char* username = strlen(VESCOPE_MQTT_USER) ? VESCOPE_MQTT_USER : nullptr;
  const char* password = strlen(VESCOPE_MQTT_PASSWORD) ? VESCOPE_MQTT_PASSWORD : nullptr;

  logLine(String("MQTT connecting to ") + VESCOPE_MQTT_HOST + ":" + VESCOPE_MQTT_PORT);
  const bool connected = mqtt.connect(
      client_id.c_str(), username, password,
      status_topic.c_str(), 1, true, offline_payload.c_str());

  if (connected) {
    mqtt_retry_ms = MQTT_RETRY_MIN_MS;
    logLine("MQTT connected");
    publishStatus();
    publishDiagnostics();
  } else {
    mqtt_retry_ms = min<uint32_t>(MQTT_RETRY_MAX_MS, mqtt_retry_ms * 2);
    logLine(String("MQTT failed rc=") + mqtt.state());
  }
}

String statusJson() {
  JsonDocument doc;
  doc["schema"] = 1;
  doc["device_id"] = DEVICE_ID;
  doc["firmware"] = FIRMWARE_VERSION;
  doc["state"] = stationState();
  doc["wifi_connected"] = WiFi.status() == WL_CONNECTED;
  doc["wifi_ip"] = connectivity.staIp();
  doc["ap_active"] = connectivity.apActive();
  doc["ap_ip"] = connectivity.apIp();
  doc["mdns"] = connectivity.mdnsHost() + ".local";
  doc["mqtt_connected"] = mqtt.connected();
  doc["ble_connected"] = ble.connected();
  doc["pzem_online"] = have_measurement && (millis() - last_measurement_ms < 3000);
  doc["uptime_s"] = millis() / 1000;
  return jsonString(doc);
}

String telemetryJson() {
  JsonDocument doc;
  if (!have_measurement) {
    doc["schema"] = 1;
    doc["device_id"] = DEVICE_ID;
    doc["quality"] = "UNAVAILABLE";
    doc["error"] = pzem.lastError();
  } else {
    fillTelemetry(doc, last_measurement);
  }
  return jsonString(doc);
}

void configureWebServer() {
  web.on("/api/status", HTTP_GET, []() {
    web.send(200, "application/json; charset=utf-8", statusJson());
  });
  web.on("/api/telemetry", HTTP_GET, []() {
    web.send(200, "application/json; charset=utf-8", telemetryJson());
  });
  web.on("/api/session", HTTP_GET, []() {
    JsonDocument doc;
    doc["schema"] = 1;
    doc["device_id"] = DEVICE_ID;
    doc["active"] = session.active;
    doc["session_id"] = session.id;
    doc["state"] = stationState();
    if (session.active && have_measurement) fillSession(doc, last_measurement, false);
    web.send(200, "application/json; charset=utf-8", jsonString(doc));
  });
  web.on("/", HTTP_GET, []() {
    const char page[] PROGMEM = R"HTML(
<!doctype html><html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>VE-SCOPE Core</title><style>body{font-family:system-ui;background:#071321;color:#e9f1fa;margin:0;padding:24px}main{max-width:760px;margin:auto}.card{background:#0d1d2f;border:1px solid #243b55;border-radius:16px;padding:20px;margin:12px 0}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:12px}.v{font-size:1.7rem;font-weight:700}small{color:#8fa7bf}code{color:#7fc4ff}</style></head>
<body><main><h1>VE-SCOPE Core</h1><p>Interface locale terrain ESP32 / PZEM-004T.</p><div id="status" class="card">Chargement...</div><div id="values" class="grid"></div><div class="card"><small>Accès local</small><p><code>/api/status</code><br><code>/api/telemetry</code><br><code>/api/session</code><br><code>/api/connectivity</code><br><a href="/update" style="color:#7fc4ff">Mise à jour OTA</a></p></div></main>
<script>async function r(){try{let s=await (await fetch('/api/status')).json(),t=await (await fetch('/api/telemetry')).json();document.getElementById('status').innerHTML='<b>'+s.device_id+'</b> · '+s.state+' · MQTT '+(s.mqtt_connected?'OK':'OFF')+' · PZEM '+(s.pzem_online?'OK':'OFF');let a=[['Tension',t.voltage_v,'V'],['Courant',t.current_a,'A'],['Puissance',t.active_power_w,'W'],['PF',t.power_factor,''],['Fréquence',t.frequency_hz,'Hz'],['Énergie',t.energy_total_wh,'Wh']];document.getElementById('values').innerHTML=a.map(x=>'<div class="card"><small>'+x[0]+'</small><div class="v">'+(x[1]??'—')+' '+x[2]+'</div></div>').join('')}catch(e){}}setInterval(r,1000);r()</script></body></html>)HTML";
    web.send(200, "text/html; charset=utf-8", page);
  });
  web.begin();
}

void setup() {
  Serial.begin(115200);
  delay(500);
  logLine(String("Boot firmware ") + FIRMWARE_VERSION);
  board_ui.begin();
  board_ui.showBoot(FIRMWARE_VERSION);

  seedClockFromBuild();
  configTime(0, 0, "pool.ntp.org", "time.google.com");

  pzem.begin(PZEM_BAUD, PZEM_RX_PIN, PZEM_TX_PIN);

  ble.begin(DEVICE_ID, FIRMWARE_VERSION);
  connectivity.begin(web, DEVICE_ID);

  mqtt.setServer(VESCOPE_MQTT_HOST, VESCOPE_MQTT_PORT);
  mqtt.setKeepAlive(30);
  mqtt.setBufferSize(1536);

  configureWebServer();
  publishStatus();
}

void loop() {
  web.handleClient();
  connectivity.handle();
  connectMqttIfNeeded();
  if (mqtt.connected()) mqtt.loop();

  const uint32_t now = millis();
  if (now - last_telemetry_ms >= TELEMETRY_PERIOD_MS) {
    last_telemetry_ms = now;
    PzemMeasurement measurement;
    if (pzem.read(measurement) && measurementPhysicallyValid(measurement)) {
      last_measurement = measurement;
      have_measurement = true;
      last_measurement_ms = now;
      processSession(measurement);
      board_ui.showTelemetry(measurement, connectivity.staConnected(), mqtt.connected(), ble.connected(), session.active);
      publishTelemetry(measurement);
      if (session.active) publishSessionLive(measurement);
    } else {
      board_ui.showPzemOffline(connectivity.staConnected(), mqtt.connected(), ble.connected());
      logLine(String("PZEM read failed: ") + pzem.lastError());
    }
  }

  if (mqtt.connected() && now - last_status_ms >= STATUS_PERIOD_MS) {
    last_status_ms = now;
    publishStatus();
  }
  if (mqtt.connected() && now - last_diagnostics_ms >= DIAGNOSTICS_PERIOD_MS) {
    last_diagnostics_ms = now;
    publishDiagnostics();
  }

  delay(2);
}
