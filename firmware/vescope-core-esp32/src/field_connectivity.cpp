#include "field_connectivity.h"

#include <ArduinoJson.h>
#include <ArduinoOTA.h>
#include <DNSServer.h>
#include <ESPmDNS.h>
#include <HTTPClient.h>
#include <Preferences.h>
#include <Update.h>
#include <WiFi.h>

#include "config.h"

#if __has_include("secrets.h")
#include "secrets.h"
#else
#include "secrets.example.h"
#endif

// Compatible avec les anciens secrets.h prives, sans y inscrire de secret.
#ifndef VESCOPE_PRIORITY_WIFI_SSID
#define VESCOPE_PRIORITY_WIFI_SSID "SN"
#endif
#ifndef VESCOPE_PRIORITY_WIFI_PASSWORD
#define VESCOPE_PRIORITY_WIFI_PASSWORD ""
#endif

namespace vescope {

namespace {
DNSServer dns_server;
Preferences wifi_prefs;
constexpr uint8_t FALLBACK_AP_CHANNEL = 6;
constexpr uint8_t FALLBACK_AP_MAX_CLIENTS = 4;
const IPAddress FALLBACK_AP_IP(192, 168, 4, 1);
const IPAddress FALLBACK_AP_MASK(255, 255, 255, 0);

// Portail captif ESP / Etudiant_ESP observe sur le terrain le 14/09/2026.
constexpr char CAPTIVE_PORTAL_LOGIN_URL[] =
    "http://10.7.0.1:8002/index.php?zone=portail_etudiant";
constexpr char CAPTIVE_PORTAL_ORIGIN[] = "http://10.7.0.1:8002";
constexpr char CAPTIVE_PORTAL_REFERER[] =
    "http://10.7.0.1:8002/index.php?zone=portail_etudiant&redirurl="
    "http%3A%2F%2Fwww.msftconnecttest.com%2Fredirect";
constexpr char CAPTIVE_PORTAL_REDIRECT[] = "https://esp.sn";
constexpr char INTERNET_PROBE_URL[] =
    "http://www.msftconnecttest.com/connecttest.txt";
constexpr char INTERNET_PROBE_EXPECTED[] = "Microsoft Connect Test";
constexpr uint32_t PORTAL_PROBE_PERIOD_MS = 60000;
constexpr uint32_t PORTAL_RETRY_MS = 10000;
constexpr uint32_t PORTAL_FALLBACK_AFTER_MS = 90000;
constexpr uint32_t PRIORITY_CONNECT_TIMEOUT_MS = 20000;
constexpr uint32_t PRIORITY_SCAN_PERIOD_MS = 60000;
constexpr uint32_t PRIORITY_RETRY_COOLDOWN_MS = 120000;
constexpr uint32_t OTA_WINDOW_MS = 120000;

String formUrlEncode(const String& input) {
  static const char hex[] = "0123456789ABCDEF";
  String output;
  output.reserve(input.length() * 3);

  for (size_t i = 0; i < input.length(); ++i) {
    const uint8_t c = static_cast<uint8_t>(input[i]);
    const bool unreserved =
        (c >= 'a' && c <= 'z') || (c >= 'A' && c <= 'Z') ||
        (c >= '0' && c <= '9') || c == '-' || c == '_' || c == '.' || c == '~';
    if (unreserved) {
      output += static_cast<char>(c);
    } else if (c == ' ') {
      output += '+';
    } else {
      output += '%';
      output += hex[(c >> 4) & 0x0F];
      output += hex[c & 0x0F];
    }
  }
  return output;
}
String htmlEscape(String value) {
  value.replace("&", "&amp;");
  value.replace("<", "&lt;");
  value.replace(">", "&gt;");
  value.replace("\"", "&quot;");
  value.replace("'", "&#39;");
  return value;
}
}  // namespace

void FieldConnectivity::loadWifiCredentials() {
  wifi_prefs.begin("vescope-wifi", false);
  if (wifi_prefs.isKey("ssid")) {
    wifi_ssid_ = wifi_prefs.getString("ssid", "");
    wifi_password_ = wifi_prefs.getString("pass", "");
    stored_wifi_ = wifi_ssid_.length() > 0;
  }

  if (!stored_wifi_) {
    wifi_ssid_ = VESCOPE_WIFI_SSID;
    wifi_password_ = VESCOPE_WIFI_PASSWORD;
  }

  // Les profils deja en NVS survivent a un flash OTA et USB sans effacement.
  priority_ssid_ = wifi_prefs.getString("pssid", VESCOPE_PRIORITY_WIFI_SSID);
  priority_password_ = wifi_prefs.getString("ppasswifi", VESCOPE_PRIORITY_WIFI_PASSWORD);

  portal_enabled_ = wifi_prefs.getBool("portal", false);
  if (portal_enabled_) {
    portal_user_ = wifi_prefs.getString("puser", "");
    portal_password_ = wifi_prefs.getString("ppass", "");
    if (portal_user_.length() == 0 || portal_password_.length() == 0) {
      portal_enabled_ = false;
    }
  }
}

bool FieldConnectivity::priorityConfigured() const {
  return priority_ssid_.length() > 0 && priority_ssid_ != wifi_ssid_ &&
      priority_password_.length() > 0;
}

bool FieldConnectivity::portalRequired() const {
  return portal_enabled_ && staConnected() && WiFi.SSID() == wifi_ssid_;
}

void FieldConnectivity::connectPrimaryWifi() {
  if (!priorityConfigured()) {
    connectFallbackWifi();
    return;
  }
  if (staConnected() && WiFi.SSID() == priority_ssid_) return;

  WiFi.mode(WIFI_AP_STA);
  WiFi.setSleep(true);
  WiFi.setAutoReconnect(true);
  WiFi.disconnect(false, false);
  wifi_target_ssid_ = priority_ssid_;
  portal_authenticated_ = false;
  last_wifi_retry_ms_ = millis();
  Serial.printf("[VE-SCOPE] Wi-Fi prioritaire: %s\n", priority_ssid_.c_str());
  WiFi.begin(priority_ssid_.c_str(), priority_password_.c_str());
}

void FieldConnectivity::connectFallbackWifi() {
  if (wifi_ssid_.length() == 0 || (staConnected() && WiFi.SSID() == wifi_ssid_)) return;

  // En mode maintenance, conserver l'AP tout en permettant au STA de se
  // reconnecter tout seul. Cela evite qu'une coupure Wi-Fi temporaire impose
  // un redemarrage manuel de la borne.
  WiFi.mode(ap_active_ ? WIFI_AP_STA : WIFI_STA);
  WiFi.setSleep(true);
  WiFi.setAutoReconnect(true);
  WiFi.disconnect(false, false);
  wifi_target_ssid_ = wifi_ssid_;
  portal_authenticated_ = false;
  last_wifi_retry_ms_ = millis();
  WiFi.begin(wifi_ssid_.c_str(), wifi_password_.c_str());
}

void FieldConnectivity::startPriorityScan(uint32_t now) {
  if (!priorityConfigured() || priority_scanning_ || localMaintenanceActive() ||
      (staConnected() && WiFi.SSID() == priority_ssid_) ||
      (!staConnected() && wifi_target_ssid_ == priority_ssid_ &&
       now - last_wifi_retry_ms_ < PRIORITY_CONNECT_TIMEOUT_MS) ||
      (priority_cooldown_ms_ && now - priority_cooldown_ms_ < PRIORITY_RETRY_COOLDOWN_MS) ||
      (last_priority_scan_ms_ && now - last_priority_scan_ms_ < PRIORITY_SCAN_PERIOD_MS)) return;
  last_priority_scan_ms_ = now;
  // Un scan asynchrone garde l'interface HTTP et l'acquisition reactives.
  priority_scanning_ = WiFi.scanNetworks(true) == WIFI_SCAN_RUNNING;
}

void FieldConnectivity::processPriorityScan(uint32_t now) {
  if (!priority_scanning_) return;
  const int found = WiFi.scanComplete();
  if (found == WIFI_SCAN_RUNNING) return;
  priority_scanning_ = false;
  bool visible = false;
  if (found > 0) {
    for (int i = 0; i < found; ++i) {
      if (WiFi.SSID(i) == priority_ssid_) { visible = true; break; }
    }
  }
  WiFi.scanDelete();
  if (visible && !localMaintenanceActive()) connectPrimaryWifi();
}

void FieldConnectivity::begin(WebServer& server, const char* device_id) {
  server_ = &server;
  device_id_ = device_id;
  mdns_host_ = String(MDNS_HOST_PREFIX) + device_id_;
  mdns_host_.toLowerCase();
  offline_since_ms_ = millis();

  loadWifiCredentials();

  WiFi.persistent(false);
  // ESP32 classique : lorsque BLE et Wi-Fi sont actifs simultanement,
  // le modem sleep doit rester actif pour la coexistence radio.
  WiFi.setSleep(true);
  WiFi.setAutoReconnect(true);
  WiFi.mode(WIFI_STA);
  // Acces local disponible sans attendre une panne du reseau de l'ecole.
  // L'arret explicite depuis /update reste possible jusqu'au prochain boot.
  maintenance_ap_forced_ = true;
  startFallbackAp();
  connectPrimaryWifi();
  Serial.printf("[VE-SCOPE] Wi-Fi secours: %s (%s); prioritaire: %s\n",
      wifi_ssid_.c_str(), stored_wifi_ ? "NVS" : "firmware",
      priorityConfigured() ? priority_ssid_.c_str() : "non configure");
  if (portal_enabled_) {
    Serial.println("[VE-SCOPE] Portail captif: authentification automatique active");
  }

  configureWebOta();
  configureWifiPortal();
}

void FieldConnectivity::configureArduinoOta() {
  if (ota_started_) return;
  ArduinoOTA.setHostname(mdns_host_.c_str());
  ArduinoOTA.setPassword(VESCOPE_OTA_PASSWORD);
  ArduinoOTA.onStart([this]() {
    ota_upload_active_ = true;
    Serial.println("[VE-SCOPE] OTA reseau: debut");
  });
  ArduinoOTA.onEnd([this]() {
    ota_upload_active_ = false;
    Serial.println("\n[VE-SCOPE] OTA reseau: termine");
  });
  ArduinoOTA.onProgress([](unsigned int progress, unsigned int total) {
    const unsigned int percent = total ? (progress * 100U) / total : 0U;
    Serial.printf("[VE-SCOPE] OTA: %u%%\r", percent);
  });
  ArduinoOTA.onError([this](ota_error_t error) {
    ota_upload_active_ = false;
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
    doc["priority_ssid"] = priorityConfigured() ? priority_ssid_ : "";
    doc["wifi_target_ssid"] = wifi_target_ssid_;
    doc["wifi_config_source"] = stored_wifi_ ? "NVS" : "firmware";
    doc["wifi_rssi_dbm"] = staConnected() ? WiFi.RSSI() : -127;
    doc["wifi_ip"] = staIp();
    doc["captive_portal_enabled"] = portalRequired();
    doc["captive_portal_authenticated"] = portal_authenticated_;
    doc["captive_portal_last_http_code"] = portal_last_http_code_;
    doc["fallback_ap_active"] = ap_active_;
    doc["maintenance_ap_forced"] = maintenance_ap_forced_;
    doc["local_maintenance_active"] = localMaintenanceActive();
    doc["ap_clients"] = ap_active_ ? WiFi.softAPgetStationNum() : 0;
    doc["fallback_ap_ssid"] = ap_active_ ? String(AP_SSID_PREFIX) + device_id_ : "";
    doc["fallback_ap_ip"] = apIp();
    doc["fallback_ap_channel"] = ap_active_ ? WiFi.channel() : FALLBACK_AP_CHANNEL;
    doc["mdns"] = mdns_host_ + ".local";
    doc["ota_web_path"] = "/update";
    doc["maintenance_ap_start_path"] = "/api/maintenance/ap/start";
    doc["wifi_config_path"] = "/wifi";
    String payload;
    serializeJson(doc, payload);
    server_->send(200, "application/json; charset=utf-8", payload);
  });

  server_->on("/api/maintenance/ap/start", HTTP_POST, [this]() {
    if (!server_->authenticate(VESCOPE_OTA_WEB_USER, VESCOPE_OTA_WEB_PASSWORD)) {
      return server_->requestAuthentication();
    }

    maintenance_ap_forced_ = true;
    startFallbackAp();

    JsonDocument doc;
    doc["ok"] = ap_active_;
    doc["ssid"] = ap_active_ ? String(AP_SSID_PREFIX) + device_id_ : "";
    doc["ip"] = apIp();
    doc["mode"] = "AP+STA";
    doc["ota_url"] = ap_active_ ? "http://192.168.4.1/update" : "";
    String payload;
    serializeJson(doc, payload);
    server_->send(ap_active_ ? 200 : 500, "application/json; charset=utf-8", payload);
  });

  server_->on("/api/maintenance/ap/stop", HTTP_POST, [this]() {
    if (!server_->authenticate(VESCOPE_OTA_WEB_USER, VESCOPE_OTA_WEB_PASSWORD)) {
      return server_->requestAuthentication();
    }

    server_->send(409, "application/json; charset=utf-8", "{\"ok\":false,\"reason\":\"AP permanent pour recuperation locale\"}");
  });

  server_->on("/update", HTTP_GET, [this]() {
    if (!server_->authenticate(VESCOPE_OTA_WEB_USER, VESCOPE_OTA_WEB_PASSWORD)) {
      return server_->requestAuthentication();
    }
    ota_window_until_ms_ = millis() + OTA_WINDOW_MS;
    const char page[] PROGMEM = R"HTML(
<!doctype html><html lang="fr"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>VE-SCOPE OTA</title><style>body{font-family:system-ui;background:#071321;color:#eaf2fa;padding:24px}main{max-width:620px;margin:auto;background:#0d1d2f;border:1px solid #29435d;border-radius:16px;padding:24px}input,button{width:100%;box-sizing:border-box;margin-top:12px;padding:12px;border-radius:10px}button{background:#1765a4;color:white;border:0;font-weight:700}.secondary{background:#29435d}small{color:#9fb2c6}</style></head>
<body><main><h1>VE-SCOPE OTA</h1><p>Selectionnez le fichier <code>firmware.bin</code> compile pour cette carte.</p>
<form method="POST" action="/update" enctype="multipart/form-data"><input type="file" name="firmware" accept=".bin" required><button type="submit">Mettre a jour</button></form>
<hr><p><b>Acces de secours</b></p><p><small>Le point d'acces est toujours actif. Connectez votre PC a <code>VE-SCOPE-borne-01</code>, puis ouvrez <code>http://192.168.4.1/update</code>. Les envois cloud reprennent automatiquement apres le transfert OTA.</small></p>
<form method="POST" action="/api/maintenance/ap/start"><button class="secondary" type="submit">Activer AP maintenance</button></form>
</main></body></html>)HTML";
    server_->send(200, "text/html; charset=utf-8", page);
  });

  server_->on(
      "/update", HTTP_POST,
      [this]() {
        if (!server_->authenticate(VESCOPE_OTA_WEB_USER, VESCOPE_OTA_WEB_PASSWORD)) {
          return server_->requestAuthentication();
        }
        const bool ok = ota_upload_success_ && !Update.hasError();
        server_->send(ok ? 200 : 500, "text/plain; charset=utf-8", ok ? "OTA OK - redemarrage" : "OTA ECHEC");
        ota_upload_active_ = false;
        delay(250);
        if (ok) ESP.restart();
      },
      [this]() {
        if (!server_->authenticate(VESCOPE_OTA_WEB_USER, VESCOPE_OTA_WEB_PASSWORD)) return;
        HTTPUpload& upload = server_->upload();
        if (upload.status == UPLOAD_FILE_START) {
          ota_upload_active_ = true;
          ota_upload_success_ = false;
          Serial.printf("[VE-SCOPE] OTA Web: %s\n", upload.filename.c_str());
          if (!Update.begin(UPDATE_SIZE_UNKNOWN)) Update.printError(Serial);
        } else if (upload.status == UPLOAD_FILE_WRITE) {
          if (Update.write(upload.buf, upload.currentSize) != upload.currentSize) Update.printError(Serial);
        } else if (upload.status == UPLOAD_FILE_END) {
          if (Update.end(true)) {
            ota_upload_success_ = true;
            Serial.printf("[VE-SCOPE] OTA Web terminee: %u octets\n", upload.totalSize);
          } else {
            Update.printError(Serial);
          }
        } else if (upload.status == UPLOAD_FILE_ABORTED) {
          ota_upload_active_ = false;
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
<title>VE-SCOPE Wi-Fi</title><style>body{font-family:system-ui;background:#071321;color:#eaf2fa;padding:24px}main{max-width:620px;margin:auto;background:#0d1d2f;border:1px solid #29435d;border-radius:16px;padding:24px}input,button{width:100%;box-sizing:border-box;margin-top:10px;padding:12px;border-radius:10px}input[type=checkbox]{width:auto;margin-right:8px}button{background:#1765a4;color:white;border:0;font-weight:700}small{color:#9fb2c6}.box{margin-top:18px;padding:14px;border:1px solid #29435d;border-radius:12px}</style></head><body><main><h1>VE-SCOPE Wi-Fi</h1><p>Reseau configure : <b>)HTML";
    page += htmlEscape(wifi_ssid_);
    page += R"HTML(</b></p><form method="POST" action="/api/wifi/config"><div class="box"><h2>Reseau prioritaire</h2><label>SSID prioritaire</label><input name="priority_ssid" maxlength="32" value=")HTML";
    page += htmlEscape(priority_ssid_.length() ? priority_ssid_ : String("SN"));
    page += R"HTML("><label>Mot de passe prioritaire</label><input name="priority_password" type="password" maxlength="63" autocomplete="new-password" placeholder="Vide = garder l'ancien"><p><small>SN est choisi des qu'il est visible. Sans mot de passe enregistre, le profil reste inactif. Effacez le SSID pour le desactiver.</small></p></div><div class="box"><h2>Reseau de secours</h2><label>SSID</label><input name="ssid" maxlength="32" required value=")HTML";
    page += htmlEscape(wifi_ssid_);
    page += R"HTML("><label>Mot de passe</label><input name="password" type="password" maxlength="63" autocomplete="new-password" placeholder="Vide = garder l'ancien"><label><input type="checkbox" name="portal_enabled" value="1" )HTML";
    if (portal_enabled_) page += "checked ";
    page += R"HTML(>Portail captif (reseau de secours seulement)</label><label>Identifiant portail</label><input name="portal_user" maxlength="96" autocomplete="off" value=")HTML";
    page += htmlEscape(portal_user_);
    page += R"HTML("><label>Mot de passe portail</label><input name="portal_password" type="password" maxlength="128" autocomplete="new-password" placeholder="Vide = garder l'ancien"></div><button type="submit">Enregistrer et redemarrer</button></form><form method="POST" action="/api/wifi/reset"><button type="submit">Effacer les reseaux NVS</button></form><p><small>Configurations conservees en NVS lors d'une OTA. AP local permanent : 192.168.4.1.</small></p></main></body></html>)HTML";
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
    const String password = server_->arg("password").length() ? server_->arg("password") :
        (ssid == wifi_ssid_ ? wifi_password_ : String());
    const String priority_ssid = server_->arg("priority_ssid");
    const String priority_password = server_->arg("priority_password").length() ?
        server_->arg("priority_password") :
        (priority_ssid == priority_ssid_ ? priority_password_ : String());
    const bool portal_enabled = server_->hasArg("portal_enabled");
    const String portal_user = server_->arg("portal_user");
    const String portal_password = server_->arg("portal_password").length() ?
        server_->arg("portal_password") : portal_password_;

    if (ssid.length() == 0 || ssid.length() > 32 || password.length() > 63 ||
        priority_ssid.length() > 32 || priority_password.length() > 63 ||
        (priority_ssid.length() != 0 && priority_ssid == ssid)) {
      server_->send(422, "text/plain; charset=utf-8", "Parametres Wi-Fi invalides");
      return;
    }
    if (portal_enabled &&
        (portal_user.length() == 0 || portal_user.length() > 96 ||
         portal_password.length() == 0 || portal_password.length() > 128)) {
      server_->send(422, "text/plain; charset=utf-8", "Identifiants du portail captif invalides");
      return;
    }

    wifi_prefs.putString("ssid", ssid);
    wifi_prefs.putString("pass", password);
    wifi_prefs.putString("pssid", priority_ssid);
    if (priority_ssid.length() == 0) wifi_prefs.remove("ppasswifi");
    else wifi_prefs.putString("ppasswifi", priority_password);
    wifi_prefs.putBool("portal", portal_enabled);
    if (portal_enabled) {
      wifi_prefs.putString("puser", portal_user);
      wifi_prefs.putString("ppass", portal_password);
    } else {
      wifi_prefs.remove("puser");
      wifi_prefs.remove("ppass");
    }

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
    wifi_prefs.remove("pssid");
    wifi_prefs.remove("ppasswifi");
    wifi_prefs.remove("portal");
    wifi_prefs.remove("puser");
    wifi_prefs.remove("ppass");
    server_->send(200, "text/plain; charset=utf-8", "Configuration Wi-Fi locale effacee. Redemarrage...");
    delay(500);
    ESP.restart();
  });
}

