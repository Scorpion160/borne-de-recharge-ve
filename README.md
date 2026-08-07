# Borne de recharge VE — VE-SCOPE

Projet de conception, instrumentation et supervision d'une borne de recharge pour véhicule électrique, développé dans le cadre du stage de l'équipe projet.

## VE-SCOPE

**VE-SCOPE** est le système de collecte, d'observation et de supervision des paramètres énergétiques de la borne.

Le projet est structuré autour de plusieurs sous-systèmes :

- **VE-SCOPE Core** : acquisition embarquée sur ESP32-S3 et PCB intégré à la borne ;
- **VE-SCOPE Local** : interface locale accessible par Wi-Fi/IP, sans dépendance Internet ;
- **VE-SCOPE Hub** : collecte MQTT, API, stockage et services distants ;
- **VE-SCOPE Supervisor** : interface Web de supervision ;
- **VE-SCOPE Mobile** : accès mobile, notamment via Bluetooth Low Energy ;
- **VE-SCOPE Data** : historisation des mesures, sessions, alarmes et événements.

## Première cible fonctionnelle

La V1 s'appuie sur un **PZEM-004T** raccordé à un **ESP32-S3** pour acquérir :

- tension AC ;
- courant AC ;
- puissance active ;
- facteur de puissance ;
- fréquence ;
- énergie active.

Les données doivent être accessibles simultanément par :

- USB série ;
- Wi-Fi local ;
- MQTT pour la supervision distante ;
- Bluetooth Low Energy.

Le système sera ensuite étendu aux données du **JK BMS**, au futur chargeur rapide DC et à l'architecture énergétique hybride réseau / photovoltaïque / stockage.

## Équipe de stage

- Cheikh Tidiane DIOP
- Oumar DIOP
- El Hadji Abdoukhadre NDIAYE

## État du dépôt

Le dépôt est en cours d'initialisation. Les premières versions du simulateur VE-SCOPE Core, du contrat MQTT et de VE-SCOPE Supervisor seront développées progressivement et validées avant intégration au matériel réel.
