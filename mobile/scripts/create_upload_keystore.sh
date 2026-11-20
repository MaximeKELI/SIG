#!/usr/bin/env bash
# Crée le keystore d'upload Play Store (à garder hors git / hors partage).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ANDROID_DIR="$ROOT/android"
OUT="$ANDROID_DIR/upload-keystore.jks"
PROPS="$ANDROID_DIR/key.properties"

if [[ -f "$OUT" ]]; then
  echo "Déjà présent: $OUT"
  exit 1
fi

echo "Création du keystore d'upload Play Console…"
keytool -genkey -v \
  -keystore "$OUT" \
  -keyalg RSA -keysize 2048 -validity 10000 \
  -alias upload

read -r -s -p "storePassword (celui saisi ci-dessus): " STORE_PASS
echo
read -r -s -p "keyPassword (souvent identique): " KEY_PASS
echo

cat > "$PROPS" <<EOF
storePassword=$STORE_PASS
keyPassword=$KEY_PASS
keyAlias=upload
storeFile=upload-keystore.jks
EOF

chmod 600 "$PROPS" "$OUT"
echo "OK → $OUT"
echo "OK → $PROPS (gitignoré)"
echo "Build AAB: flutter build appbundle --release --dart-define=API_BASE_URL=https://VOTRE-DOMAINE/api/v1"