bool FieldConnectivity::internetProbe() {
  if (WiFi.status() != WL_CONNECTED) return false;

  HTTPClient http;
  http.setConnectTimeout(2500);
  http.setTimeout(3500);
  if (!http.begin(INTERNET_PROBE_URL)) return false;

  const int code = http.GET();
  String body;
  if (code == 200) body = http.getString();
  http.end();

  return code == 200 && body.indexOf(INTERNET_PROBE_EXPECTED) >= 0;
}

bool FieldConnectivity::authenticateCaptivePortal() {
  if (!portal_enabled_ || WiFi.status() != WL_CONNECTED ||
      portal_user_.length() == 0 || portal_password_.length() == 0) {
    return false;
  }

  HTTPClient http;
  http.setConnectTimeout(2500);
  http.setTimeout(4500);
  const char* header_keys[] = {"Location"};
  http.collectHeaders(header_keys, 1);

  if (!http.begin(CAPTIVE_PORTAL_LOGIN_URL)) {
    portal_last_http_code_ = -1;
    return false;
  }

  http.addHeader("Content-Type", "application/x-www-form-urlencoded");
  http.addHeader("Origin", CAPTIVE_PORTAL_ORIGIN);
  http.addHeader("Referer", CAPTIVE_PORTAL_REFERER);

  String body;
  body.reserve(portal_user_.length() * 3 + portal_password_.length() * 3 + 180);
  body += "auth_user=" + formUrlEncode(portal_user_);
  body += "&auth_pass=" + formUrlEncode(portal_password_);
  body += "&redirurl=" + formUrlEncode(CAPTIVE_PORTAL_REDIRECT);
  body += "&zone=portail_etudiant";
  body += "&accept=" + formUrlEncode("Cliquez ICI pour aller vers INTERNET");

  const int code = http.POST(body);
  portal_last_http_code_ = code;
  const String location = http.header("Location");
  http.end();

  const bool login_redirect =
      code >= 300 && code < 400 && location.indexOf("esp.sn") >= 0;
  if (!login_redirect) {
    Serial.printf("[VE-SCOPE] Portail captif: echec authentification HTTP %d\n", code);
    return false;
  }

  Serial.printf("[VE-SCOPE] Portail captif: authentification acceptee HTTP %d\n", code);
  for (uint8_t attempt = 0; attempt < 3; ++attempt) {
    delay(600);
    if (internetProbe()) {
      Serial.println("[VE-SCOPE] Portail captif: Internet autorise");
      return true;
    }
  }

  Serial.println("[VE-SCOPE] Portail captif: login accepte mais Internet non confirme");
  return false;
}

