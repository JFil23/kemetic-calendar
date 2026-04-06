#!/usr/bin/env bash
set -euo pipefail

# Ensure the iOS Firebase config is present in Runner/ so Firebase initializes.
# Looks for ios/config/GoogleService-Info.plist by default, or uses
# GOOGLE_SERVICE_INFO to override.

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
IOS_DIR="$ROOT/ios"
DEFAULT_SRC="$IOS_DIR/config/GoogleService-Info.plist"
SRC="${GOOGLE_SERVICE_INFO:-$DEFAULT_SRC}"
DEST="$IOS_DIR/Runner/GoogleService-Info.plist"

# Simulator cannot receive push; don't block sim builds if config is missing.
if [[ "${PLATFORM_NAME:-}" == "iphonesimulator" || "${EFFECTIVE_PLATFORM_NAME:-}" == "-iphonesimulator" ]]; then
  if [[ -f "$SRC" ]]; then
    mkdir -p "$(dirname "$DEST")"
    cp "$SRC" "$DEST"
    echo "🔄 Copied GoogleService-Info.plist for simulator build"
  else
    echo "ℹ️  Skipping Firebase config sync for simulator (no GoogleService-Info.plist found)."
  fi
  exit 0
fi

# If the file is already present in Runner, allow it.
if [[ -f "$DEST" && ! -f "$SRC" ]]; then
  echo "✅ GoogleService-Info.plist already present in Runner (using existing file)"
  exit 0
fi

if [[ ! -f "$SRC" ]]; then
  echo "❌ Missing GoogleService-Info.plist. Place it at $DEFAULT_SRC or set GOOGLE_SERVICE_INFO=/path/to/GoogleService-Info.plist" >&2
  exit 1
fi

mkdir -p "$(dirname "$DEST")"

if cmp -s "$SRC" "$DEST"; then
  echo "✅ GoogleService-Info.plist already synced"
  exit 0
fi

cp "$SRC" "$DEST"
echo "🔄 Copied GoogleService-Info.plist from $SRC"
