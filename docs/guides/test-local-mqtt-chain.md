# Tester la chaîne locale MQTT de VE-SCOPE

Cette procédure valide le chemin complet :

```text
simulateur -> Mosquitto -> VE-SCOPE Hub -> WebSocket -> VE-SCOPE Supervisor
```

## 1. Mettre le dépôt à jour

```powershell
git switch agent/bootstrap-vescope-supervisor
git pull
```

## 2. Démarrer Mosquitto et VE-SCOPE Hub

Docker Desktop doit être lancé.

```powershell
docker compose -f infrastructure/docker-compose.dev.yml up -d --build
```

Vérifier :

```powershell
docker compose -f infrastructure/docker-compose.dev.yml ps
Invoke-RestMethod http://localhost:8003/health
```

Le endpoint doit retourner `ok=true`. Après démarrage du simulateur, `mqtt_connected` doit être vrai et `mqtt_last_message_at` doit évoluer.

## 3. Démarrer le simulateur VE-SCOPE Core

Dans un nouveau PowerShell :

```powershell
cd simulator\vescope-core
python -m venv .venv
.\.venv\Scripts\Activate.ps1
pip install -r requirements.txt
python simulator.py --broker localhost --port 1883 --device-id borne-01
```

## 4. Vérifier les données reçues par le Hub

```powershell
Invoke-RestMethod http://localhost:8003/api/v1/devices/borne-01/latest
```

Les canaux `status`, `telemetry/ac` et `session/live` doivent apparaître.

## 5. Démarrer Supervisor

Dans un troisième PowerShell :

```powershell
cd frontend\vescope-supervisor
npm install
npm run dev -- --host 0.0.0.0
```

Par défaut, Supervisor tente automatiquement :

```text
ws://<adresse-du-PC>:8003/api/v1/ws/devices/borne-01
```

Si le Hub reçoit une télémétrie récente, elle remplace les valeurs simulées. Si le Hub n'est pas joignable, le frontend continue en simulation pour ne pas bloquer le développement.

## 6. Forcer le mode simulation

Créer un fichier `.env.local` dans `frontend/vescope-supervisor` :

```text
VITE_VESCOPE_DATA_SOURCE=simulation
```

Puis redémarrer Vite.

## 7. Arrêt de la stack

```powershell
docker compose -f infrastructure/docker-compose.dev.yml down
```

## Sécurité

La configuration Mosquitto fournie ici autorise les connexions anonymes uniquement pour le développement local. Elle ne doit pas être exposée sur Internet. Le déploiement distant utilisera comptes MQTT, ACL, TLS et reverse proxy.
