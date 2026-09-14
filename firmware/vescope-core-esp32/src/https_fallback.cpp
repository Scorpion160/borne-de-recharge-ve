#include "https_fallback.h"

#include <WiFi.h>

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
  last_http_code_ = 0;
  success_count_ = 0;
  error_count_ = 0;
  configured_ = false;

#if VESCOPE_HTTPS_FALLBACK_ENABLED
  if (strlen(VESCOPE_HTTPS_INGEST_HOST) == 0 ||
      strlen(VESCOPE_HTTPS_INGEST_TOKEN) == 0 ||
      strlen(VESCOPE_MQTT_ROOT_CA) == 0) {
    return;
  }

  secure_.setCACert(VESCOPE_MQTT_ROOT_CA);
  secure_.setHandshakeTimeout(4);
  http_.setConnectTimeout(2500);
  http_.setTimeout(3500);
  // HTTPClient conserve le socket TLS si le serveur accepte keep-alive.
  // Cela evite un nouveau handshake TLS pour chaque mesure PZEM a 1 Hz.
  http_.setReuse(true);
  configured_ = true;
#endif
}

bool HttpsFallback::publish(const char* device_id, const char* channel, const String& payload) {
#if !VESCOPE_HTTPS_FALLBACK_ENABLED
  (void)device_id;
  (void)channel;
  (void)payload;
  return false;
#else
  if (!configured_ || WiFi.status() != WL_CONNECTED) return false;

  const uint32_t now = millis();
  if (retry_ms_ > 0 && last_attempt_ms_ != 0 && now - last_attempt_ms_ < retry_ms_) return false;
  last_attempt_ms_ = now;

  const String url = String("https://") + VESCOPE_HTTPS_INGEST_HOST +
                     "/api/v1/ingest/" + device_id + "/" + channel;

  // Reutiliser le meme HTTPClient et le meme WiFiClientSecure est essentiel :
  // setReuse(true) peut alors conserver la connexion TLS entre deux POST vers
  // le meme hote, meme si le chemin change selon le canal VE-SCOPE.
  http_.setReuse(true);
  if (!http_.begin(secure_, url)) {
    ++error_count_;
    last_http_code_ = -1;
    retry_ms_ = retry_ms_ == 0 ? HTTPS_RETRY_MIN_MS : min<uint32_t>(HTTPS_RETRY_MAX_MS, retry_ms_ * 2);
    return false;
  }

  http_.addHeader("Content-Type", "application/json");
  http_.addHeader("Authorization", String("Bearer ") + VESCOPE_HTTPS_INGEST_TOKEN);
  const int code = http_.POST(payload);
  last_http_code_ = code;
  const bool ok = code >= 200 && code < 300;
  http_.end();

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
