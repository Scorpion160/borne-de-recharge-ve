#pragma once

#include <Arduino.h>

namespace vescope {

constexpr char DEVICE_ID[] = "borne-01";
constexpr char FIRMWARE_VERSION[] = "0.2.5-field";

// -----------------------------------------------------------------------------
// Cible matérielle
// -----------------------------------------------------------------------------
#if defined(VESCOPE_BOARD_CLASSIC)
constexpr char BOARD_NAME[] = "ESP32 DevKit V1 / WROOM-32";
constexpr int PZEM_RX_PIN = 16;   // PCB: PZEM TX -> ESP32 RX2
constexpr int PZEM_TX_PIN = 17;   // PCB: ESP32 TX2 -> PZEM RX
constexpr int OLED_SDA_PIN = 21;  // PCB: SDA_OLED -> D21
constexpr int OLED_SCL_PIN = 22;  // PCB: SCL_OLED -> D22
constexpr int RGB_R_PIN = 25;     // PCB: R_RGB -> D25
constexpr int RGB_G_PIN = 26;     // PCB: G_RGB -> D26
constexpr int RGB_B_PIN = 27;     // PCB: B_RGB -> D27
#elif defined(VESCOPE_BOARD_S3)
constexpr char BOARD_NAME[] = "ESP32-S3 DevKitC-1";
constexpr int PZEM_RX_PIN = 18;
constexpr int PZEM_TX_PIN = 17;
constexpr int OLED_SDA_PIN = 8;
constexpr int OLED_SCL_PIN = 9;
constexpr int RGB_R_PIN = 10;
constexpr int RGB_G_PIN = 11;
constexpr int RGB_B_PIN = 12;
#else
#error "Cible VE-SCOPE inconnue : utiliser esp32dev ou esp32-s3-devkitc-1"
#endif

constexpr uint8_t OLED_I2C_ADDRESS = 0x3C;
constexpr int OLED_WIDTH = 128;
constexpr int OLED_HEIGHT = 64;

// PZEM-004T v3 / Modbus RTU
constexpr uint8_t PZEM_ADDRESS = 0xF8;
constexpr uint32_t PZEM_BAUD = 9600;
constexpr uint32_t PZEM_TIMEOUT_MS = 350;

// Cadences
constexpr uint32_t TELEMETRY_PERIOD_MS = 1000;
constexpr uint32_t SESSION_PERIOD_MS = 5000;
constexpr uint32_t STATUS_PERIOD_MS = 15000;
constexpr uint32_t DIAGNOSTICS_PERIOD_MS = 10000;
constexpr uint32_t WIFI_RETRY_MS = 5000;
constexpr uint32_t WIFI_FALLBACK_AP_AFTER_MS = 20000;
constexpr uint32_t WIFI_AP_STOP_AFTER_RECOVERY_MS = 30000;
constexpr uint32_t BLE_TELEMETRY_PERIOD_MS = 1000;
constexpr uint32_t MQTT_RETRY_MIN_MS = 5000;
constexpr uint32_t MQTT_RETRY_MAX_MS = 60000;

// Détection d'une session de recharge AC.
constexpr float SESSION_START_POWER_W = 100.0F;
constexpr float SESSION_START_CURRENT_A = 0.50F;
constexpr float SESSION_STOP_POWER_W = 50.0F;
constexpr float SESSION_STOP_CURRENT_A = 0.25F;
constexpr uint8_t SESSION_START_CONFIRM_SAMPLES = 3;
constexpr uint8_t SESSION_STOP_CONFIRM_SAMPLES = 5;

// Contrôles de cohérence physiques du PZEM.
constexpr float VALID_VOLTAGE_MIN_V = 40.0F;
constexpr float VALID_VOLTAGE_MAX_V = 300.0F;
constexpr float VALID_CURRENT_MAX_A = 100.0F;
constexpr float VALID_FREQUENCY_MIN_HZ = 40.0F;
constexpr float VALID_FREQUENCY_MAX_HZ = 70.0F;

// Point d'accès local de maintenance.
constexpr char AP_SSID_PREFIX[] = "VE-SCOPE-";
constexpr char MDNS_HOST_PREFIX[] = "vescope-";

// BLE GATT UUIDs VE-SCOPE Core V1.
constexpr char BLE_SERVICE_UUID[] = "8f110000-6c4d-4f62-9ca8-7ef24ec70001";
constexpr char BLE_TELEMETRY_UUID[] = "8f110001-6c4d-4f62-9ca8-7ef24ec70001";
constexpr char BLE_STATUS_UUID[] = "8f110002-6c4d-4f62-9ca8-7ef24ec70001";
constexpr char BLE_INFO_UUID[] = "8f110003-6c4d-4f62-9ca8-7ef24ec70001";

}  // namespace vescope
