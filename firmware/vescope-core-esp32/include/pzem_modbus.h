#pragma once

#include <Arduino.h>

struct PzemMeasurement {
  bool valid = false;
  float voltage_v = 0.0F;
  float current_a = 0.0F;
  float active_power_w = 0.0F;
  float energy_total_wh = 0.0F;
  float frequency_hz = 0.0F;
  float power_factor = 0.0F;
  bool alarm = false;
};

class PzemModbus {
 public:
  PzemModbus(HardwareSerial& serial, uint8_t address, uint32_t timeout_ms);

  void begin(uint32_t baud, int rx_pin, int tx_pin);
  bool read(PzemMeasurement& measurement);

  uint32_t successCount() const { return success_count_; }
  uint32_t errorCount() const { return error_count_; }
  const char* lastError() const { return last_error_; }

 private:
  static uint16_t crc16(const uint8_t* data, size_t length);
  static uint16_t be16(const uint8_t* data);
  static uint32_t registerPair(uint16_t low_word, uint16_t high_word);
  bool validateResponse(const uint8_t* response, size_t length);
  void setError(const char* message);

  HardwareSerial& serial_;
  uint8_t address_;
  uint32_t timeout_ms_;
  uint32_t success_count_ = 0;
  uint32_t error_count_ = 0;
  char last_error_[64] = "none";
};
