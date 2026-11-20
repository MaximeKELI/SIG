#!/usr/bin/env bash
# Build AAB signé Play Store (upload keystore + HTTPS API).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
REPO="$(cd "$ROOT/.." && pwd)"
cd "$ROOT"

PLAY_ENV="$ROOT/play.release.env"
if [[ ! -f "$PLAY_ENV" ]]; then
  echo "Manquant : mobile/play.release.env"
  echo "Lancez : ../scripts/prepare-production.sh"
  exit 1
fi
# shellcheck disable=SC1090
source "$PLAY_ENV"

API_BASE_URL="${API_BASE_URL:?}"
PRIVACY_POLICY_URL="${PRIVACY_POLICY_URL:-${API_BASE_URL%/api/v1}/privacy.html}"

if [[ ! "$API_BASE_URL" =~ ^https:// ]]; then
  echo "API_BASE_URL doit être https:// (reçu: $API_BASE_URL)"
  exit 1
fi

if [[ ! -f "$ROOT/android/key.properties" || ! -f "$ROOT/android/upload-keystore.jks" ]]; then
  echo "Keystore manquant — ./scripts/create_upload_keystore.sh"
  exit 1
fi

# Résoudre Flutter (SDK projet, PATH, ou snap décompressé)
resolve_flutter() {
  if [[ -x "$REPO/.tools/flutter/bin/flutter" ]]; then
    echo "$REPO/.tools/flutter/bin/flutter"
    return
  fi
  if command -v flutter >/dev/null 2>&1; then
    # Éviter le wrapper snap cassé
    local p
    p="$(command -v flutter)"
    if [[ "$p" == /snap/bin/flutter ]]; then
      if [[ -x /home/admin20/snap/flutter/common/flutter/bin/flutter ]]; then
        # Snap SDK souvent non inscriptible — préférer .tools
        :
      fi
    else
      echo "$p"
      return
    fi
  fi
  if [[ -x "$HOME/flutter/bin/flutter" ]]; then
    echo "$HOME/flutter/bin/flutter"
    return
  fi
  echo ""
}

FLUTTER="$(resolve_flutter)"
if [[ -z "$FLUTTER" ]]; then
  echo "Flutter introuvable. Installez : ../scripts/install-flutter.sh"
  exit 1
fi

export ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
export ANDROID_SDK_ROOT="${ANDROID_SDK_ROOT:-$ANDROID_HOME}"
export PATH="$ANDROID_HOME/platform-tools:$PATH"

echo "Flutter : $FLUTTER"
"$FLUTTER" --version
"$FLUTTER" pub get

OUT_DIR="$REPO/partage/play"
mkdir -p "$OUT_DIR" "$ROOT/build/debug-info"

echo "Build AAB release → $API_BASE_URL"
"$FLUTTER" build appbundle --release \
  --obfuscate \
  --split-debug-info="$ROOT/build/debug-info" \
  --dart-define="API_BASE_URL=${API_BASE_URL}" \
  --dart-define="PRIVACY_POLICY_URL=${PRIVACY_POLICY_URL}"

AAB="$ROOT/build/app/outputs/bundle/release/app-release.aab"
if [[ ! -f "$AAB" ]]; then
  echo "Échec : AAB introuvable"
  exit 1
fi

STAMP="$(date +%Y%m%d)"
DEST="$OUT_DIR/SIG-Sols-Togo-${STAMP}-play.aab"
cp -f "$AAB" "$DEST"
cp -f "$AAB" "$OUT_DIR/SIG-Sols-Togo-latest-play.aab"

cat > "$OUT_DIR/README.txt" <<EOF
SIG Sols Togo — Android App Bundle (Play Store)
================================================
Fichier     : $(basename "$DEST")
Package     : tg.dusol.sig_sols_mobile
API         : ${API_BASE_URL}
Privacy     : ${PRIVACY_POLICY_URL}
Signé avec  : android/upload-keystore.jks (NE PAS perdre)
Date        : ${STAMP}

Upload
------
1. Play Console → Application → Production (ou test interne)
2. Créer une version → uploader $(basename "$DEST")
3. Data Safety : localisation, photos/médias, analytics (consentement)
4. Lien politique : ${PRIVACY_POLICY_URL}

Assets listing : mobile/store/
EOF

echo
echo "OK → $DEST"
echo "OK → $OUT_DIR/SIG-Sols-Togo-latest-play.aab"
ls -lh "$DEST"
