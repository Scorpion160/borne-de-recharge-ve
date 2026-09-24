#!/usr/bin/env bash
# Sauvegarde PostgreSQL vérifiée, sans modifier la base active.
set -euo pipefail

backup_dir="${VESCOPE_BACKUP_DIR:-/opt/vescope/backups/postgres}"
mkdir -p "$backup_dir"
chmod 700 "$backup_dir"

exec 9>"$backup_dir/.backup.lock"
flock -n 9 || { echo 'Sauvegarde déjà en cours' >&2; exit 1; }

target="$backup_dir/vescope-$(date -u +%Y%m%dT%H%M%SZ).dump"
temp=$(mktemp "$backup_dir/.vescope-XXXXXX.dump")
trap 'rm -f "$temp"' EXIT
chmod 600 "$temp"

docker exec vescope_postgres pg_dump -U vescope -d vescope -Fc > "$temp"
test -s "$temp"
# Lire et décompresser le dump en entier pour détecter un fichier tronqué.
docker exec -i vescope_postgres pg_restore --data-only -f /dev/null < "$temp"
mv "$temp" "$target"
trap - EXIT
echo "Sauvegarde vérifiée : $target"
