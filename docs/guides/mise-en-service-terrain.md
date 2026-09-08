# Mise en service terrain VE-SCOPE Core

## Objectif

Installer une seule fois le firmware par USB, puis utiliser OTA pour les mises à jour suivantes.

Le firmware `0.2.0-field` fournit :

- Wi-Fi primaire configuré dans `include/secrets.h` ;
- MQTT vers le Hub ;
- point d'accès de secours `VE-SCOPE-borne-01` après 20 s sans Wi-Fi primaire ;
- API locale sur `http://192.168.4.1` en mode secours ;
- BLE GATT `VE-SCOPE-borne-01` ;
- OTA Web sur `/update` ;
- ArduinoOTA pour maintenance atelier ;
- PZEM-004T sur UART2 GPIO16/17.

## Secrets

`include/secrets.h` est ignoré par Git. Ne jamais mettre les vrais mots de passe dans un fichier versionné.

Variables nécessaires :

```cpp
#define VESCOPE_WIFI_SSID "..."
#define VESCOPE_WIFI_PASSWORD "..."
#define VESCOPE_MQTT_HOST "..."
#define VESCOPE_MQTT_PORT 1883
#define VESCOPE_MQTT_USER ""
#define VESCOPE_MQTT_PASSWORD ""
#define VESCOPE_AP_PASSWORD "..."
#define VESCOPE_OTA_PASSWORD "..."
#define VESCOPE_OTA_WEB_USER "admin"
#define VESCOPE_OTA_WEB_PASSWORD "..."
```

## Premier flash USB

```powershell
pio run -e esp32dev
pio device list
pio run -e esp32dev -t upload --upload-port COMx
pio device monitor -e esp32dev -b 115200 --port COMx
```

## OTA Web

Compiler uniquement :

```powershell
pio run -e esp32dev
```

Le binaire est :

```text
.pio\build\esp32dev\firmware.bin
```

Depuis le même réseau que l'ESP32, ouvrir :

```text
http://vescope-borne-01.local/update
```

ou l'adresse IP affichée dans le moniteur série.

En mode point d'accès de secours :

```text
http://192.168.4.1/update
```

S'authentifier avec les identifiants OTA Web, sélectionner `firmware.bin`, puis envoyer.

## API locale

```text
GET /api/status
GET /api/telemetry
GET /api/session
GET /api/connectivity
GET /update
```

## BLE

Service : `8f110000-6c4d-4f62-9ca8-7ef24ec70001`

Caractéristiques :

- télémétrie : `8f110001-6c4d-4f62-9ca8-7ef24ec70001` READ + NOTIFY ;
- statut : `8f110002-6c4d-4f62-9ca8-7ef24ec70001` READ + NOTIFY ;
- informations : `8f110003-6c4d-4f62-9ca8-7ef24ec70001` READ.

Le client Flutter VE-SCOPE utilisera ces UUIDs pour le mode Bluetooth.

## Test du fallback

1. démarrer avec le Wi-Fi primaire disponible : l'ESP32 doit se connecter sans AP de secours permanent ;
2. couper le Wi-Fi primaire ;
3. après environ 20 s, `VE-SCOPE-borne-01` doit apparaître ;
4. s'y connecter puis ouvrir `http://192.168.4.1` ;
5. remettre le Wi-Fi primaire ;
6. après environ 30 s de stabilité, l'AP de secours doit s'arrêter.

## Sécurité secteur

Les manipulations USB/OTA n'impliquent pas de toucher au 230 V. Toute intervention sur la partie PZEM secteur doit se faire hors tension et avec les protections de la borne en place.
