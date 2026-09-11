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

  // Un paquet BLE legacy est limite a 31 octets. Le UUID 128 bits et le nom
  // complet ne tiennent pas ensemble : UUID dans l'annonce, nom dans la
  // scan-response afin de conserver VE-SCOPE-borne-01 visible au scan.
  NimBLEAdvertisementData advertisement_data;
  advertisement_data.addServiceUUID(BLE_SERVICE_UUID);

  NimBLEAdvertisementData scan_response_data;
  scan_response_data.setName(name.c_str());

  NimBLEAdvertising* advertising = NimBLEDevice::getAdvertising();
  advertising->setAdvertisementData(advertisement_data);
  advertising->setScanResponseData(scan_response_data);
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
