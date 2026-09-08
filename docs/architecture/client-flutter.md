# VE-SCOPE — client Flutter multiplateforme

## Principe

`frontend/vescope` est le client unique VE-SCOPE. Il cible Web, Android et iOS avec le même code Dart.

`frontend/vescope-supervisor` reste temporairement comme référence fonctionnelle pendant la migration puis sera retiré lorsque la parité sera atteinte.

## Modes de transport

Le client ne dépend pas d'un seul réseau. Un orchestrateur sélectionne la meilleure source disponible :

```text
1. CLOUD      HTTPS + WebSocket -> VPS / VE-SCOPE Hub
2. LOCAL_WIFI HTTP -> ESP32, 192.168.4.1 ou vescope-borne-01.local
3. BLE        GATT -> ESP32
```

Priorité normale : Cloud. Si le cloud n'est pas joignable, tester l'API locale. Si elle n'est pas joignable, proposer/rechercher BLE.

Le mode actif doit toujours être visible dans l'interface.

## Fonctions à porter depuis le Supervisor actuel

- Vue générale ;
- Mesures AC ;
- Historique ;
- Data Logger / export CSV ;
- Sessions ;
- Alarmes ;
- Diagnostic ;
- Paramètres ;
- thème clair/sombre.

## Fonctions spécifiques Flutter

- découverte BLE et connexion à `VE-SCOPE-borne-01` ;
- notifications BLE de télémétrie/statut ;
- détection de l'API locale `http://192.168.4.1` ;
- ouverture de la page OTA locale ;
- accès Cloud au même Hub REST/WebSocket ;
- téléchargement et partage des CSV ;
- stockage local des préférences et du dernier mode utilisé.

## BLE GATT VE-SCOPE Core

Service : `8f110000-6c4d-4f62-9ca8-7ef24ec70001`

- telemetry READ/NOTIFY : `8f110001-6c4d-4f62-9ca8-7ef24ec70001` ;
- status READ/NOTIFY : `8f110002-6c4d-4f62-9ca8-7ef24ec70001` ;
- info READ : `8f110003-6c4d-4f62-9ca8-7ef24ec70001`.

Les payloads télémétrie/statut reprennent le JSON `schema: 1` du contrat MQTT.

## Dépendances Flutter prévues

- `http` ;
- `web_socket_channel` ;
- `flutter_blue_plus` ;
- `shared_preferences` ;
- `fl_chart` ;
- `dio` ;
- `path_provider` ;
- `share_plus` ;
- `url_launcher`.

Les fonctions BLE doivent être isolées derrière une interface pour que Flutter Web puisse compiler même lorsque BLE n'est pas disponible dans le navigateur.

## Déploiement Web

Le build `flutter build web --release` remplacera le build React dans l'image Nginx de VE-SCOPE lorsque la parité fonctionnelle sera validée.
