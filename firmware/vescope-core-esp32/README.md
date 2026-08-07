# VE-SCOPE Core — ESP32 + PZEM-004T

Ce firmware remplace progressivement le simulateur Python par le matériel réel.

La cible **prototype par défaut** est maintenant un **ESP32 classique DevKit / WROOM-32**. Une cible ESP32-S3 reste disponible dans le même projet pour une éventuelle évolution du PCB.

## Fonctions V0.1.1

- lecture directe du PZEM-004T v3 en Modbus RTU 9600 bauds ;
- tension, courant, puissance active, énergie, fréquence et facteur de puissance ;
- calcul de la puissance apparente et de la puissance non active estimée ;
- validation physique des mesures avant publication ;
- publication MQTT selon `docs/protocols/mqtt-v1.md` ;
- LWT MQTT et état `ONLINE/OFFLINE` ;
- détection automatique d'une session de recharge ;
- statistiques de session ;
- diagnostic périodique ;
- JSON de télémétrie sur USB série ;
- point d'accès Wi-Fi local `VE-SCOPE-borne-01` ;
- mini-interface Web locale et API `/api/status` + `/api/telemetry` ;
- reconnexion Wi-Fi et MQTT non bloquante.

## Cibles PlatformIO

| Environnement | Carte | Usage |
|---|---|---|
| `esp32dev` | ESP32 DevKit / WROOM-32 | **prototype actuel, cible par défaut** |
| `esp32-s3-devkitc-1` | ESP32-S3 DevKitC-1 | évolution future possible |

Un simple `pio run` compile donc l'ESP32 classique.

## Configuration

Copier :

```powershell
Copy-Item include\secrets.example.h include\secrets.h
```

Puis renseigner dans `include/secrets.h` :

- SSID et mot de passe Wi-Fi ;
- IP du broker Mosquitto ;
- identifiants MQTT si activés ;
- mot de passe du point d'accès local.

`include/secrets.h` est ignoré par Git.

## Compilation — ESP32 classique

```powershell
pio run -e esp32dev
```

Téléversement :

```powershell
pio run -e esp32dev -t upload
```

Moniteur série :

```powershell
pio device monitor -b 115200
```

Pour identifier le port avant l'upload :

```powershell
pio device list
```

## Compilation — ESP32-S3, si utilisé plus tard

```powershell
pio run -e esp32-s3-devkitc-1
```

## Broches par défaut

### Prototype ESP32 classique

| Signal | ESP32 classique |
|---|---:|
| PZEM TX -> ESP32 RX2 | GPIO16 |
| ESP32 TX2 -> PZEM RX | GPIO17 |
| Console PC | USB-UART de la carte |

GPIO16/GPIO17 correspondent à l'UART2 couramment utilisé sur les DevKit basés sur ESP32-WROOM-32. Si votre carte est une variante différente, vérifier son marquage avant câblage définitif.

### ESP32-S3 conservé en option

| Signal | ESP32-S3 |
|---|---:|
| PZEM TX -> ESP32 RX | GPIO18 |
| ESP32 TX -> PZEM RX | GPIO17 |

Les broches sont centralisées dans `include/config.h`.

## MQTT

Le firmware publie notamment :

```text
vescope/borne-01/status
vescope/borne-01/telemetry/ac
vescope/borne-01/session/live
vescope/borne-01/session/summary
vescope/borne-01/diagnostics
```

Le Hub déjà validé reçoit ces topics sans modification.

## Test de migration depuis le simulateur

1. arrêter `simulator.py` ;
2. laisser Mosquitto, PostgreSQL et VE-SCOPE Hub actifs ;
3. flasher l'ESP32 classique avec l'environnement `esp32dev` ;
4. vérifier le moniteur série ;
5. vérifier `http://<ip-esp32>/api/telemetry` ;
6. vérifier `/api/v1/devices/borne-01/latest` sur le Hub ;
7. ouvrir Supervisor : il doit rester en `SOURCE HUB`, mais les mesures doivent maintenant provenir du PZEM réel.

## Limites V0.1.1

- les statistiques de session sont en RAM et repartent après un redémarrage ;
- le BLE sera intégré après validation de la chaîne PZEM + MQTT ;
- la page Web embarquée est une interface locale de diagnostic, pas le Supervisor complet ;
- la sécurité MQTT de production (TLS/ACL) viendra avec le déploiement distant ;
- le brochage logique PZEM doit être vérifié électriquement avant le premier raccordement au secteur.
