#include <Arduino.h>
#include <ArduinoJson.h>
#include <Preferences.h>
#include <PubSubClient.h>
#include <WebServer.h>
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <time.h>
#include <sys/time.h>

#include "ble_service.h"
#include "board_ui.h"
#include "config.h"
#include "durable_store.h"
#include "field_connectivity.h"
#include "https_fallback.h"
#include "pzem_modbus.h"

#if __has_include("secrets.h")
#include "secrets.h"
#else
#include "secrets.example.h"
#endif

#if __has_include("mqtt_ca.h")
#include "mqtt_ca.h"
#else
#include "mqtt_ca.example.h"
#endif

using namespace vescope;

HardwareSerial pzem_uart(1);
PzemModbus pzem(pzem_uart, PZEM_ADDRESS, PZEM_TIMEOUT_MS);
#if VESCOPE_MQTT_TLS
WiFiClientSecure wifi_client;
#else
WiFiClient wifi_client;
#endif
PubSubClient mqtt(wifi_client);
WebServer web(80);
BleService ble;
FieldConnectivity connectivity;
HttpsFallback https_fallback;
DurableStore durable_store;
BoardUi board_ui;
Preferences session_prefs;

PzemMeasurement last_measurement;
bool have_measurement = false;
uint32_t sequence_number = 0;
uint32_t last_measurement_ms = 0;
uint32_t last_telemetry_ms = 0;
uint32_t last_durable_telemetry_ms = 0;
uint32_t last_durable_flush_ms = 0;
uint32_t last_session_ms = 0;
uint32_t last_status_ms = 0;
uint32_t last_diagnostics_ms = 0;
uint32_t last_mqtt_attempt_ms = 0;
uint32_t mqtt_retry_ms = MQTT_RETRY_MIN_MS;
uint32_t last_pzem_error_log_ms = 0;
uint32_t pzem_consecutive_errors = 0;
String last_pzem_logged_error;
bool durable_queue_error = false;