void FieldConnectivity::startFallbackAp() {
  if (ap_active_) return;
  last_ap_attempt_ms_ = millis();

  // Garder le STA actif en parallele du point d'acces de maintenance. L'AP
  // reste disponible pour l'operateur tandis que la borne continue de tenter
  // automatiquement son Wi-Fi primaire.
  WiFi.setAutoReconnect(true);
  WiFi.mode(WIFI_AP_STA);
  WiFi.setSleep(true);
  delay(100);

  WiFi.softAPConfig(FALLBACK_AP_IP, FALLBACK_AP_IP, FALLBACK_AP_MASK);

  const String ssid = String(AP_SSID_PREFIX) + device_id_;
  const bool started = WiFi.softAP(
      ssid.c_str(), VESCOPE_AP_PASSWORD,
      FALLBACK_AP_CHANNEL, false, FALLBACK_AP_MAX_CLIENTS);

  if (started) {
    ap_active_ = true;
    recovery_started_ms_ = 0;
    dns_server.start(53, "*", FALLBACK_AP_IP);
    Serial.printf(
        "[VE-SCOPE] AP %s: %s @ %s | mode=AP+STA | canal=%u | visible=oui\n",
        maintenance_ap_forced_ ? "maintenance" : "secours",
        ssid.c_str(), WiFi.softAPIP().toString().c_str(), WiFi.channel());
    startMdnsIfNeeded();
  } else {
    Serial.println("[VE-SCOPE] ERREUR: demarrage AP secours impossible");
  }
}

