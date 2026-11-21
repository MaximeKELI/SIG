#!/usr/bin/env bash
# Prépare .env prod, nginx TLS, certificats, mobile/play.release.env
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

CFG="$ROOT/deploy.config"
EXAMPLE="$ROOT/deploy.config.example"
if [[ ! -f "$CFG" ]]; then
  cp "$EXAMPLE" "$CFG"
  echo "Créé $CFG — éditez DOMAIN puis relancez."
  exit 1
fi

# shellcheck disable=SC1090
source "$CFG"

DOMAIN="${DOMAIN:?DOMAIN requis dans deploy.config}"
DOMAIN_WWW="${DOMAIN_WWW:-}"
ADMIN_EMAIL="${ADMIN_EMAIL:-sig-sols@disia.tg}"
TLS_MODE="${TLS_MODE:-selfsigned}"
REPLACE_DOTENV="${REPLACE_DOTENV:-0}"

HOSTS="$DOMAIN"
ORIGINS="https://$DOMAIN"
if [[ -n "$DOMAIN_WWW" ]]; then
  HOSTS="$DOMAIN,$DOMAIN_WWW"
  ORIGINS="https://$DOMAIN,https://$DOMAIN_WWW"
fi
# Healthcheck Docker (Host: 127.0.0.1:8000)
HOSTS="$HOSTS,127.0.0.1,localhost"

SECRET_KEY="$(openssl rand -hex 32)"
POSTGRES_PASSWORD="$(openssl rand -hex 16)"
REDIS_PASSWORD="$(openssl rand -hex 16)"

# Préserver clés API déjà présentes dans .env si possible
preserve() {
  local key="$1"
  if [[ -f "$ROOT/.env" ]]; then
    local v
    v="$(grep -E "^${key}=" "$ROOT/.env" 2>/dev/null | head -1 | cut -d= -f2- || true)"
    printf '%s' "$v"
  fi
}

NASA_U="$(preserve NASA_EARTHDATA_USERNAME)"
NASA_P="$(preserve NASA_EARTHDATA_PASSWORD)"
NASA_T="$(preserve NASA_EARTHDATA_TOKEN)"
SENT_ID="$(preserve SENTINEL_HUB_CLIENT_ID)"
SENT_SEC="$(preserve SENTINEL_HUB_CLIENT_SECRET)"
OWM="$(preserve OPENWEATHER_API_KEY)"
GEM="$(preserve GEMINI_API_KEY)"
GEM_M="$(preserve GEMINI_MODEL)"; GEM_M="${GEM_M:-gemini-2.5-flash-lite}"

ENV_OUT="$ROOT/.env.production"
cat > "$ENV_OUT" <<EOF
# Généré par scripts/prepare-production.sh — ne pas committer
DEBUG=0
SECRET_KEY=$SECRET_KEY
SECURE_SSL_REDIRECT=1
SECURE_HSTS_SECONDS=31536000

ALLOWED_HOSTS=$HOSTS
CSRF_TRUSTED_ORIGINS=$ORIGINS
CORS_ALLOWED_ORIGINS=$ORIGINS

POSTGRES_DB=sig_sols
POSTGRES_USER=sig_sols
POSTGRES_PASSWORD=$POSTGRES_PASSWORD
POSTGRES_HOST=db
POSTGRES_PORT=5432

REDIS_PASSWORD=$REDIS_PASSWORD
REDIS_URL=redis://:${REDIS_PASSWORD}@redis:6379/0
REDIS_CACHE_URL=redis://:${REDIS_PASSWORD}@redis:6379/1
REDIS_CHANNELS_URL=redis://:${REDIS_PASSWORD}@redis:6379/2
CELERY_BROKER_URL=redis://:${REDIS_PASSWORD}@redis:6379/0

SEED_DEMO_DATA=0
JWT_ACCESS_TOKEN_LIFETIME_MINUTES=60

THROTTLE_RATE=100/min
THROTTLE_ANON=200/min
THROTTLE_USER=1000/min
THROTTLE_AUTH=20/min
THROTTLE_ASSISTANT=30/min
MIDDLEWARE_RATE_PER_MIN=300

EMAIL_BACKEND=django.core.mail.backends.smtp.EmailBackend
EMAIL_HOST=smtp.${DOMAIN}
EMAIL_PORT=587
EMAIL_USE_TLS=1
EMAIL_HOST_USER=
EMAIL_HOST_PASSWORD=
DEFAULT_FROM_EMAIL=noreply@${DOMAIN}

NASA_EARTHDATA_USERNAME=${NASA_U}
NASA_EARTHDATA_PASSWORD=${NASA_P}
NASA_EARTHDATA_TOKEN=${NASA_T}
SENTINEL_HUB_CLIENT_ID=${SENT_ID}
SENTINEL_HUB_CLIENT_SECRET=${SENT_SEC}
OPENWEATHER_API_KEY=${OWM}
GEMINI_API_KEY=${GEM}
GEMINI_MODEL=${GEM_M}

SITE_NAME="SIG Sols Togo"
DEFAULT_REGION=maritime
EOF
chmod 600 "$ENV_OUT"
echo "OK → $ENV_OUT"

if [[ "$REPLACE_DOTENV" == "1" ]]; then
  cp "$ENV_OUT" "$ROOT/.env"
  chmod 600 "$ROOT/.env"
  echo "OK → .env remplacé par la prod"
else
  echo "Note : .env dev conservé. Pour déployer : REPLACE_DOTENV=1 ou cp .env.production .env"
fi

# nginx TLS depuis template
WWW_LINE="$DOMAIN_WWW"
if [[ -z "$WWW_LINE" ]]; then
  WWW_LINE="_"
fi
sed -e "s/__DOMAIN__/${DOMAIN}/g" \
    -e "s/__DOMAIN_WWW__/${WWW_LINE}/g" \
    "$ROOT/nginx/nginx-tls.conf.template" > "$ROOT/nginx/nginx-tls.conf"
echo "OK → nginx/nginx-tls.conf"

# Certificats
mkdir -p "$ROOT/nginx/certs"
if [[ ! -f "$ROOT/nginx/certs/fullchain.pem" || ! -f "$ROOT/nginx/certs/privkey.pem" ]]; then
  if [[ "$TLS_MODE" == "selfsigned" ]]; then
    "$ROOT/scripts/setup-tls-certs.sh" --selfsigned "$DOMAIN"
  else
    echo "TLS_MODE=letsencrypt : placez fullchain.pem / privkey.pem dans nginx/certs/"
    echo "  ou lancez : ./scripts/setup-tls-certs.sh --letsencrypt $DOMAIN $ADMIN_EMAIL"
  fi
else
  echo "OK → nginx/certs déjà présents"
fi

# Config mobile Play
PLAY_ENV="$ROOT/mobile/play.release.env"
cat > "$PLAY_ENV" <<EOF
# Généré — utilisé par mobile/scripts/build_play_aab.sh
API_BASE_URL=https://${DOMAIN}/api/v1
PRIVACY_POLICY_URL=https://${DOMAIN}/privacy.html
EOF
chmod 600 "$PLAY_ENV"
echo "OK → $PLAY_ENV"

# Mettre à jour .env.production.example domaine (doc)
echo
echo "=== Production prête (fichiers locaux) ==="
echo "Domaine : https://${DOMAIN}"
echo "Déployer : ./scripts/deploy-prod.sh"
echo "AAB Play : cd mobile && ./scripts/build_play_aab.sh"
