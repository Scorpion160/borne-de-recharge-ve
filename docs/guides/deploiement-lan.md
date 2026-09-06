# Déploiement VE-SCOPE sur le réseau local

Cette stack remplace Vite et les processus lancés manuellement. Elle déploie :

```text
ESP32 -> MQTT/Mosquitto -> VE-SCOPE Hub -> PostgreSQL
                              |
                              +-> Nginx -> VE-SCOPE Supervisor
```

## Démarrage

Depuis la racine du dépôt :

```powershell
git switch agent/bootstrap-vescope-supervisor
git pull
docker compose -f infrastructure/docker-compose.lan.yml up -d --build
```

Vérifier :

```powershell
docker compose -f infrastructure/docker-compose.lan.yml ps
Invoke-RestMethod http://localhost:8080/health
```

L'interface est disponible sur :

```text
http://localhost:8080
```

et depuis un autre appareil du même réseau :

```text
http://IP_DU_PC:8080
```

Le Supervisor utilise la même origine HTTP pour REST et WebSocket ; aucun port 8003 n'est nécessaire côté utilisateur.

## Data logger

PostgreSQL est le journal principal. La page **Données** permet de télécharger :

- télémétrie AC CSV sur 1 h, 24 h, 7 j ou 30 j ;
- sessions de recharge CSV ;
- alarmes et événements CSV.

Les exports 1 h et 24 h sont bruts. Les exports 7 j et 30 j sont agrégés pour conserver une taille raisonnable.

## Sauvegarde PostgreSQL

Créer un dump binaire :

```powershell
New-Item -ItemType Directory -Force .\backups | Out-Null
docker exec vescope_postgres pg_dump -U vescope -d vescope -Fc -f /tmp/vescope.dump
docker cp vescope_postgres:/tmp/vescope.dump .\backups\vescope.dump
```

Le volume `vescope_postgres_data` conserve les données lors des redémarrages et reconstructions des conteneurs.

## Arrêt

```powershell
docker compose -f infrastructure/docker-compose.lan.yml down
```

Ne pas utiliser `down -v` sauf si l'objectif est de supprimer volontairement toutes les données.

## Limite sécurité

Cette stack est destinée au réseau local de développement/atelier. Le broker MQTT 1883 n'est pas chiffré et le Hub ne possède pas encore d'authentification utilisateur. Ne pas exposer directement les ports 1883 ou 8080 sur Internet.

Avant un déploiement Internet : authentification applicative, comptes/ACL MQTT, TLS, HTTPS et politique de sauvegarde automatisée sont obligatoires.
