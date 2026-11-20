#!/usr/bin/env bash
# Déploie la stack web en mode production (Docker Compose overlay).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if [[ ! -f "$ROOT/deploy.config" ]]; then
  echo "Manquant : deploy.config — lancez d'abord ./scripts/prepare-production.sh"
  exit 1
fi

# shellcheck disable=SC1091
source "$ROOT/deploy.config"

if [[ ! -f "$ROOT/.env.production" ]]; then
  echo "Génération des fichiers prod…"
  "$ROOT/scripts/prepare-production.sh"
fi

if [[ ! -f "$ROOT/nginx/nginx-tls.conf" ]]; then
  echo "Manquant : nginx/nginx-tls.conf — relancez prepare-production.sh"
  exit 1
fi

if [[ ! -f "$ROOT/nginx/certs/fullchain.pem" || ! -f "$ROOT/nginx/certs/privkey.pem" ]]; then
  echo "Manquant : nginx/certs/*.pem — ./scripts/setup-tls-certs.sh --selfsigned \$DOMAIN"
  exit 1
fi

# Activer .env prod pour Compose (sauvegarde le .env dev si présent)
if [[ -f "$ROOT/.env" && ! -f "$ROOT/.env.development.bak" ]]; then
  cp "$ROOT/.env" "$ROOT/.env.development.bak"
  echo "Sauvegarde .env → .env.development.bak"
fi
cp "$ROOT/.env.production" "$ROOT/.env"
chmod 600 "$ROOT/.env"

echo "Build + démarrage production…"
docker compose -f docker-compose.yml -f docker-compose.prod.yml up -d --build

echo
echo "Attente health…"
for i in $(seq 1 30); do
  if curl -skf "https://127.0.0.1/health/" -H "Host: ${DOMAIN}" >/dev/null 2>&1 \
     || curl -sf "http://127.0.0.1/health/" >/dev/null 2>&1; then
    echo "OK health"
    break
  fi
  sleep 2
  if [[ "$i" -eq 30 ]]; then
    echo "Health pas encore prêt — vérifiez : docker compose -f docker-compose.yml -f docker-compose.prod.yml logs"
  fi
done

echo
echo "=== Déploiement lancé ==="
echo "URL    : https://${DOMAIN}"
echo "Health : https://${DOMAIN}/health/"
echo "Privacy: https://${DOMAIN}/privacy.html"
echo "Logs   : docker compose -f docker-compose.yml -f docker-compose.prod.yml logs -f"
echo
echo "Restaurer le .env de dev : cp .env.development.bak .env"
