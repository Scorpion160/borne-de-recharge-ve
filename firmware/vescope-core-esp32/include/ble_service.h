#pragma once

#include <Arduino.h>

namespace vescope {

class BleService {
 public:
  void begin(const char* device_id, const char* firmware_version);
  void updateTelemetry(const String& payload);
  void updateStatus(const String& payload);
  bool connected() const;

 private:
  bool started_ = false;
};

}  // namespace vescope
