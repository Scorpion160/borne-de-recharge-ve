#pragma once

#include <Arduino.h>

#include "pzem_modbus.h"

namespace vescope {

class BoardUi {
 public:
  void begin();
  void showBoot(const char* firmware);
  void showTelemetry(const PzemMeasurement& m, bool wifi, bool mqtt, bool ble, bool charging);
  void showPzemOffline(bool wifi, bool mqtt, bool ble);
  bool oledReady() const;

 private:
  void setRgb(uint8_t r, uint8_t g, uint8_t b);
  bool oled_ready_ = false;
};

}  // namespace vescope
