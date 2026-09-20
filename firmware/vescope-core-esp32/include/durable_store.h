#pragma once

#include <Arduino.h>

namespace vescope {

struct DurableTelemetry {
  uint32_t boot_id = 0;
  uint32_t sequence = 0;
  uint32_t epoch_s = 0;
  uint32_t session_epoch_s = 0;
  float voltage_v = 0.0F;
  float current_a = 0.0F;
  float active_power_w = 0.0F;
  float power_factor = 0.0F;
  float frequency_hz = 0.0F;
  float energy_total_wh = 0.0F;
};

class DurableStore {
 public:
  bool begin();
  bool healthy() const;
  uint32_t bootId() const;

  bool enqueueTelemetry(const DurableTelemetry& record);
  bool peekTelemetry(DurableTelemetry& record);
  bool popTelemetry();
  size_t pendingTelemetry() const;
  size_t telemetryBytes() const;

  bool enqueueSessionSummary(const String& payload);
  bool peekSessionSummary(String& payload);
  bool popSessionSummary();
  size_t pendingSessionSummaries() const;

 private:
  bool compactTelemetry();
  bool compactSessionSummaries();
  void persistTelemetryHead(bool force = false);

  bool fs_ok_ = false;
  uint32_t boot_id_ = 0;
  uint32_t telemetry_head_ = 0;
  uint32_t session_head_ = 0;
  uint32_t telemetry_pops_since_checkpoint_ = 0;
};

}  // namespace vescope
