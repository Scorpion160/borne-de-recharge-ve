# Architecture VE-SCOPE

## Objectif

VE-SCOPE doit superviser la borne sans dépendre d'un unique capteur ou d'un unique moyen de communication. L'architecture est donc organisée autour d'un modèle générique de borne et non autour du PZEM-004T.

## Sous-systèmes

```text
PZEM-004T ─────┐
JK BMS ────────┤
Chargeur DC ───┤──> VE-SCOPE Core ──> Wi-Fi / MQTT / BLE / USB
Capteurs ──────┘                         │
                                        ├──> VE-SCOPE Local
                                        └──> VE-SCOPE Hub ──> VE-SCOPE Supervisor
```

### VE-SCOPE Core

Carte embarquée dans la borne, basée initialement sur ESP32-S3. Responsabilités :

- acquisition PZEM-004T par UART/Modbus RTU ;
- calcul des grandeurs dérivées ;
- détection des sessions de charge ;
- publication MQTT ;
- interface locale ;
- BLE ;
- USB série ;
- gestion des pertes de communication ;
- diagnostics locaux.

### VE-SCOPE Local

Interface autonome accessible sur le réseau local ou sur le point d'accès de secours de l'ESP32. Elle doit rester utilisable sans Internet.

### VE-SCOPE Hub

Couche serveur destinée à recevoir les données MQTT, historiser la télémétrie, gérer les sessions, les alarmes, les utilisateurs et exposer une API à l'interface distante.

### VE-SCOPE Supervisor

Interface Web de supervision destinée aux opérateurs et ingénieurs. La V0 démarre en mode simulation avant connexion au Hub.

## Sources de données

### V1 — AC

Source : PZEM-004T.

- tension RMS ;
- courant RMS ;
- puissance active ;
- facteur de puissance ;
- fréquence ;
- énergie active cumulée.

Grandeurs calculées :

- puissance apparente : `S = U × I` ;
- puissance non active estimée : `sqrt(max(S² - P², 0))` ;
- énergie de session ;
- statistiques min/max/moyenne.

### V1.1 — Batterie

Source prévue : JK BMS.

- tension pack ;
- courant batterie ;
- SOC ;
- températures ;
- tensions cellules ;
- delta cellules ;
- états charge/décharge/équilibrage ;
- alarmes.

### V2 — Chargeur rapide et énergie hybride

- consignes tension/courant ;
- puissance DC ;
- limites BMS, thermiques et convertisseur ;
- températures du chargeur ;
- rendement AC/DC ;
- production photovoltaïque ;
- stockage stationnaire ;
- réseau ;
- stratégie EMS.

## Principes de sûreté

VE-SCOPE est un système de mesure, de supervision et de diagnostic. Il ne remplace jamais les protections électriques matérielles, le BMS, le disjoncteur, la protection différentielle ou les sécurités intrinsèques du chargeur.

Une donnée absente ou périmée ne doit jamais être présentée comme une valeur nulle valide. Chaque donnée doit porter un état de qualité : `GOOD`, `STALE`, `INVALID`, `UNAVAILABLE` ou `ESTIMATED`.
