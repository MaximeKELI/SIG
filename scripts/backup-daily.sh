#!/usr/bin/env bash
# Sauvegarde quotidienne PostGIS + médias — cron recommandé (voir docs/SAUVEGARDE.md)
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
BACKUP_DIR="${BACKUP_DIR:-$ROOT/backups}"
STAMP="$(date -u +%Y%m%dT%H%M%SZ)"
COMPOSE=(docker compose -f "$ROOT/docker-compose.yml")
DB_SERVICE="${DB_SERVICE:-db}"
DB_USER="${POSTGRES_USER:-sig_sols}"
DB_NAME="${POSTGRES_DB:-sig_sols}"
RETENTION_DAYS="${RETENTION_DAYS:-14}"

mkdir -p "$BACKUP_DIR"
DUMP_FILE="$BACKUP_DIR/sig_sols_${STAMP}.dump"

echo "[backup] Dump PostGIS → $DUMP_FILE"
"${COMPOSE[@]}" exec -T "$DB_SERVICE" pg_dump -U "$DB_USER" "$DB_NAME" -Fc > "$DUMP_FILE"

MEDIA_VOL=$("${COMPOSE[@]}" volume ls -q | grep media_data | head -1 || true)
if [[ -n "$MEDIA_VOL" ]]; then
  MEDIA_TAR="$BACKUP_DIR/media_${STAMP}.tar.gz"
  echo "[backup] Médias → $MEDIA_TAR"
  docker run --rm -v "${MEDIA_VOL}:/data:ro" -v "$BACKUP_DIR:/backup" alpine \
    tar czf "/backup/media_${STAMP}.tar.gz" -C /data .
fi

echo "[backup] Purge > ${RETENTION_DAYS} jours"
find "$BACKUP_DIR" -type f \( -name 'sig_sols_*.dump' -o -name 'media_*.tar.gz' \) \
  -mtime "+$RETENTION_DAYS" -delete || true

echo "[backup] OK"
ls -lh "$BACKUP_DIR" | tail -n 20
