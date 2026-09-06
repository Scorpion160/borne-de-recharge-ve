#include "pzem_modbus.h"

#include <cstring>

PzemModbus::PzemModbus(HardwareSerial& serial, uint8_t address, uint32_t timeout_ms)
    : serial_(serial), address_(address), timeout_ms_(timeout_ms) {}

void PzemModbus::begin(uint32_t baud, int rx_pin, int tx_pin) {
  serial_.begin(baud, SERIAL_8N1, rx_pin, tx_pin);
}

uint16_t PzemModbus::crc16(const uint8_t* data, size_t length) {
  uint16_t crc = 0xFFFF;
  for (size_t pos = 0; pos < length; ++pos) {
    crc ^= static_cast<uint16_t>(data[pos]);
    for (uint8_t bit = 0; bit < 8; ++bit) {
      if (crc & 0x0001) {
        crc >>= 1;
        crc ^= 0xA001;
      } else {
        crc >>= 1;
      }
    }
  }
  return crc;
}

uint16_t PzemModbus::be16(const uint8_t* data) {
  return (static_cast<uint16_t>(data[0]) << 8) | data[1];
}

uint32_t PzemModbus::registerPair(uint16_t low_word, uint16_t high_word) {
  return static_cast<uint32_t>(low_word) | (static_cast<uint32_t>(high_word) << 16);
}

void PzemModbus::setError(const char* message) {
  ++error_count_;
  std::strncpy(last_error_, message, sizeof(last_error_) - 1);
  last_error_[sizeof(last_error_) - 1] = '\0';
}

bool PzemModbus::validateResponse(const uint8_t* response, size_t length) {
  if (length != 25) {
    setError("response_length");
    return false;
  }
  if (response[0] != address_) {
    setError("address_mismatch");
    return false;
  }
  if (response[1] != 0x04 || response[2] != 20) {
    setError("function_or_byte_count");
    return false;
  }

  const uint16_t expected_crc = crc16(response, length - 2);
  const uint16_t received_crc = static_cast<uint16_t>(response[length - 2]) |
                                (static_cast<uint16_t>(response[length - 1]) << 8);
  if (expected_crc != received_crc) {
    setError("crc");
    return false;
  }
  return true;
}

bool PzemModbus::read(PzemMeasurement& measurement) {
  measurement = PzemMeasurement{};

  while (serial_.available()) {
    serial_.read();
  }

  uint8_t request[8] = {address_, 0x04, 0x00, 0x00, 0x00, 0x0A, 0x00, 0x00};
  const uint16_t request_crc = crc16(request, 6);
  request[6] = request_crc & 0xFF;
  request[7] = request_crc >> 8;

  serial_.write(request, sizeof(request));
  serial_.flush();

  uint8_t response[25] = {};
  size_t received = 0;
  const uint32_t started = millis();
  while ((millis() - started) < timeout_ms_ && received < sizeof(response)) {
    while (serial_.available() && received < sizeof(response)) {
      response[received++] = static_cast<uint8_t>(serial_.read());
    }
    delay(1);
  }

  if (!validateResponse(response, received)) {
    return false;
  }

  const uint16_t voltage_raw = be16(&response[3]);
  const uint16_t current_low = be16(&response[5]);
  const uint16_t current_high = be16(&response[7]);
  const uint16_t power_low = be16(&response[9]);
  const uint16_t power_high = be16(&response[11]);
  const uint16_t energy_low = be16(&response[13]);
  const uint16_t energy_high = be16(&response[15]);
  const uint16_t frequency_raw = be16(&response[17]);
  const uint16_t pf_raw = be16(&response[19]);
  const uint16_t alarm_raw = be16(&response[21]);

  measurement.voltage_v = static_cast<float>(voltage_raw) / 10.0F;
  measurement.current_a = static_cast<float>(registerPair(current_low, current_high)) / 1000.0F;
  measurement.active_power_w = static_cast<float>(registerPair(power_low, power_high)) / 10.0F;
  measurement.energy_total_wh = static_cast<float>(registerPair(energy_low, energy_high));
  measurement.frequency_hz = static_cast<float>(frequency_raw) / 10.0F;
  measurement.power_factor = static_cast<float>(pf_raw) / 100.0F;
  measurement.alarm = alarm_raw != 0;
  measurement.valid = true;

  ++success_count_;
  std::strncpy(last_error_, "none", sizeof(last_error_));
  return true;
}
