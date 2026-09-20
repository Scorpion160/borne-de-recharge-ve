# MQTT TLS terrain — VE-SCOPE

## DNS

Créer dans Cloudflare :

```text
A  mqtt.vescope  84.247.135.81  DNS only
```

Ne pas activer le proxy orange pour ce sous-domaine MQTT sauf utilisation de Cloudflare Spectrum.

## Certificat

Activer temporairement le vhost HTTP :

```bash
cp /opt/vescope/infrastructure/nginx/mqtt.bootstrap.conf /etc/nginx/sites-available/vescope-mqtt
ln -sfn /etc/nginx/sites-available/vescope-mqtt /etc/nginx/sites-enabled/vescope-mqtt
nginx -t && systemctl reload nginx
certbot certonly --webroot -w /var/www/certbot -d mqtt.vescope.kerunjombor.net
```

## Secrets Mosquitto

```bash
cd /opt/vescope/infrastructure
mkdir -p mosquitto/secrets mosquitto/certs
cp mosquitto/acl.example mosquitto/secrets/acl
MQTTPASS=$(openssl rand -hex 24)
rm -f mosquitto/secrets/passwords
docker run --rm -v "$PWD/mosquitto/secrets:/work" eclipse-mosquitto:2 \
  mosquitto_passwd -b -c /work/passwords borne-01 "$MQTTPASS"
chown 1883:1883 mosquitto/secrets/passwords mosquitto/secrets/acl
chmod 640 mosquitto/secrets/passwords mosquitto/secrets/acl
```

Conserver la valeur de `MQTTPASS` dans un gestionnaire de secrets. Elle doit ensuite être placée dans `firmware/vescope-core-esp32/include/secrets.h` sur le poste de développement.

## Certificats Mosquitto

```bash
chmod +x mosquitto/sync-certs.sh
./mosquitto/sync-certs.sh mqtt.vescope.kerunjombor.net
```

## Stack

```bash
docker compose --env-file .env.vps \
  -f docker-compose.vps.yml \
  -f docker-compose.mqtt-tls.yml \
  up -d --build mqtt hub supervisor
docker compose --env-file .env.vps \
  -f docker-compose.vps.yml \
  -f docker-compose.mqtt-tls.yml \
  ps
```

Le port public doit être `8883/tcp`. Le listener `1883` reste uniquement dans le réseau Docker et n’est pas publié sur l’hôte. Sans l’override `docker-compose.mqtt-tls.yml`, le broker reste volontairement en mode interne afin qu’un certificat manquant ne casse pas le Hub et le simulateur.

## Test TLS depuis le VPS

```bash
openssl s_client -connect mqtt.vescope.kerunjombor.net:8883 -servername mqtt.vescope.kerunjombor.net </dev/null
```

Puis test MQTT authentifié avec un conteneur client :

```bash
docker run --rm eclipse-mosquitto:2 mosquitto_pub \
  -h mqtt.vescope.kerunjombor.net -p 8883 \
  --cafile /etc/ssl/certs/ca-certificates.crt \
  -u borne-01 -P "$MQTTPASS" \
  -t vescope/borne-01/diagnostics \
  -m '{"schema":1,"device_id":"borne-01","source":"mqtt-tls-test"}'
```

## Renouvellement

Après renouvellement Let's Encrypt, resynchroniser les certificats puis redémarrer Mosquitto :

```bash
/opt/vescope/infrastructure/mosquitto/sync-certs.sh mqtt.vescope.kerunjombor.net
```

Un hook Certbot peut appeler cette commande automatiquement.

## Firmware ESP32

Le fichier `secrets.h` doit contenir :

```cpp
#define VESCOPE_MQTT_HOST "mqtt.vescope.kerunjombor.net"
#define VESCOPE_MQTT_PORT 8883
#define VESCOPE_MQTT_TLS 1
#define VESCOPE_MQTT_USER "borne-01"
#define VESCOPE_MQTT_PASSWORD "..."
```

Sur Windows, générer le CA racine :

```powershell
.\scripts\fetch-mqtt-ca.ps1
```

Puis compiler et téléverser :

```powershell
cd firmware\vescope-core-esp32
pio run -e esp32dev
pio run -e esp32dev -t upload --upload-port COMx
```
