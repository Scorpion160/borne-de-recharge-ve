#include "board_ui.h"

#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <Wire.h>

#include "config.h"

namespace vescope {

namespace {
Adafruit_SSD1306 display(OLED_WIDTH, OLED_HEIGHT, &Wire, -1);
}

void BoardUi::begin() {
  pinMode(RGB_R_PIN, OUTPUT);
  pinMode(RGB_G_PIN, OUTPUT);
  pinMode(RGB_B_PIN, OUTPUT);
  setRgb(0, 0, 1);

  Wire.begin(OLED_SDA_PIN, OLED_SCL_PIN);
  oled_ready_ = display.begin(SSD1306_SWITCHCAPVCC, OLED_I2C_ADDRESS);
  if (oled_ready_) {
    display.clearDisplay();
    display.setTextColor(SSD1306_WHITE);
    display.setTextSize(1);
    display.display();
  }
}

void BoardUi::showBoot(const char* firmware) {
  setRgb(0, 0, 1);
  if (!oled_ready_) return;
  display.clearDisplay();
  display.setCursor(0, 0);
  display.setTextSize(2);
  display.println("VE-SCOPE");
  display.setTextSize(1);
  display.println("Core terrain");
  display.println(firmware);
  display.println("Initialisation...");
  display.display();
}

void BoardUi::showTelemetry(const PzemMeasurement& m, bool wifi, bool mqtt, bool ble, bool charging) {
  if (charging) setRgb(0, 1, 0);
  else if (mqtt) setRgb(0, 1, 1);
  else if (wifi) setRgb(0, 0, 1);
  else if (ble) setRgb(1, 0, 1);
  else setRgb(1, 1, 0);

  if (!oled_ready_) return;
  display.clearDisplay();
  display.setTextSize(1);
  display.setCursor(0, 0);
  display.printf("U %6.1f V  %s\n", m.voltage_v, charging ? "CHG" : "IDLE");
  display.printf("I %6.2f A\n", m.current_a);
  display.printf("P %6.2f kW\n", m.active_power_w / 1000.0F);
  display.printf("PF %.3f  F %.2fHz\n", m.power_factor, m.frequency_hz);
  display.printf("E %.3f kWh\n", m.energy_total_wh / 1000.0F);
  display.printf("W:%s M:%s B:%s", wifi ? "OK" : "--", mqtt ? "OK" : "--", ble ? "OK" : "--");
  display.display();
}

void BoardUi::showPzemOffline(bool wifi, bool mqtt, bool ble) {
  setRgb(1, 0, 0);
  if (!oled_ready_) return;
  display.clearDisplay();
  display.setTextSize(1);
  display.setCursor(0, 0);
  display.println("VE-SCOPE");
  display.println("PZEM OFFLINE");
  display.println();
  display.printf("WiFi: %s\n", wifi ? "OK" : "NON");
  display.printf("MQTT: %s\n", mqtt ? "OK" : "NON");
  display.printf("BLE : %s\n", ble ? "OK" : "NON");
  display.display();
}

bool BoardUi::oledReady() const { return oled_ready_; }

void BoardUi::setRgb(uint8_t r, uint8_t g, uint8_t b) {
  digitalWrite(RGB_R_PIN, r ? HIGH : LOW);
  digitalWrite(RGB_G_PIN, g ? HIGH : LOW);
  digitalWrite(RGB_B_PIN, b ? HIGH : LOW);
}

}  // namespace vescope
