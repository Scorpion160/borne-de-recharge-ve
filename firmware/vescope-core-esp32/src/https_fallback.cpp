#include "https_fallback.h"

#include <ArduinoJson.h>
#include <HTTPClient.h>
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <cstring>
#include <sys/time.h>
#include <time.h>

#include "config.h"

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

#ifndef VESCOPE_HTTPS_FALLBACK_ENABLED
#define VESCOPE_HTTPS_FALLBACK_ENABLED 0
#endif
#ifndef VESCOPE_HTTPS_INGEST_HOST
#define VESCOPE_HTTPS_INGEST_HOST ""
#endif
#ifndef VESCOPE_HTTPS_INGEST_TOKEN
#define VESCOPE_HTTPS_INGEST_TOKEN ""
#endif

namespace vescope {

namespace {
constexpr uint32_t HTTPS_RETRY_MIN_MS = 1000;
constexpr uint32_t HTTPS_RETRY_MAX_MS = 15000;

bool setClockFromHttpDate(const String& value) {
  // Exemple RFC 7231 : Sun, 14 Sep 2026 12:27:14 GMT
  char weekday[4] = {};
  char month_name[4] = {};
  char zone[4] = {};
  int day = 0;
  int year = 0;
  int hour = 0;
  int minute = 0;
  int second = 0;

  const int parsed = sscanf(
      value.c_str(), "%3s, %d %3s %d %d:%d:%d %3s",
      weekday, &day, month_name, &year, &hour, &minute, &second, zone);
  if (parsed != 8) return false;

  static const char* months = "JanFebMarAprMayJunJulAugSepOctNovDec";
  const char* found = strstr(months, month_name);
  if (!found) return false;

  tm utc{};
  utc.tm_year = year - 1900;
  utc.tm_mon = static_cast<int>((found - months) / 3);
  utc.tm_mday = day;
  utc.tm_hour = hour;
  utc.tm_min = minute;
  utc.tm_sec = second;

  setenv("TZ", "UTC0", 1);
  tzset();
  const time_t epoch = mktime(&utc);
  if (epoch < 1700000000) return false;

  timeval tv{epoch, 0};
  settimeofday(&tv, nullptr);
  return true;
}

String payloadForHttpsTransport(const char* channel, const String& payload) {
  if (strcmp(channel, "status") != 0 && strcmp(channel, "diagnostics") != 0) {
    return payload;
  }

  JsonDocument doc;
  if (deserializeJson(doc, payload)) return payload;

  // Le message qui arrive au Hub via ce code a effectivement emprunte HTTPS,
  // meme s'il s'agit de la premiere publication reussie depuis le boot.
  doc["cloud_transport"] = "HTTPS";
  if (strcmp(channel, "diagnostics") == 0) {
    doc["https_transport_selected"] = true;
  }

  String output;
  serializeJson(doc, output);
  return output;
}
}  // namespace

void HttpsFallback::begin() {
  retry_ms_ = 0;
  last_attempt_ms_ = 0;
  last_success_ms_ = 0;
  last_telemetry_attempt_ms_ = 0;
  last_http_code_ = 0;
  success_count_ = 0;
  error_count_ = 0;
}

bool HttpsFallback::publish(const char* device_id, const char* channel, const String& payload) {
#if !VESCOPE_HTTPS_FALLBACK_ENABLED
  (void)device_id;
  (void)channel;
  (void)payload;
  return false;
#else
  if (WiFi.status() != WL_CONNECTED) return false;
  if (strlen(VESCOPE_HTTPS_INGEST_HOST) == 0 || strlen(VESCOPE_HTTPS_INGEST_TOKEN) == 0) return false;
  if (strlen(VESCOPE_MQTT_ROOT_CA) == 0) return false;

  const uint32_t now = millis();

  // En mode HTTPS, la mesure locale/BLE reste a 1 Hz mais la telemetrie cloud
  // est limitee a 1 envoi toutes les 5 s pour eviter de multiplier les
  // handshakes TLS sur les reseaux universitaires faibles ou instables.
  if (strcmp(channel, "telemetry/ac") == 0) {
    if (last_telemetry_attempt_ms_ != 0 &&
        now - last_telemetry_attempt_ms_ < HTTPS_TELEMETRY_PERIOD_MS) {
      return false;
    }
    last_telemetry_attempt_ms_ = now;
  }

  if (retry_ms_ > 0 && last_attempt_ms_ != 0 && now - last_attempt_ms_ < retry_ms_) return false;
  last_attempt_ms_ = now;

  // Un client TLS neuf pour chaque POST s'est montre plus robuste sur le
  // terrain qu'un WiFiClientSecure persistant apres un handshake interrompu.
  WiFiClientSecure secure;
  secure.setCACert(VESCOPE_MQTT_ROOT_CA);
  secure.setHandshakeTimeout(6);

  HTTPClient http;
  http.setConnectTimeout(3500);
  http.setTimeout(5000);
  http.setReuse(false);
  const char* response_headers[] = {"Date"};
  http.collectHeaders(response_headers, 1);

  const String url = String("https://") + VESCOPE_HTTPS_INGEST_HOST +
                     "/api/v1/ingest/" + device_id + "/" + channel;

  if (!http.begin(secure, url)) {
    ++error_count_;
    last_http_code_ = -1;
    retry_ms_ = retry_ms_ == 0 ? HTTPS_RETRY_MIN_MS : min<uint32_t>(HTTPS_RETRY_MAX_MS, retry_ms_ * 2);
    return false;
  }

  http.addHeader("Content-Type", "application/json");
  http.addHeader("Authorization", String("Bearer ") + VESCOPE_HTTPS_INGEST_TOKEN);
  const String outbound = payloadForHttpsTransport(channel, payload);
  const int code = http.POST(outbound);
  last_http_code_ = code;
  const bool ok = code >= 200 && code < 300;
  const String server_date = http.header("Date");
  http.end();
  secure.stop();

  if (ok) {
    if (server_date.length() > 0) setClockFromHttpDate(server_date);
    last_success_ms_ = millis();
    ++success_count_;
    retry_ms_ = 0;
  } else {
    ++error_count_;
    retry_ms_ = retry_ms_ == 0 ? HTTPS_RETRY_MIN_MS : min<uint32_t>(HTTPS_RETRY_MAX_MS, retry_ms_ * 2);
  }

  return ok;
#endif
}

bool HttpsFallback::recentlySuccessful(uint32_t max_age_ms) const {
  return last_success_ms_ != 0 && millis() - last_success_ms_ <= max_age_ms;
}

int HttpsFallback::lastHttpCode() const { return last_http_code_; }
uint32_t HttpsFallback::successCount() const { return success_count_; }
uint32_t HttpsFallback::errorCount() const { return error_count_; }

}  // namespace vescope
