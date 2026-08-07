#pragma once

#include <Arduino.h>

namespace vescope {

constexpr char DEVICE_ID[] = "borne-01";
constexpr char FIRMWARE_VERSION[] = "0.1.1-hw";

// -----------------------------------------------------------------------------
// Cible matérielle
// -----------------------------------------------------------------------------
// Prototype actuel : ESP32 classique DevKit / WROOM-32.
// Cible future conservée : ESP32-S3 DevKitC-1.
// Les macros sont injectées par platformio.ini.
#if defined(VESCOPE_BOARD_CLASSIC)
constexpr char BOARD_NAME[] = "ESP32 DevKit / WROOM-32";
constexpr int PZEM_RX_PIN = 16;  // PZEM TX -> adaptation de niveau -> ESP32 RX2
constexpr int PZEM_TX_PIN = 17;  // ESP32 TX2 -> PZEM RX
#elif defined(VESCOPE_BOARD_S3)
constexpr char BOARD_NAME[] = "ESP32-S3 DevKitC-1";
constexpr int PZEM_RX_PIN = 18;  // PZEM TX -> adaptation de niveau -> ESP32 RX
constexpr int PZEM_TX_PIN = 17;  // ESP32 TX -> PZEM RX
#else
#error "Cible VE-SCOPE inconnue : utiliser esp32dev ou esp32-s3-devkitc-1"
#endif

// PZEM-004T v3 / Modbus RTU
constexpr uint8_t PZEM_ADDRESS = 0xF8;
constexpr uint32_t PZEM_BAUD = 9600;
constexpr uint32_t PZEM_TIMEOUT_MS = 350;

// Cadences
constexpr uint32_t TELEMETRY_PERIOD_MS = 1000;
constexpr uint32_t SESSION_PERIOD_MS = 1000;
constexpr uint32_t STATUS_PERIOD_MS = 15000;
constexpr uint32_t DIAGNOSTICS_PERIOD_MS = 10000;
constexpr uint32_t WIFI_RETRY_MS = 5000;
constexpr uint32_t MQTT_RETRY_MIN_MS = 1000;
constexpr uint32_t MQTT_RETRY_MAX_MS = 15000;

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

}  // namespace vescope
