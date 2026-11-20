#!/usr/bin/env bash
# Installe Flutter SDK stable dans .tools/flutter (hors snap).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
DEST="$ROOT/.tools/flutter"
mkdir -p "$ROOT/.tools"

if [[ -x "$DEST/bin/flutter" ]]; then
  echo "Déjà installé : $DEST"
  "$DEST/bin/flutter" --version
  exit 0
fi

TMP="$ROOT/.tools/flutter-sdk.tar.xz"
URL="https://storage.googleapis.com/flutter_infra_release/releases/stable/linux/flutter_linux_3.35.7-stable.tar.xz"

echo "Téléchargement Flutter stable…"
if command -v curl >/dev/null 2>&1; then
  curl -L --fail --retry 3 -o "$TMP" "$URL"
else
  wget -O "$TMP" "$URL"
fi

echo "Extraction…"
rm -rf "$DEST"
tar -xJf "$TMP" -C "$ROOT/.tools"
# L'archive crée un dossier "flutter"
if [[ ! -d "$DEST" && -d "$ROOT/.tools/flutter" ]]; then
  :
elif [[ -d "$ROOT/.tools/flutter" ]]; then
  :
fi
rm -f "$TMP"

export ANDROID_HOME="${ANDROID_HOME:-$HOME/Android/Sdk}"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
"$DEST/bin/flutter" config --no-analytics
"$DEST/bin/flutter" precache --android
"$DEST/bin/flutter" doctor -v || true
echo "OK → $DEST/bin/flutter"
echo "Ajoutez au PATH : export PATH=\"$DEST/bin:\$PATH\""
