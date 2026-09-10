#pragma once

#include <Arduino.h>

namespace vescope {

class HttpsFallback {
 public:
  void begin();
  bool publish(const char* device_id, const char* channel, const String& payload);
  bool recentlySuccessful(uint32_t max_age_ms = 15000) const;
  int lastHttpCode() const;
  uint32_t successCount() const;
  uint32_t errorCount() const;

 private:
  uint32_t last_attempt_ms_ = 0;
  uint32_t last_success_ms_ = 0;
  uint32_t retry_ms_ = 1000;
  uint32_t success_count_ = 0;
  uint32_t error_count_ = 0;
  int last_http_code_ = 0;
};

}  // namespace vescope
