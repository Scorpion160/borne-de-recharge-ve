#!/usr/bin/env bash
set -euo pipefail

DOMAIN="${1:-mqtt.vescope.kerunjombor.net}"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERT_DIR="$ROOT/certs"
SRC="/etc/letsencrypt/live/$DOMAIN"

if [[ ! -r "$SRC/fullchain.pem" || ! -r "$SRC/privkey.pem" ]]; then
  echo "Certificat introuvable pour $DOMAIN" >&2
  exit 1
fi

mkdir -p "$CERT_DIR"
cp -L "$SRC/fullchain.pem" "$CERT_DIR/fullchain.pem"
cp -L "$SRC/privkey.pem" "$CERT_DIR/privkey.pem"
chmod 644 "$CERT_DIR/fullchain.pem"
chmod 640 "$CERT_DIR/privkey.pem"

# Eclipse Mosquitto utilise normalement l'UID/GID 1883 dans l'image officielle.
chown 1883:1883 "$CERT_DIR/fullchain.pem" "$CERT_DIR/privkey.pem" 2>/dev/null || true

if docker ps --format '{{.Names}}' | grep -qx vescope_mqtt; then
  docker restart vescope_mqtt >/dev/null
  echo "Certificats synchronisés et vescope_mqtt redémarré."
else
  echo "Certificats synchronisés. Démarrez ensuite vescope_mqtt."
fi
