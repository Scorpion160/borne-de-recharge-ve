#include "ble_service.h"

#include <NimBLEDevice.h>

#include "config.h"

namespace vescope {

namespace {
NimBLECharacteristic* telemetry_characteristic = nullptr;
NimBLECharacteristic* status_characteristic = nullptr;
NimBLECharacteristic* info_characteristic = nullptr;
volatile bool ble_connected = false;

class ServerCallbacks final : public NimBLEServerCallbacks {
  void onConnect(NimBLEServer*, NimBLEConnInfo&) override { ble_connected = true; }
  void onDisconnect(NimBLEServer*, NimBLEConnInfo&, int) override {
    ble_connected = false;
    NimBLEDevice::startAdvertising();
  }
};
}  // namespace

void BleService::begin(const char* device_id, const char* firmware_version) {
  if (started_) return;
  const String name = String("VE-SCOPE-") + device_id;
  NimBLEDevice::init(name.c_str());
  NimBLEDevice::setPower(ESP_PWR_LVL_P9);
  NimBLEServer* server = NimBLEDevice::createServer();
  server->setCallbacks(new ServerCallbacks());

  NimBLEService* service = server->createService(BLE_SERVICE_UUID);
  telemetry_characteristic = service->createCharacteristic(
      BLE_TELEMETRY_UUID, NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::NOTIFY);
  status_characteristic = service->createCharacteristic(
      BLE_STATUS_UUID, NIMBLE_PROPERTY::READ | NIMBLE_PROPERTY::NOTIFY);
  info_characteristic = service->createCharacteristic(
      BLE_INFO_UUID, NIMBLE_PROPERTY::READ);

  String info = String("{\"device_id\":\"") + device_id +
                "\",\"firmware\":\"" + firmware_version +
                "\",\"transport\":\"ble\"}";
  info_characteristic->setValue(info.c_str());
  telemetry_characteristic->setValue("{\"quality\":\"UNAVAILABLE\"}");
  status_characteristic->setValue("{\"state\":\"BOOTING\"}");
  service->start();

  NimBLEAdvertising* advertising = NimBLEDevice::getAdvertising();
  advertising->addServiceUUID(BLE_SERVICE_UUID);
  advertising->setName(name.c_str());
  advertising->enableScanResponse(true);
  advertising->start();
  started_ = true;
  Serial.printf("[VE-SCOPE] BLE actif: %s\n", name.c_str());
}

void BleService::updateTelemetry(const String& payload) {
  if (!started_ || telemetry_characteristic == nullptr) return;
  telemetry_characteristic->setValue(payload.c_str());
  if (ble_connected) telemetry_characteristic->notify();
}

void BleService::updateStatus(const String& payload) {
  if (!started_ || status_characteristic == nullptr) return;
  status_characteristic->setValue(payload.c_str());
  if (ble_connected) status_characteristic->notify();
}

bool BleService::connected() const { return ble_connected; }

}  // namespace vescope
