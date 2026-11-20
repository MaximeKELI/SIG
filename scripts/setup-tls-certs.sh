#!/usr/bin/env bash
# Génère ou oriente les certificats TLS pour nginx/certs/
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CERT_DIR="$ROOT/nginx/certs"
mkdir -p "$CERT_DIR"

MODE="${1:---selfsigned}"
DOMAIN="${2:-sig-sols.tg}"
EMAIL="${3:-sig-sols@disia.tg}"

case "$MODE" in
  --selfsigned)
    echo "Certificat auto-signé pour $DOMAIN (dev / smoke-test — pas pour Play Store public)…"
    openssl req -x509 -nodes -newkey rsa:2048 -days 825 \
      -keyout "$CERT_DIR/privkey.pem" \
      -out "$CERT_DIR/fullchain.pem" \
      -subj "/CN=${DOMAIN}/O=DUSOL SIG Sols Togo/C=TG" \
      -addext "subjectAltName=DNS:${DOMAIN},DNS:www.${DOMAIN},DNS:localhost"
    chmod 600 "$CERT_DIR/privkey.pem"
    chmod 644 "$CERT_DIR/fullchain.pem"
    echo "OK → $CERT_DIR/fullchain.pem + privkey.pem"
    echo "Attention : les apps mobiles Play Store exigent un certificat CA public (Let's Encrypt)."
    ;;
  --letsencrypt)
    if ! command -v certbot >/dev/null 2>&1; then
      echo "Installez certbot, puis :"
      echo "  sudo certbot certonly --standalone -d ${DOMAIN} -d www.${DOMAIN} -m ${EMAIL} --agree-tos"
      echo "  sudo cp /etc/letsencrypt/live/${DOMAIN}/fullchain.pem $CERT_DIR/"
      echo "  sudo cp /etc/letsencrypt/live/${DOMAIN}/privkey.pem $CERT_DIR/"
      echo "  sudo chown \"\$USER:\$USER\" $CERT_DIR/*.pem"
      exit 1
    fi
    echo "Lancement certbot (nécessite ports 80 libres + DNS pointant ici)…"
    sudo certbot certonly --standalone -d "$DOMAIN" -d "www.${DOMAIN}" \
      -m "$EMAIL" --agree-tos --non-interactive
    sudo cp "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" "$CERT_DIR/"
    sudo cp "/etc/letsencrypt/live/${DOMAIN}/privkey.pem" "$CERT_DIR/"
    sudo chown "$(id -u):$(id -g)" "$CERT_DIR/fullchain.pem" "$CERT_DIR/privkey.pem"
    chmod 600 "$CERT_DIR/privkey.pem"
    echo "OK → certificats Let's Encrypt copiés"
    ;;
  *)
    echo "Usage: $0 --selfsigned [domaine] | --letsencrypt [domaine] [email]"
    exit 1
    ;;
esac
