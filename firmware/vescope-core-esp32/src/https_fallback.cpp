#include "https_fallback.h"

#include <HTTPClient.h>
#include <WiFi.h>
#include <WiFiClientSecure.h>
#include <cstring>

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
}

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
  const int code = http.POST(payload);
  last_http_code_ = code;
  const bool ok = code >= 200 && code < 300;
  http.end();
  secure.stop();

  if (ok) {
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
