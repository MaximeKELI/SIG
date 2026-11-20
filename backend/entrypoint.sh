#!/bin/sh
set -e

if [ -f /opt/dusol.env ]; then
  set -a
  # shellcheck disable=SC1091
  . /opt/dusol.env
  set +a
fi

echo "==> Migrations PostGIS..."
python manage.py migrate --noinput

if [ "${RUN_MAKEMIGRATIONS:-0}" = "1" ]; then
  python manage.py makemigrations --noinput 2>/dev/null || true
fi

echo "==> Fichiers statiques..."
python manage.py collectstatic --noinput

# Prod : SEED_DEMO_DATA=0 (défaut). Dev : SEED_DEMO_DATA=1
if [ "${SEED_DEMO_DATA:-0}" = "1" ]; then
  echo "==> Données démo (si base vide)..."
  python manage.py seed_demo_data 2>/dev/null || true
else
  echo "==> Seed démo ignoré (SEED_DEMO_DATA!=1)"
fi

if [ "$#" -gt 0 ]; then
  echo "==> Commande personnalisée: $*"
  exec "$@"
fi

echo "==> Démarrage Gunicorn..."
exec gunicorn config.wsgi:application \
  --bind 0.0.0.0:8000 \
  --workers "${GUNICORN_WORKERS:-2}" \
  --threads 2 \
  --timeout 120 \
  --access-logfile - \
  --error-logfile -
