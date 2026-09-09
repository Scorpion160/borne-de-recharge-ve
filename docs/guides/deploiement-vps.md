# Déploiement public VE-SCOPE sur VPS

Architecture de test :

```text
Internet -> HTTPS 443 -> Nginx hôte -> 127.0.0.1:8010 -> Supervisor
                                                  |
                                                  +-> Hub
                                                       |
                                                       +-> PostgreSQL
                                                       +-> Mosquitto interne
```

Le port MQTT n'est pas exposé à Internet dans cette première étape. Le profil `simulation` permet de tester l'interface publique depuis n'importe quel réseau.

## DNS

Créer un enregistrement A :

```text
vescope.kerunjombor.net -> 84.247.135.81
```

## Variables

Copier `infrastructure/.env.vps.example` vers `infrastructure/.env.vps` et remplacer le mot de passe PostgreSQL.

## Docker

```bash
cd /opt/vescope/infrastructure
docker compose --env-file .env.vps -f docker-compose.vps.yml config --quiet
docker compose --env-file .env.vps -f docker-compose.vps.yml up -d --build
```

Pour activer les données simulées :

```bash
docker compose --env-file .env.vps -f docker-compose.vps.yml --profile simulation up -d --build simulator
```

## Nginx et HTTPS

Installer si nécessaire :

```bash
apt-get update
apt-get install -y nginx certbot python3-certbot-nginx apache2-utils
mkdir -p /var/www/certbot
```

Copier d'abord `infrastructure/nginx/vescope.bootstrap.conf` vers `/etc/nginx/sites-available/vescope` puis l'activer.

```bash
ln -sfn /etc/nginx/sites-available/vescope /etc/nginx/sites-enabled/vescope
nginx -t && systemctl reload nginx
certbot certonly --webroot -w /var/www/certbot -d vescope.kerunjombor.net
```

Créer ensuite le compte de test HTTP Basic :

```bash
htpasswd -c /etc/nginx/vescope.htpasswd vescope
```

Remplacer enfin le site par `infrastructure/nginx/vescope.kerunjombor.net.conf`, puis :

```bash
nginx -t && systemctl reload nginx
```

Tester :

```bash
curl -I http://127.0.0.1:8010
curl -u vescope https://vescope.kerunjombor.net/health
```

## Sauvegarde PostgreSQL

```bash
mkdir -p /opt/vescope/backups
docker exec vescope_postgres pg_dump -U vescope -d vescope -Fc -f /tmp/vescope.dump
docker cp vescope_postgres:/tmp/vescope.dump /opt/vescope/backups/vescope-$(date +%F-%H%M).dump
```

Ne jamais utiliser `docker compose down -v` en exploitation normale.