void FieldConnectivity::stopFallbackAp() {
  if (!ap_active_) return;

  dns_server.stop();
  // false = ne pas arreter l'interface Wi-Fi complete : le STA doit rester
  // connecte si la recuperation du reseau primaire a deja reussi.
  WiFi.softAPdisconnect(false);
  ap_active_ = false;
  recovery_started_ms_ = 0;
  WiFi.mode(WIFI_STA);
  WiFi.setSleep(true);
  WiFi.setAutoReconnect(true);

  if (WiFi.status() != WL_CONNECTED) connectPrimaryWifi();
  Serial.println("[VE-SCOPE] AP maintenance/secours arrete: Wi-Fi primaire conserve");
}

void FieldConnectivity::startMdnsIfNeeded() {
  if (mdns_started_ && ota_started_) return;
  configureArduinoOta();
}

void FieldConnectivity::handle() {
  const uint32_t now = millis();

  if (maintenance_ap_forced_ && !ap_active_ &&
      now - last_ap_attempt_ms_ >= WIFI_RETRY_MS) {
    startFallbackAp();
  }
  if (ap_active_) dns_server.processNextRequest();

  // Seul un transfert OTA (ou sa courte fenetre de preparation) suspend le
  // cloud. Un telephone simplement associe a l'AP ne doit pas remplir la file.
  if (localMaintenanceActive()) {
    if (ota_started_) ArduinoOTA.handle();
    return;
  }

  processPriorityScan(now);

  const bool connected = WiFi.status() == WL_CONNECTED;
  if (connected) {
    offline_since_ms_ = 0;
    startMdnsIfNeeded();
    if (WiFi.SSID() == priority_ssid_) priority_cooldown_ms_ = 0;
    startPriorityScan(now);

    if (portalRequired()) {
      const bool probe_due =
          last_portal_probe_ms_ == 0 || now - last_portal_probe_ms_ >= PORTAL_PROBE_PERIOD_MS;
      if (probe_due) {
        last_portal_probe_ms_ = now;
        if (internetProbe()) {
          if (!portal_authenticated_) {
            Serial.println("[VE-SCOPE] Portail captif: Internet deja autorise");
          }
          portal_authenticated_ = true;
          portal_failure_since_ms_ = 0;
        } else {
          portal_authenticated_ = false;
          if (portal_failure_since_ms_ == 0) portal_failure_since_ms_ = now;

          const bool retry_due =
              last_portal_attempt_ms_ == 0 || now - last_portal_attempt_ms_ >= PORTAL_RETRY_MS;
          if (retry_due) {
            last_portal_attempt_ms_ = now;
            if (authenticateCaptivePortal()) {
              portal_authenticated_ = true;
              portal_failure_since_ms_ = 0;
              last_portal_probe_ms_ = millis();
            }
          }

          if (!portal_authenticated_ && portal_failure_since_ms_ != 0 &&
              now - portal_failure_since_ms_ >= PORTAL_FALLBACK_AFTER_MS && !ap_active_) {
            Serial.println("[VE-SCOPE] Portail captif indisponible: activation AP secours");
            startFallbackAp();
          }
        }
      }
    } else {
      portal_authenticated_ = true;
      portal_failure_since_ms_ = 0;
    }

    const bool primary_ready = !portalRequired() || portal_authenticated_;
    if (ap_active_ && !maintenance_ap_forced_) {
      if (primary_ready) {
        if (recovery_started_ms_ == 0) {
          recovery_started_ms_ = now;
          Serial.println("[VE-SCOPE] Wi-Fi primaire recupere: verification avant arret AP secours");
        } else if (now - recovery_started_ms_ >= WIFI_AP_STOP_AFTER_RECOVERY_MS) {
          stopFallbackAp();
        }
      } else {
        recovery_started_ms_ = 0;
      }
    }
  } else {
    portal_authenticated_ = false;
    portal_failure_since_ms_ = 0;
    last_portal_probe_ms_ = 0;
    recovery_started_ms_ = 0;

    if (offline_since_ms_ == 0) offline_since_ms_ = now;

    if (wifi_target_ssid_ == priority_ssid_ && priorityConfigured() &&
        now - last_wifi_retry_ms_ >= PRIORITY_CONNECT_TIMEOUT_MS) {
      priority_cooldown_ms_ = now;
      WiFi.scanDelete();
      priority_scanning_ = false;
      connectFallbackWifi();
    }

    startPriorityScan(now);

    const uint32_t retry_period = ap_active_ ? WIFI_AP_STA_RETRY_MS : WIFI_RETRY_MS;
    if (wifi_target_ssid_ != priority_ssid_ && now - last_wifi_retry_ms_ >= retry_period) {
      connectFallbackWifi();
    }

    const uint32_t fallback_after =
        portal_enabled_ ? WIFI_FALLBACK_AP_AFTER_PORTAL_MS : WIFI_FALLBACK_AP_AFTER_MS;
    if (!ap_active_ && now - offline_since_ms_ >= fallback_after) {
      startFallbackAp();
    }
  }

  if (ota_started_) ArduinoOTA.handle();
}

bool FieldConnectivity::localMaintenanceActive() const {
  return ota_upload_active_ ||
      (ota_window_until_ms_ != 0 && static_cast<int32_t>(ota_window_until_ms_ - millis()) > 0);
}

bool FieldConnectivity::apActive() const { return ap_active_; }
bool FieldConnectivity::maintenanceApForced() const { return maintenance_ap_forced_; }
bool FieldConnectivity::staConnected() const { return WiFi.status() == WL_CONNECTED; }
String FieldConnectivity::staIp() const { return staConnected() ? WiFi.localIP().toString() : String(); }
String FieldConnectivity::apIp() const { return ap_active_ ? WiFi.softAPIP().toString() : String(); }
String FieldConnectivity::mdnsHost() const { return mdns_host_; }
String FieldConnectivity::activeSsid() const { return staConnected() ? WiFi.SSID() : wifi_target_ssid_; }
bool FieldConnectivity::usingStoredWifi() const { return stored_wifi_; }
bool FieldConnectivity::captivePortalEnabled() const { return portalRequired(); }
bool FieldConnectivity::captivePortalAuthenticated() const { return portal_authenticated_; }
int FieldConnectivity::captivePortalLastHttpCode() const { return portal_last_http_code_; }

}  // namespace vescope
