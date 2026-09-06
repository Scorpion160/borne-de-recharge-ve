#pragma once

#include <Arduino.h>

#include "pzem_modbus.h"

namespace vescope {

void statusUiBegin();
void statusUiUpdate(
    const PzemMeasurement& measurement,
    bool have_measurement,
    bool wifi_connected,
    bool mqtt_connected,
    bool session_active,
    const String& pzem_error);

}  // namespace vescope
