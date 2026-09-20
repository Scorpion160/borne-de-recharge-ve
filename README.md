# Borne de recharge VE — VE-SCOPE

Projet de conception, instrumentation et supervision d'une borne de recharge pour véhicule électrique, développé dans le cadre du stage de l'équipe projet.

## VE-SCOPE

**VE-SCOPE** est le système de collecte, d'observation et de supervision des paramètres énergétiques de la borne.

Le projet est structuré autour de plusieurs sous-systèmes :

- **VE-SCOPE Core** : acquisition embarquée sur ESP32 et PCB intégré à la borne ;
- **VE-SCOPE Local** : interface locale accessible par Wi-Fi/IP, sans dépendance Internet ;
- **VE-SCOPE Hub** : collecte MQTT/HTTPS, API, stockage et services distants ;
- **VE-SCOPE Supervisor** : interface Web de supervision ;
- **VE-SCOPE Data** : historisation des mesures, sessions, alarmes et événements.

## Acquisition réelle de la borne

La chaîne actuellement utilisée sur la borne repose sur un **PZEM-004T** raccordé à un **ESP32** pour acquérir les mesures réelles suivantes :

- tension AC ;
- courant AC ;
- puissance active ;
- facteur de puissance ;
- fréquence ;
- énergie active.

Les données sont accessibles par :

- USB série ;
- Wi-Fi local ;
- HTTPS/MQTT pour la supervision distante ;
- Bluetooth Low Energy.

La supervision distante utilise les données réelles émises par **VE-SCOPE Core**. Le simulateur utilisé pendant la phase de développement initiale a été retiré de l'architecture de production.

Le système sera ensuite étendu aux données du **JK BMS**, au futur chargeur rapide DC et à l'architecture énergétique hybride réseau / photovoltaïque / stockage.

## Organisation actuelle

```text
borne-de-recharge-ve/
├── backend/
│   ├── vescope-hub/
│   └── vescope-ingest/
├── docs/
├── firmware/
│   └── vescope-core-esp32/
├── frontend/
│   └── vescope-supervisor/
├── infrastructure/
└── scripts/
```

## VE-SCOPE Supervisor

Le Supervisor consomme les API du Hub et affiche les données réelles de la borne :

- tableau de bord ;
- mesures AC ;
- sessions de recharge ;
- alarmes ;
- diagnostic ;
- historique et exports.

Démarrage local du frontend :

```bash
cd frontend/vescope-supervisor
npm install
npm run dev
```

Le contrat de données est documenté dans `docs/protocols/mqtt-v1.md`.

## Équipe de stage

- Cheikh Tidiane DIOP
- Oumar DIOP
- El Hadji Abdoukhadre NDIAYE

## Règles de développement

- ne jamais committer de mots de passe, certificats privés ou secrets MQTT ;
- développer les nouvelles fonctions sur des branches dédiées ;
- valider localement les builds et tests avant déploiement ;
- conserver la compatibilité avec le contrat de données versionné ;
- séparer les fonctions de supervision des fonctions de sécurité électrique.

## Roadmap immédiate

1. stabiliser VE-SCOPE Core et la conservation durable des données terrain ;
2. fiabiliser la continuité des sessions lors des coupures réseau et redémarrages ;
3. finaliser VE-SCOPE Supervisor sur les données réelles ;
4. intégrer les données JK BMS ;
5. préparer le futur chargeur rapide et l'EMS hybride.
