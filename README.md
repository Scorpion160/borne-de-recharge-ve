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

## Organisation actuelle

```text
borne-de-recharge-ve/
├── .github/workflows/ci.yml
├── docs/
│   ├── architecture/overview.md
│   └── protocols/mqtt-v1.md
├── frontend/
│   └── vescope-supervisor/
└── simulator/
    └── vescope-core/
```

Les dossiers `hardware`, `firmware`, `backend`, `infrastructure`, `mobile`, `tools` et `tests` seront ajoutés au fur et à mesure que leurs premiers fichiers réels seront créés. Aucun dossier vide artificiel n'est conservé dans Git.

## Démarrage de VE-SCOPE Supervisor

Prérequis : Node.js LTS.

```bash
cd frontend/vescope-supervisor
npm install
npm run dev
```

La V0 démarre en **mode simulation intégré** et permet déjà de parcourir :

- le tableau de bord ;
- les mesures AC ;
- les sessions ;
- les alarmes ;
- le diagnostic.

## Simulateur VE-SCOPE Core

```bash
cd simulator/vescope-core
python -m venv .venv
```

Sous Windows PowerShell :

```powershell
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
python simulator.py --stdout-only
```

Pour publier vers un broker MQTT :

```bash
python simulator.py --broker localhost --port 1883
```

Le contrat MQTT de référence est documenté dans `docs/protocols/mqtt-v1.md`.

## Équipe de stage

- Cheikh Tidiane DIOP
- Oumar DIOP
- El Hadji Abdoukhadre NDIAYE

## Règles de développement

- ne jamais committer de mots de passe, certificats privés ou secrets MQTT ;
- développer les nouvelles fonctions sur des branches dédiées ;
- faire passer la CI avant intégration dans `main` ;
- conserver la compatibilité avec le contrat de données versionné ;
- séparer les fonctions de supervision des fonctions de sécurité électrique.

## Roadmap immédiate

1. stabiliser la V0 de Supervisor ;
2. connecter Supervisor à une passerelle MQTT/API réelle ;
3. développer VE-SCOPE Core sur ESP32-S3 + PZEM-004T ;
4. intégrer la supervision locale autonome ;
5. enregistrer les sessions et alarmes ;
6. ajouter les données JK BMS ;
7. préparer le futur chargeur rapide et l'EMS hybride.
