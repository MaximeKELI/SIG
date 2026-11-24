#!/usr/bin/env bash
# Lance l’app avec le Flutter du repo (jamais le snap cassé).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
FLUTTER="$ROOT/.tools/flutter/bin/flutter"
MOBILE="$(cd "$(dirname "$0")" && pwd)"
cd "$MOBILE"

if [[ ! -x "$FLUTTER" ]]; then
  echo "Flutter introuvable: $FLUTTER" >&2
  exit 1
fi

# Force le SDK du projet (ignore /snap/bin/flutter)
export PATH="$(dirname "$FLUTTER"):$PATH"
export CMAKE_MAKE_PROGRAM="${CMAKE_MAKE_PROGRAM:-/usr/bin/ninja}"
hash -r 2>/dev/null || true

DEVICE="${1:-}"

echo "→ Flutter: $($FLUTTER --version 2>/dev/null | head -1)"
echo "→ SDK:    $FLUTTER"

# Purge cache CMake qui pointe encore vers le ninja du snap
if grep -Rqs '/snap/flutter' build/linux 2>/dev/null \
  || grep -Rqs '/snap/flutter' linux/flutter/ephemeral 2>/dev/null; then
  echo "→ Nettoyage cache Linux (références snap)…"
  rm -rf build/linux
fi

if [[ -z "$DEVICE" ]]; then
  if "$FLUTTER" devices 2>/dev/null | grep -q 'chrome •'; then
    DEVICE=chrome
  else
    DEVICE=linux
  fi
fi

if [[ "$DEVICE" == "linux" ]]; then
  if ! pkg-config --exists libsecret-1 2>/dev/null; then
    echo "⚠ Manque libsecret-1. Installe: sudo apt-get install -y libsecret-1-dev libjsoncpp-dev"
    exit 1
  fi
  # Rebuild propre si le dernier build a échoué
  rm -rf build/linux
fi

exec "$FLUTTER" run -d "$DEVICE"
