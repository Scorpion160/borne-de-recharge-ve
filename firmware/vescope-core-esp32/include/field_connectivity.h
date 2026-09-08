#pragma once

#include <Arduino.h>
#include <WebServer.h>

namespace vescope {

class FieldConnectivity {
 public:
  void begin(WebServer& server, const char* device_id);
  void handle();
  bool apActive() const;
  bool staConnected() const;
  String staIp() const;
  String apIp() const;
  String mdnsHost() const;

 private:
  void startFallbackAp();
  void stopFallbackAp();
  void startMdnsIfNeeded();
  void configureArduinoOta();
  void configureWebOta();

  WebServer* server_ = nullptr;
  String device_id_;
  String mdns_host_;
  uint32_t offline_since_ms_ = 0;
  uint32_t last_wifi_retry_ms_ = 0;
  uint32_t recovery_started_ms_ = 0;
  bool ap_active_ = false;
  bool mdns_started_ = false;
  bool ota_started_ = false;
};

}  // namespace vescope
