#pragma once

#include <Arduino.h>
#include <WebServer.h>

namespace vescope {

class FieldConnectivity {
 public:
  void begin(WebServer& server, const char* device_id);
  void handle();
  bool apActive() const;
  bool maintenanceApForced() const;
  bool staConnected() const;
  String staIp() const;
  String apIp() const;
  String mdnsHost() const;
  String activeSsid() const;
  bool usingStoredWifi() const;
  bool captivePortalEnabled() const;
  bool captivePortalAuthenticated() const;
  int captivePortalLastHttpCode() const;

 private:
  void startFallbackAp();
  void stopFallbackAp();
  void startMdnsIfNeeded();
  void configureArduinoOta();
  void configureWebOta();
  void configureWifiPortal();
  void loadWifiCredentials();
  void connectPrimaryWifi();
  bool internetProbe();
  bool authenticateCaptivePortal();

  WebServer* server_ = nullptr;
  String device_id_;
  String mdns_host_;
  String wifi_ssid_;
  String wifi_password_;
  String portal_user_;
  String portal_password_;
  uint32_t offline_since_ms_ = 0;
  uint32_t last_wifi_retry_ms_ = 0;
  uint32_t recovery_started_ms_ = 0;
  uint32_t last_portal_probe_ms_ = 0;
  uint32_t last_portal_attempt_ms_ = 0;
  uint32_t portal_failure_since_ms_ = 0;
  int portal_last_http_code_ = 0;
  bool ap_active_ = false;
  bool maintenance_ap_forced_ = false;
  bool mdns_started_ = false;
  bool ota_started_ = false;
  bool stored_wifi_ = false;
  bool portal_enabled_ = false;
  bool portal_authenticated_ = false;
};

}  // namespace vescope
