#pragma once

// Copier ce fichier vers include/secrets.h puis adapter les valeurs.
// Ne jamais committer include/secrets.h.

#define VESCOPE_WIFI_SSID "VOTRE_WIFI"
#define VESCOPE_WIFI_PASSWORD "VOTRE_MOT_DE_PASSE"

// Adresse IP ou nom DNS du broker Mosquitto joignable par l'ESP32.
// Exemple en laboratoire : IP du PC qui exécute docker compose.
#define VESCOPE_MQTT_HOST "mqtt.vescope.kerunjombor.net"
#define VESCOPE_MQTT_PORT 8883
#define VESCOPE_MQTT_TLS 1
#define VESCOPE_MQTT_USER "borne-01"
#define VESCOPE_MQTT_PASSWORD "CHANGE_ME_MQTT"

// Mot de passe du point d'accès local VE-SCOPE-<device_id> (8 caractères min.).
#define VESCOPE_AP_PASSWORD "vescope01"

// OTA local (ArduinoOTA + page Web /update). Ne pas committer les vraies valeurs.
#define VESCOPE_OTA_PASSWORD "CHANGE_ME_OTA"
#define VESCOPE_OTA_WEB_USER "admin"
#define VESCOPE_OTA_WEB_PASSWORD "CHANGE_ME_WEB"
