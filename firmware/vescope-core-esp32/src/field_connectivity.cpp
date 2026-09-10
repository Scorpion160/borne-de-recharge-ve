#include "field_connectivity.h"

#include <ArduinoJson.h>
#include <ArduinoOTA.h>
#include <DNSServer.h>
#include <ESPmDNS.h>
#include <Preferences.h>
#include <Update.h>
#include <WiFi.h>

#include "config.h"

#if __has_include("secrets.h")
#include "secrets.h"
#else
#include "secrets.example.h"
#endif

namespace vescope {

namespace {
DNSServer dns_server;
Preferences wifi_prefs;
}

void FieldConnectivity::loadWifiCredentials() {
  wifi_prefs.begin("vescope-wifi", false);
  const String stored_ssid = wifi_prefs.getString("ssid", "");
  if (stored_ssid.length() > 0) {
    wifi_ssid_ = stored_ssid;
    wifi_password_ = wifi_prefs.getString("pass", "");
    stored_wifi_ = true;
  } else {
    wifi_ssid_ = VESCOPE_WIFI_SSID;
    wifi_password_ = VESCOPE_WIFI_PASSWORD;
    stored_wifi_ = false;
  }
}

void FieldConnectivity::connectPrimaryWifi() {
  if (wifi_ssid_.isEmpty()) return;
  WiFi.begin(wifi_ssid_.c_str(), wifi_password_.c_str());
}

void FieldConnectivity::begin(WebServer& server, const char* device_id) {
  server_ = &server;
  device_id_ = device_id;
  mdns_host_ = String(MDNS_HOST_PREFIX) + device_id_;
  mdns_host_.toLowerCase();
  offline_since_ms_ = millis();

  loadWifiCredentials();

  WiFi.persistent(false);
  WiFi.setAutoReconnect(true);
  WiFi.mode(WIFI_STA);
  connectPrimaryWifi();
  Serial.printf("[VE-SCOPE] Wi-Fi primaire: %s (%s)\n", wifi_ssid_.c_str(), stored_wifi_ ? "NVS" : "firmware");

  configureWebOta();
  configureWifiPortal();
}

void FieldConnectivity::configureArduinoOta() {
  if (ota_started_) return;
  ArduinoOTA.setHostname(mdns_host_.c_str());
  ArduinoOTA.setPassword(VESCOPE_OTA_PASSWORD);
  ArduinoOTA.onStart([]() { Serial.println("[VE-SCOPE] OTA reseau: debut"); });
  ArduinoOTA.onEnd([]() { Serial.println("\n[VE-SCOPE] OTA reseau: termine"); });
  ArduinoOTA.onProgress([](unsigned int progress, unsigned int total) {
    const unsigned int percent = total ? (progress * 100U) / total : 0U;
    Serial.printf("[VE-SCOPE] OTA: %u%%\r", percent);
  });
  ArduinoOTA.onError([](ota_error_t error) {
    Serial.printf("[VE-SCOPE] OTA erreur %u\n", static_cast<unsigned int>(error));
  });
  ArduinoOTA.begin();
  MDNS.addService("http", "tcp", 80);
  ota_started_ = true;
  mdns_started_ = true;
  Serial.printf("[VE-SCOPE] OTA/mDNS: %s.local\n", mdns_host_.c_str());
}

void FieldConnectivity::configureWebOta() {
  if (server_ == nullptr) return;

  server_->on("/api/connectivity", HTTP_GET, [this]() {
    JsonDocument doc;
    doc["schema"] = 1;
    doc["device_id"] = device_id_;
    doc["wifi_connected"] = staConnected();
    doc["wifi_ssid"] = staConnected() ? WiFi.SSID() : "";
    doc["configured_ssid"] = wifi_ssid_;
    doc["wifi_config_source"] = stored_wifi_ ? "NVS" : "firmware";
    doc["wifi_rssi_dbm"] = staConnected() ? WiFi.RSSI() : -127;
    doc["wifi_ip"] = staIp();
    doc["fallback_ap_active"] = ap_active_;
    doc["fallback_ap_ssid"] = ap_active_ ? String(AP_SSID_PREFIX) + device_id_ : "";
    doc["fallback_ap_ip"] = apIp();
    doc["mdns"] = mdns_host_ + ".local";
    doc["ota_web_path"] = "/update";
    doc["wifi_config_path"] = "/wifi";
    String payload;
    serializeJson(doc, payload);
    server_->send(200, "application/json; charset=utf-8", payload);
  });

  server_->on("/update", HTTP_GET, [this]() {
    if (!server_->authenticate(VESCOPE_OTA_WEB_USER, VESCOPE_OTA_WEB_PASSWORD)) {
      return server_->requestAuthentication();
    }
    const char page[] PROGMEM = R"HTML(
<!doctype html><html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>VE-SCOPE OTA</title><style>body{font-family:system-ui;background:#071321;color:#eaf2fa;padding:24px}main{max-width:560px;margin:auto;background:#0d1d2f;border:1px solid #29435d;border-radius:16px;padding:24px}input,button{width:100%;box-sizing:border-box;margin-top:12px;padding:12px;border-radius:10px}button{background:#1765a4;color:white;border:0;font-weight:700}</style></head>
<body><main><h1>VE-SCOPE OTA</h1><p>Selectionnez le fichier <code>firmware.bin</code> compile pour cette carte.</p>
<form method="POST" action="/update" enctype="multipart/form-data"><input type="file" name="firmware" accept=".bin" required><button type="submit">Mettre a jour</button></form></main></body></html>
)HTML";
    server_->send(200, "text/html; charset=utf-8", page);
  });

  server_->on(
      "/update", HTTP_POST,
      [this]() {
        if (!server_->authenticate(VESCOPE_OTA_WEB_USER, VESCOPE_OTA_WEB_PASSWORD)) {
          return server_->requestAuthentication();
        }
        const bool ok = !Update.hasError();
        server_->send(ok ? 200 : 500, "text/plain; charset=utf-8", ok ? "OTA OK - redemarrage" : "OTA ECHEC");
        delay(250);
        if (ok) ESP.restart();
      },
      [this]() {
        if (!server_->authenticate(VESCOPE_OTA_WEB_USER, VESCOPE_OTA_WEB_PASSWORD)) return;
        HTTPUpload& upload = server_->upload();
        if (upload.status == UPLOAD_FILE_START) {
          Serial.printf("[VE-SCOPE] OTA Web: %s\n", upload.filename.c_str());
          if (!Update.begin(UPDATE_SIZE_UNKNOWN)) Update.printError(Serial);
        } else if (upload.status == UPLOAD_FILE_WRITE) {
          if (Update.write(upload.buf, upload.currentSize) != upload.currentSize) Update.printError(Serial);
        } else if (upload.status == UPLOAD_FILE_END) {
          if (Update.end(true)) {
            Serial.printf("[VE-SCOPE] OTA Web terminee: %u octets\n", upload.totalSize);
          } else {
            Update.printError(Serial);
          }
        }
      });
}

void FieldConnectivity::configureWifiPortal() {
  if (server_ == nullptr) return;

  server_->on("/wifi", HTTP_GET, [this]() {
    if (!server_->authenticate(VESCOPE_OTA_WEB_USER, VESCOPE_OTA_WEB_PASSWORD)) {
      return server_->requestAuthentication();
    }
    String page = R"HTML(
<!doctype html><html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>VE-SCOPE Wi-Fi</title><style>body{font-family:system-ui;background:#071321;color:#eaf2fa;padding:24px}main{max-width:560px;margin:auto;background:#0d1d2f;border:1px solid #29435d;border-radius:16px;padding:24px}input,button{width:100%;box-sizing:border-box;margin-top:12px;padding:12px;border-radius:10px}button{background:#1765a4;color:white;border:0;font-weight:700}small{color:#9fb2c6}</style></head><body><main><h1>VE-SCOPE Wi-Fi</h1><p>Reseau configure : <b>)HTML";
    page += wifi_ssid_;
    page += R"HTML(</b></p><form method="POST" action="/api/wifi/config"><label>SSID</label><input name="ssid" maxlength="32" required><label>Mot de passe</label><input name="password" type="password" maxlength="63"><button type="submit">Enregistrer et redemarrer</button></form><form method="POST" action="/api/wifi/reset"><button type="submit">Revenir au Wi-Fi usine</button></form><p><small>La configuration est stockee dans la memoire NVS de l'ESP32 et peut etre changee sans reflasher.</small></p></main></body></html>)HTML";
    server_->send(200, "text/html; charset=utf-8", page);
  });

  server_->on("/api/wifi/config", HTTP_POST, [this]() {
    if (!server_->authenticate(VESCOPE_OTA_WEB_USER, VESCOPE_OTA_WEB_PASSWORD)) {
      return server_->requestAuthentication();
    }
    if (!server_->hasArg("ssid")) {
      server_->send(400, "text/plain; charset=utf-8", "SSID requis");
      return;
    }
    const String ssid = server_->arg("ssid");
    const String password = server_->arg("password");
    if (ssid.length() == 0 || ssid.length() > 32 || password.length() > 63) {
      server_->send(422, "text/plain; charset=utf-8", "Parametres Wi-Fi invalides");
      return;
    }
    wifi_prefs.putString("ssid", ssid);
    wifi_prefs.putString("pass", password);
    server_->send(200, "text/plain; charset=utf-8", "Wi-Fi enregistre. Redemarrage VE-SCOPE...");
    delay(500);
    ESP.restart();
  });

  server_->on("/api/wifi/reset", HTTP_POST, [this]() {
    if (!server_->authenticate(VESCOPE_OTA_WEB_USER, VESCOPE_OTA_WEB_PASSWORD)) {
      return server_->requestAuthentication();
    }
    wifi_prefs.remove("ssid");
    wifi_prefs.remove("pass");
    server_->send(200, "text/plain; charset=utf-8", "Configuration Wi-Fi locale effacee. Redemarrage...");
    delay(500);
    ESP.restart();
  });
}

void FieldConnectivity::startFallbackAp() {
  if (ap_active_) return;
  WiFi.mode(WIFI_AP_STA);
  const String ssid = String(AP_SSID_PREFIX) + device_id_;
  if (WiFi.softAP(ssid.c_str(), VESCOPE_AP_PASSWORD)) {
    ap_active_ = true;
    dns_server.start(53, "*", WiFi.softAPIP());
    Serial.printf("[VE-SCOPE] AP secours: %s @ %s\n", ssid.c_str(), WiFi.softAPIP().toString().c_str());
    startMdnsIfNeeded();
  }
}

void FieldConnectivity::stopFallbackAp() {
  if (!ap_active_) return;
  dns_server.stop();
  WiFi.softAPdisconnect(true);
  WiFi.mode(WIFI_STA);
  ap_active_ = false;
  recovery_started_ms_ = 0;
  Serial.println("[VE-SCOPE] AP secours arrete: Wi-Fi primaire stable");
}

void FieldConnectivity::startMdnsIfNeeded() {
  if (mdns_started_ && ota_started_) return;
  configureArduinoOta();
}

void FieldConnectivity::handle() {
  const uint32_t now = millis();
  const bool connected = WiFi.status() == WL_CONNECTED;

  if (connected) {
    offline_since_ms_ = 0;
    startMdnsIfNeeded();
    if (ap_active_) {
      if (recovery_started_ms_ == 0) recovery_started_ms_ = now;
      if (now - recovery_started_ms_ >= WIFI_AP_STOP_AFTER_RECOVERY_MS) stopFallbackAp();
    }
  } else {
    recovery_started_ms_ = 0;
    if (offline_since_ms_ == 0) offline_since_ms_ = now;
    if (now - last_wifi_retry_ms_ >= WIFI_RETRY_MS) {
      last_wifi_retry_ms_ = now;
      connectPrimaryWifi();
    }
    if (!ap_active_ && now - offline_since_ms_ >= WIFI_FALLBACK_AP_AFTER_MS) startFallbackAp();
  }

  if (ap_active_) dns_server.processNextRequest();
  if (ota_started_) ArduinoOTA.handle();
}

bool FieldConnectivity::apActive() const { return ap_active_; }
bool FieldConnectivity::staConnected() const { return WiFi.status() == WL_CONNECTED; }
String FieldConnectivity::staIp() const { return staConnected() ? WiFi.localIP().toString() : String(); }
String FieldConnectivity::apIp() const { return ap_active_ ? WiFi.softAPIP().toString() : String(); }
String FieldConnectivity::mdnsHost() const { return mdns_host_; }
String FieldConnectivity::activeSsid() const { return wifi_ssid_; }
bool FieldConnectivity::usingStoredWifi() const { return stored_wifi_; }

}  // namespace vescope
