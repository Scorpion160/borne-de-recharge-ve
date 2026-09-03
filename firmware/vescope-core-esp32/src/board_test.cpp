#include <Arduino.h>
#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <Wire.h>

#include "config.h"
#include "pzem_modbus.h"

using namespace vescope;

HardwareSerial test_pzem_uart(2);
PzemModbus test_pzem(test_pzem_uart, PZEM_ADDRESS, PZEM_TIMEOUT_MS);
Adafruit_SSD1306 test_display(OLED_WIDTH, OLED_HEIGHT, &Wire, -1);

bool oled_ok = false;
uint32_t last_read_ms = 0;

void rgb(bool r, bool g, bool b) {
  digitalWrite(RGB_R_PIN, r ? HIGH : LOW);
  digitalWrite(RGB_G_PIN, g ? HIGH : LOW);
  digitalWrite(RGB_B_PIN, b ? HIGH : LOW);
}

void printI2cScan() {
  Serial.println("[BOARD-TEST] Scan I2C...");
  uint8_t count = 0;
  for (uint8_t address = 1; address < 127; ++address) {
    Wire.beginTransmission(address);
    if (Wire.endTransmission() == 0) {
      Serial.printf("[BOARD-TEST] I2C detecte: 0x%02X\n", address);
      ++count;
    }
  }
  if (!count) Serial.println("[BOARD-TEST] Aucun peripherique I2C detecte");
}

void showText(const String& line1, const String& line2 = "", const String& line3 = "", const String& line4 = "") {
  if (!oled_ok) return;
  test_display.clearDisplay();
  test_display.setTextColor(SSD1306_WHITE);
  test_display.setTextSize(1);
  test_display.setCursor(0, 0);
  test_display.println("VE-SCOPE PCB TEST");
  test_display.drawLine(0, 10, 127, 10, SSD1306_WHITE);
  test_display.setCursor(0, 15);
  test_display.println(line1);
  if (line2.length()) test_display.println(line2);
  if (line3.length()) test_display.println(line3);
  if (line4.length()) test_display.println(line4);
  test_display.display();
}

void setup() {
  Serial.begin(115200);
  delay(500);

  Serial.println();
  Serial.println("====================================");
  Serial.println(" VE-SCOPE CORE - TEST PCB");
  Serial.println("====================================");
  Serial.printf("Carte : %s\n", BOARD_NAME);
  Serial.printf("PZEM : RX GPIO%d / TX GPIO%d\n", PZEM_RX_PIN, PZEM_TX_PIN);
  Serial.printf("OLED : SDA GPIO%d / SCL GPIO%d\n", OLED_SDA_PIN, OLED_SCL_PIN);
  Serial.printf("RGB  : R%d G%d B%d\n", RGB_R_PIN, RGB_G_PIN, RGB_B_PIN);

  pinMode(RGB_R_PIN, OUTPUT);
  pinMode(RGB_G_PIN, OUTPUT);
  pinMode(RGB_B_PIN, OUTPUT);

  Serial.println("[BOARD-TEST] Test LED RGB : rouge -> vert -> bleu -> blanc");
  rgb(true, false, false);
  delay(600);
  rgb(false, true, false);
  delay(600);
  rgb(false, false, true);
  delay(600);
  rgb(true, true, true);
  delay(600);
  rgb(false, false, false);

  Wire.begin(OLED_SDA_PIN, OLED_SCL_PIN);
  printI2cScan();

  oled_ok = test_display.begin(SSD1306_SWITCHCAPVCC, OLED_I2C_ADDRESS);
  Serial.printf("[BOARD-TEST] OLED 0x%02X : %s\n", OLED_I2C_ADDRESS, oled_ok ? "OK" : "NON DETECTE");
  showText("ESP32 : OK", oled_ok ? "OLED : OK" : "OLED : ERREUR", "PZEM : attente...");

  test_pzem.begin(PZEM_BAUD, PZEM_RX_PIN, PZEM_TX_PIN);
  Serial.printf("[BOARD-TEST] PZEM Modbus %lu bauds, adresse 0x%02X\n", PZEM_BAUD, PZEM_ADDRESS);
  Serial.println("[BOARD-TEST] Pret. Lecture PZEM chaque seconde.");

  rgb(false, false, true);
}

void loop() {
  const uint32_t now = millis();
  if (now - last_read_ms < 1000) {
    delay(2);
    return;
  }
  last_read_ms = now;

  PzemMeasurement m;
  if (test_pzem.read(m) && m.valid) {
    rgb(false, true, false);

    Serial.printf(
        "[PZEM] U=%.2f V | I=%.3f A | P=%.1f W | E=%.3f kWh | PF=%.3f | f=%.2f Hz\n",
        m.voltage_v,
        m.current_a,
        m.active_power_w,
        m.energy_total_wh / 1000.0F,
        m.power_factor,
        m.frequency_hz);

    showText(
        String(m.voltage_v, 1) + " V   " + String(m.current_a, 2) + " A",
        String(m.active_power_w, 0) + " W   PF " + String(m.power_factor, 2),
        String(m.frequency_hz, 1) + " Hz",
        "PZEM : OK");
  } else {
    rgb(true, false, false);
    Serial.println(String("[PZEM] Erreur : ") + test_pzem.lastError());
    showText("ESP32/OLED : OK", "PZEM : ERREUR", test_pzem.lastError());
  }
}