struct SessionTracker {
  bool active = false;
  String id;
  String started_at;
  time_t started_epoch = 0;
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
  bool restored_after_reboot = false;
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

String isoFromEpoch(time_t epoch) {
  tm utc{};
  gmtime_r(&epoch, &utc);
  char buffer[25];
  strftime(buffer, sizeof(buffer), "%Y-%m-%dT%H:%M:%SZ", &utc);
  return String(buffer);
}

String isoNow() { return isoFromEpoch(time(nullptr)); }

String makeSessionIdFromEpoch(time_t epoch) {
  tm utc{};
  gmtime_r(&epoch, &utc);
  char buffer[40];
  strftime(buffer, sizeof(buffer), "VE01-%Y%m%d-%H%M%S", &utc);
  return String(buffer);
}

String makeSessionId() { return makeSessionIdFromEpoch(time(nullptr)); }

String telemetrySampleId(uint32_t boot_id, uint32_t sequence) {
  return String(DEVICE_ID) + ":" + String(boot_id) + ":" + String(sequence);
}

bool measurementPhysicallyValid(const PzemMeasurement& m) {
  return m.valid &&
         m.voltage_v >= VALID_VOLTAGE_MIN_V && m.voltage_v <= VALID_VOLTAGE_MAX_V &&
         m.current_a >= 0.0F && m.current_a <= VALID_CURRENT_MAX_A &&
         m.active_power_w >= 0.0F &&
         m.frequency_hz >= VALID_FREQUENCY_MIN_HZ && m.frequency_hz <= VALID_FREQUENCY_MAX_HZ &&
         m.power_factor >= 0.0F && m.power_factor <= 1.0F;
}

void addTelemetryFields(
    JsonDocument& doc,
    uint32_t boot_id,
    uint32_t sequence,
    time_t epoch,
    uint32_t session_epoch_s,
    float voltage_v,
    float current_a,
    float active_power_w,
    float power_factor,
    float frequency_hz,
    float energy_total_wh) {
  const float apparent = voltage_v * current_a;
  const float q_squared = max(0.0F, apparent * apparent - active_power_w * active_power_w);

  doc["schema"] = 1;
  doc["device_id"] = DEVICE_ID;
  doc["timestamp"] = isoFromEpoch(epoch);
  doc["boot_id"] = boot_id;
  doc["sequence"] = sequence;
  doc["sample_id"] = telemetrySampleId(boot_id, sequence);
  if (session_epoch_s != 0) {
    doc["session_id"] = makeSessionIdFromEpoch(static_cast<time_t>(session_epoch_s));
  }
  doc["quality"] = "GOOD";
  doc["voltage_v"] = voltage_v;
  doc["current_a"] = current_a;
  doc["active_power_w"] = active_power_w;
  doc["apparent_power_va"] = apparent;
  doc["non_active_power_var_est"] = sqrtf(q_squared);
  doc["power_factor"] = power_factor;
  doc["frequency_hz"] = frequency_hz;
  doc["energy_total_wh"] = energy_total_wh;
}

void fillTelemetry(JsonDocument& doc, const PzemMeasurement& m) {
  addTelemetryFields(
      doc,
      durable_store.bootId(),
      sequence_number,
      time(nullptr),
      session.active ? static_cast<uint32_t>(session.started_epoch) : 0,
      m.voltage_v,
      m.current_a,
      m.active_power_w,
      m.power_factor,
      m.frequency_hz,
      m.energy_total_wh);
}

void fillDurableTelemetry(JsonDocument& doc, const DurableTelemetry& m) {
  addTelemetryFields(
      doc,
      m.boot_id,
      m.sequence,
      static_cast<time_t>(m.epoch_s),
      m.session_epoch_s,
      m.voltage_v,
      m.current_a,
      m.active_power_w,
      m.power_factor,
      m.frequency_hz,
      m.energy_total_wh);
  doc["durable_replay"] = true;
}

String jsonString(JsonDocument& doc) {
  String output;
  serializeJson(doc, output);
  return output;
}

bool cloudNetworkReady() {
  if (connectivity.localMaintenanceActive()) return false;
  if (WiFi.status() != WL_CONNECTED) return false;
  if (connectivity.captivePortalEnabled() && !connectivity.captivePortalAuthenticated()) return false;
  return true;
}

const char* cloudTransport() {
  if (!cloudNetworkReady()) return "OFFLINE";
  if (mqtt.connected()) return "MQTT_TLS";
  if (https_fallback.recentlySuccessful()) return "HTTPS";
  return "OFFLINE";
}

bool publishCloudPayload(const char* channel, const String& payload, bool retained = false) {
  if (!cloudNetworkReady()) return false;

  if (mqtt.connected()) {
    if (mqtt.publish(topic(channel).c_str(), payload.c_str(), retained)) return true;
  }

  const bool ok = https_fallback.publish(DEVICE_ID, channel, payload);
  if (ok && !mqtt.connected()) {
    static uint32_t last_log_ms = 0;
    if (millis() - last_log_ms > 15000 || last_log_ms == 0) {
      logLine("Cloud transport: HTTPS 443 fallback");
      last_log_ms = millis();
    }
  }
  return ok;
}

bool publishCloudJson(const char* channel, JsonDocument& doc, bool retained = false) {
  return publishCloudPayload(channel, jsonString(doc), retained);
}

String stationState() {
  return session.active ? "CHARGING" : "IDLE";
}

void persistActiveSession() {
  session_prefs.putBool("active", session.active);
  if (!session.active) return;
  session_prefs.putString("id", session.id);
  session_prefs.putString("started", session.started_at);
  session_prefs.putULong64("epoch", static_cast<uint64_t>(session.started_epoch));
  session_prefs.putFloat("energy0", session.start_energy_total_wh);
}

void clearPersistedSession() {
  session_prefs.putBool("active", false);
  session_prefs.remove("id");
  session_prefs.remove("started");
  session_prefs.remove("epoch");
  session_prefs.remove("energy0");
}

void restorePersistedSession() {
  if (!session_prefs.getBool("active", false)) return;

  const String id = session_prefs.getString("id", "");
  const String started = session_prefs.getString("started", "");
  const uint64_t epoch = session_prefs.getULong64("epoch", 0);
  const float energy0 = session_prefs.getFloat("energy0", -1.0F);
  if (id.length() == 0 || started.length() == 0 || epoch < 1700000000ULL || energy0 < 0.0F) {
    clearPersistedSession();
    return;
  }

  session.active = true;
  session.id = id;
  session.started_at = started;
  session.started_epoch = static_cast<time_t>(epoch);
  session.started_ms = millis();
  session.start_energy_total_wh = energy0;
  session.restored_after_reboot = true;
  logLine(String("Session restored after reboot: ") + session.id);
}

void publishStatus() {
  JsonDocument doc;
  doc["schema"] = 1;
  doc["device_id"] = DEVICE_ID;
  doc["timestamp"] = isoNow();
  doc["online"] = true;
  doc["state"] = stationState();
  doc["firmware"] = FIRMWARE_VERSION;
  doc["pzem_online"] = have_measurement && (millis() - last_measurement_ms < PZEM_ONLINE_GRACE_MS);
  doc["transport_wifi"] = connectivity.staConnected();
  doc["transport_ap"] = connectivity.apActive();
  doc["transport_ble"] = ble.connected();
  doc["captive_portal_enabled"] = connectivity.captivePortalEnabled();
  doc["captive_portal_authenticated"] = connectivity.captivePortalAuthenticated();
  doc["cloud_transport"] = cloudTransport();
  doc["durable_pending"] = durable_store.pendingTelemetry();
  const String payload = jsonString(doc);
  ble.updateStatus(payload);
  publishCloudPayload("status", payload, true);
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
  doc["captive_portal_enabled"] = connectivity.captivePortalEnabled();
  doc["captive_portal_authenticated"] = connectivity.captivePortalAuthenticated();
  doc["captive_portal_last_http_code"] = connectivity.captivePortalLastHttpCode();
  doc["mqtt_connected"] = mqtt.connected();
  doc["https_fallback_ok"] = https_fallback.recentlySuccessful();
  doc["https_last_http_code"] = https_fallback.lastHttpCode();
  doc["https_publish_ok"] = https_fallback.successCount();
  doc["https_publish_errors"] = https_fallback.errorCount();
  doc["cloud_transport"] = cloudTransport();
  doc["ble_connected"] = ble.connected();
  doc["pzem_online"] = have_measurement && (millis() - last_measurement_ms < PZEM_ONLINE_GRACE_MS);
  doc["pzem_reads_ok"] = pzem.successCount();
  doc["pzem_errors"] = pzem.errorCount();
  doc["pzem_consecutive_errors"] = pzem_consecutive_errors;
  doc["pzem_last_error"] = pzem.lastError();
  doc["boot_id"] = durable_store.bootId();
  doc["durable_store_ok"] = durable_store.healthy();
  doc["durable_queue_error"] = durable_queue_error;
  doc["durable_pending_telemetry"] = durable_store.pendingTelemetry();
  doc["durable_pending_bytes"] = durable_store.telemetryBytes();
  doc["durable_pending_summaries"] = durable_store.pendingSessionSummaries();
  publishCloudJson("diagnostics", doc, false);
}

void startSession(const PzemMeasurement& m) {
  session.active = true;
  session.started_epoch = time(nullptr);
  session.id = makeSessionIdFromEpoch(session.started_epoch);
  session.started_at = isoFromEpoch(session.started_epoch);
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
  session.restored_after_reboot = false;
  persistActiveSession();
  logLine(String("Session started: ") + session.id);
  publishStatus();
}

float sessionEnergyWh(const PzemMeasurement& m) {
  const float delta = m.energy_total_wh - session.start_energy_total_wh;
  return max(0.0F, delta);
}

uint32_t sessionDurationS() {
  const time_t now = time(nullptr);
  if (session.started_epoch > 0 && now >= session.started_epoch) {
    return static_cast<uint32_t>(now - session.started_epoch);
  }
  return (millis() - session.started_ms) / 1000;
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
  const uint32_t duration_s = sessionDurationS();
  const float energy_wh = sessionEnergyWh(m);
  const double avg_power = duration_s > 0 ? (static_cast<double>(energy_wh) * 3600.0) / duration_s : 0.0;
  const double avg_pf = session.samples ? session.sum_pf / session.samples : 0.0;

  doc["schema"] = 1;
  doc["device_id"] = DEVICE_ID;
  doc["session_id"] = session.id;
  doc["state"] = summary ? "COMPLETE" : "CHARGING";
  doc["started_at"] = session.started_at;
  if (summary) doc["ended_at"] = isoNow();
  doc["duration_s"] = duration_s;
  doc["energy_wh"] = energy_wh;
  doc["average_power_w"] = avg_power;
  doc["max_power_w"] = session.max_power_w;
  doc["max_current_a"] = session.max_current_a;
  doc["average_power_factor"] = avg_pf;
  doc["resumed_after_reboot"] = session.restored_after_reboot;
  if (summary) {
    doc["min_voltage_v"] = session.min_voltage_v < 9999.0F ? session.min_voltage_v : m.voltage_v;
    doc["max_voltage_v"] = max(session.max_voltage_v, m.voltage_v);
    doc["min_power_factor"] = session.min_pf <= 1.0F ? session.min_pf : m.power_factor;
    doc["min_frequency_hz"] = session.min_frequency_hz < 999.0F ? session.min_frequency_hz : m.frequency_hz;
    doc["max_frequency_hz"] = max(session.max_frequency_hz, m.frequency_hz);
    doc["interruptions"] = session.restored_after_reboot ? 1 : 0;
    doc["end_reason"] = "CURRENT_BELOW_THRESHOLD";
  }
}

void publishSessionLive(const PzemMeasurement& m) {
  if (!session.active) return;
  JsonDocument doc;
  fillSession(doc, m, false);
  publishCloudJson("session/live", doc, false);
}

void finishSession(const PzemMeasurement& m) {
  if (!session.active) return;
  JsonDocument doc;
  fillSession(doc, m, true);
  const String summary = jsonString(doc);

  // Écrire d'abord le résumé sur flash. La session NVS n'est effacée qu'une
  // fois cette écriture confirmée, afin qu'un reset au mauvais moment ne fasse
  // jamais disparaître la fin d'une recharge.
  if (!durable_store.enqueueSessionSummary(summary)) {
    durable_queue_error = true;
    logLine("CRITICAL: impossible de journaliser le resume de session");
    return;
  }

  logLine(String("Session completed locally: ") + session.id + " (queued)");
  session.active = false;
  session.stop_confirm = 0;
  clearPersistedSession();
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

void queueDurableTelemetry(const PzemMeasurement& m) {
  DurableTelemetry record;
  record.boot_id = durable_store.bootId();
  record.sequence = sequence_number;
  record.epoch_s = static_cast<uint32_t>(time(nullptr));
  record.session_epoch_s = session.active ? static_cast<uint32_t>(session.started_epoch) : 0;
  record.voltage_v = m.voltage_v;
  record.current_a = m.current_a;
  record.active_power_w = m.active_power_w;
  record.power_factor = m.power_factor;
  record.frequency_hz = m.frequency_hz;
  record.energy_total_wh = m.energy_total_wh;

  if (!durable_store.enqueueTelemetry(record)) {
    durable_queue_error = true;
    logLine("CRITICAL: file durable pleine ou indisponible - intervention requise");
  }
}

void publishTelemetry(const PzemMeasurement& m) {
  ++sequence_number;
  JsonDocument doc;
  fillTelemetry(doc, m);
  const String payload = jsonString(doc);

  // USB série et BLE conservent la cadence locale de 1 Hz.
  Serial.println(payload);
  ble.updateTelemetry(payload);

  const uint32_t now = millis();
  if (last_durable_telemetry_ms == 0 || now - last_durable_telemetry_ms >= DURABLE_TELEMETRY_PERIOD_MS) {
    last_durable_telemetry_ms = now;
    queueDurableTelemetry(m);
  }
}

void flushDurableOutbox() {
  if (!durable_store.healthy() || !cloudNetworkReady()) return;
  const uint32_t now = millis();
  if (last_durable_flush_ms != 0 && now - last_durable_flush_ms < DURABLE_FLUSH_PERIOD_MS) return;
  last_durable_flush_ms = now;

  // Toujours vider la télémétrie dans l'ordre avant les résumés de session.
  // Le serveur peut ainsi reconstruire une recharge complète avant de recevoir
  // son événement de clôture.
  DurableTelemetry record;
  if (durable_store.peekTelemetry(record)) {
    JsonDocument doc;
    fillDurableTelemetry(doc, record);
    if (https_fallback.publish(DEVICE_ID, "telemetry/ac", jsonString(doc))) {
      durable_store.popTelemetry();
      durable_queue_error = false;
    }
    return;
  }

  String summary;
  if (durable_store.peekSessionSummary(summary)) {
    if (https_fallback.publish(DEVICE_ID, "session/summary", summary)) {
      durable_store.popSessionSummary();
      durable_queue_error = false;
      logLine("Durable session summary delivered");
    }
  }
}

void connectMqttIfNeeded() {
  if (mqtt.connected() || !cloudNetworkReady()) return;
#if VESCOPE_MQTT_TLS
  if (strlen(VESCOPE_MQTT_ROOT_CA) == 0) return;
#endif
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
    logLine("Cloud transport: MQTT TLS");
    publishStatus();
    publishDiagnostics();
  } else {
    if (connectivity.captivePortalEnabled()) {
      mqtt_retry_ms = MQTT_RETRY_CAPTIVE_MS;
    } else {
      mqtt_retry_ms = min<uint32_t>(MQTT_RETRY_MAX_MS, mqtt_retry_ms * 2);
    }
    logLine(String("MQTT failed rc=") + mqtt.state() + " - HTTPS fallback available");
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
  doc["captive_portal_enabled"] = connectivity.captivePortalEnabled();
  doc["captive_portal_authenticated"] = connectivity.captivePortalAuthenticated();
  doc["captive_portal_last_http_code"] = connectivity.captivePortalLastHttpCode();
  doc["mqtt_connected"] = mqtt.connected();
  doc["https_fallback_ok"] = https_fallback.recentlySuccessful();
  doc["https_last_http_code"] = https_fallback.lastHttpCode();
  doc["cloud_transport"] = cloudTransport();
  doc["ble_connected"] = ble.connected();
  doc["pzem_online"] = have_measurement && (millis() - last_measurement_ms < PZEM_ONLINE_GRACE_MS);
  doc["durable_store_ok"] = durable_store.healthy();
  doc["durable_pending_telemetry"] = durable_store.pendingTelemetry();
  doc["durable_pending_summaries"] = durable_store.pendingSessionSummaries();
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
    doc["restored_after_reboot"] = session.restored_after_reboot;
    if (session.active && have_measurement) fillSession(doc, last_measurement, false);
    web.send(200, "application/json; charset=utf-8", jsonString(doc));
  });
  web.on("/", HTTP_GET, []() {
    const char page[] PROGMEM = R"HTML(
<!doctype html><html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>VE-SCOPE Core</title><style>body{font-family:system-ui;background:#071321;color:#e9f1fa;margin:0;padding:24px}main{max-width:760px;margin:auto}.card{background:#0d1d2f;border:1px solid #243b55;border-radius:16px;padding:20px;margin:12px 0}.grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:12px}.v{font-size:1.7rem;font-weight:700}small{color:#8fa7bf}code{color:#7fc4ff}a{color:#7fc4ff}</style></head>
<body><main><h1>VE-SCOPE Core</h1><p>Interface locale terrain ESP32 / PZEM-004T.</p><div id="status" class="card">Chargement...</div><div id="values" class="grid"></div><div class="card"><small>Accès local</small><p><code>/api/status</code><br><code>/api/telemetry</code><br><code>/api/session</code><br><code>/api/connectivity</code><br><a href="/wifi">Configuration Wi-Fi / portail</a><br><a href="/update">Mise à jour OTA</a></p></div></main>
<script>async function r(){try{let s=await (await fetch('/api/status')).json(),t=await (await fetch('/api/telemetry')).json();document.getElementById('status').innerHTML='<b>'+s.device_id+'</b> · '+s.state+' · CLOUD '+s.cloud_transport+' · PZEM '+(s.pzem_online?'OK':'OFF')+' · QUEUE '+s.durable_pending_telemetry;let a=[['Tension',t.voltage_v,'V'],['Courant',t.current_a,'A'],['Puissance',t.active_power_w,'W'],['PF',t.power_factor,''],['Fréquence',t.frequency_hz,'Hz'],['Énergie',t.energy_total_wh,'Wh']];document.getElementById('values').innerHTML=a.map(x=>'<div class="card"><small>'+x[0]+'</small><div class="v">'+(x[1]??'—')+' '+x[2]+'</div></div>').join('')}catch(e){}}setInterval(r,1000);r()</script></body></html>)HTML";
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

  session_prefs.begin("vescope-session", false);
  restorePersistedSession();

  if (durable_store.begin()) {
    logLine(String("Durable store ready, boot_id=") + durable_store.bootId() +
            ", pending=" + durable_store.pendingTelemetry());
  } else {
    durable_queue_error = true;
    logLine("CRITICAL: durable store unavailable");
  }

  pzem.begin(PZEM_BAUD, PZEM_RX_PIN, PZEM_TX_PIN);

  ble.begin(DEVICE_ID, FIRMWARE_VERSION);
  connectivity.begin(web, DEVICE_ID);
  https_fallback.begin();

#if VESCOPE_MQTT_TLS
  if (strlen(VESCOPE_MQTT_ROOT_CA) > 0) {
    wifi_client.setCACert(VESCOPE_MQTT_ROOT_CA);
    wifi_client.setHandshakeTimeout(4);
    logLine("MQTT/HTTPS TLS: validation CA active");
  } else {
    logLine("CA TLS absente - transports cloud bloques");
  }
#endif
  mqtt.setServer(VESCOPE_MQTT_HOST, VESCOPE_MQTT_PORT);
  mqtt.setKeepAlive(30);
  mqtt.setSocketTimeout(4);
  mqtt.setBufferSize(1536);

  configureWebServer();
  publishStatus();
}

void loop() {
  web.handleClient();
  connectivity.handle();
  connectMqttIfNeeded();
  if (!connectivity.localMaintenanceActive() && mqtt.connected()) mqtt.loop();
  flushDurableOutbox();

  const uint32_t now = millis();
  if (now - last_telemetry_ms >= TELEMETRY_PERIOD_MS) {
    last_telemetry_ms = now;
    PzemMeasurement measurement;
    const bool pzem_read_ok = pzem.read(measurement);
    const bool pzem_valid = pzem_read_ok && measurementPhysicallyValid(measurement);

    if (pzem_valid) {
      if (pzem_consecutive_errors > 0) {
        logLine(String("PZEM recovered after ") + pzem_consecutive_errors + " failed reads");
      }
      pzem_consecutive_errors = 0;
      last_pzem_logged_error = "";

      last_measurement = measurement;
      have_measurement = true;
      last_measurement_ms = now;
      processSession(measurement);
      const bool cloud_ok = mqtt.connected() || https_fallback.recentlySuccessful();
      board_ui.showTelemetry(measurement, connectivity.staConnected(), cloud_ok, ble.connected(), session.active);
      publishTelemetry(measurement);
      if (session.active && now - last_session_ms >= SESSION_PERIOD_MS) {
        last_session_ms = now;
        publishSessionLive(measurement);
      }
    } else {
      const bool cloud_ok = mqtt.connected() || https_fallback.recentlySuccessful();
      board_ui.showPzemOffline(connectivity.staConnected(), cloud_ok, ble.connected());

      ++pzem_consecutive_errors;
      const String error = pzem_read_ok ? String("physical_range") : String(pzem.lastError());
      const bool error_changed = error != last_pzem_logged_error;
      const bool periodic_log =
          last_pzem_error_log_ms == 0 || now - last_pzem_error_log_ms >= PZEM_ERROR_LOG_PERIOD_MS;
      if (pzem_consecutive_errors == 1 || error_changed || periodic_log) {
        logLine(String("PZEM offline: ") + error +
                " (consecutive_errors=" + pzem_consecutive_errors + ")");
        last_pzem_logged_error = error;
        last_pzem_error_log_ms = now;
      }
    }
  }

  if (now - last_status_ms >= STATUS_PERIOD_MS) {
    last_status_ms = now;
    publishStatus();
  }
  if (now - last_diagnostics_ms >= DIAGNOSTICS_PERIOD_MS) {
    last_diagnostics_ms = now;
    publishDiagnostics();
  }

  delay(2);
}
