#include "status_ui.h"

#include <Adafruit_GFX.h>
#include <Adafruit_SSD1306.h>
#include <Wire.h>

#include "config.h"

namespace vescope {
namespace {

Adafruit_SSD1306 display(OLED_WIDTH, OLED_HEIGHT, &Wire, -1);
bool display_ready = false;
uint32_t last_refresh_ms = 0;

void setRgb(bool red, bool green, bool blue) {
  digitalWrite(RGB_R_PIN, red ? HIGH : LOW);
  digitalWrite(RGB_G_PIN, green ? HIGH : LOW);
  digitalWrite(RGB_B_PIN, blue ? HIGH : LOW);
}

void drawHeader(const char* state) {
  display.setTextSize(1);
  display.setTextColor(SSD1306_WHITE);
  display.setCursor(0, 0);
  display.print("VE-SCOPE ");
  display.print(state);
  display.drawLine(0, 10, OLED_WIDTH - 1, 10, SSD1306_WHITE);
}

}  // namespace

void statusUiBegin() {
  pinMode(RGB_R_PIN, OUTPUT);
  pinMode(RGB_G_PIN, OUTPUT);
  pinMode(RGB_B_PIN, OUTPUT);
  setRgb(false, false, true);  // bleu : démarrage

  Wire.begin(OLED_SDA_PIN, OLED_SCL_PIN);
  display_ready = display.begin(SSD1306_SWITCHCAPVCC, OLED_I2C_ADDRESS);
  if (!display_ready) return;

  display.clearDisplay();
  display.setTextColor(SSD1306_WHITE);
  display.setTextSize(1);
  display.setCursor(0, 0);
  display.println("VE-SCOPE Core");
  display.println(FIRMWARE_VERSION);
  display.println(BOARD_NAME);
  display.println("Initialisation...");
  display.display();
}

void statusUiUpdate(
    const PzemMeasurement& measurement,
    bool have_measurement,
    bool wifi_connected,
    bool mqtt_connected,
    bool session_active,
    const String& pzem_error) {
  const uint32_t now = millis();
  if (now - last_refresh_ms < 500) return;
  last_refresh_ms = now;

  if (!wifi_connected) {
    setRgb(false, false, true);  // bleu : Wi-Fi en cours
  } else if (!mqtt_connected) {
    setRgb(false, true, true);   // cyan : Wi-Fi OK, MQTT en attente
  } else if (!have_measurement) {
    setRgb(true, false, false);  // rouge : PZEM absent / erreur
  } else if (session_active) {
    setRgb(false, true, false);  // vert : charge active
  } else {
    setRgb(false, true, true);   // cyan : système prêt / attente
  }

  if (!display_ready) return;

  display.clearDisplay();
  drawHeader(session_active ? "CHARGE" : "READY");
  display.setCursor(0, 14);

  display.print("WiFi: ");
  display.println(wifi_connected ? "OK" : "...");
  display.print("MQTT: ");
  display.println(mqtt_connected ? "OK" : "...");

  if (!have_measurement) {
    display.println("PZEM: ERREUR");
    display.print("Err: ");
    String short_error = pzem_error;
    if (short_error.length() > 16) short_error = short_error.substring(0, 16);
    display.println(short_error);
  } else {
    display.print(measurement.voltage_v, 1);
    display.print("V  ");
    display.print(measurement.current_a, 2);
    display.println("A");

    display.print(measurement.active_power_w / 1000.0F, 2);
    display.print("kW PF ");
    display.println(measurement.power_factor, 2);

    display.print(measurement.frequency_hz, 1);
    display.print("Hz ");
    display.print(measurement.energy_total_wh / 1000.0F, 2);
    display.println("kWh");
  }

  display.display();
}

}  // namespace vescope
