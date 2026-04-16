#!/usr/bin/env bash
set -euo pipefail

# Validate mobile deep-link entrypoints on a connected device/simulator.
# Usage:
#   scripts/validate_deep_links.sh android [device-id]
#   scripts/validate_deep_links.sh ios [simulator-id|booted]

cd "$(dirname "$0")/.."

PLATFORM="${1:-}"
DEVICE="${2:-}"

if [[ "$PLATFORM" != "android" && "$PLATFORM" != "ios" ]]; then
  echo "Usage: scripts/validate_deep_links.sh <android|ios> [device-id]" >&2
  exit 1
fi

pick_android_device() {
  flutter devices --machine | python - <<'PY'
import json, sys
devices = json.load(sys.stdin)
for d in devices:
    tp = d.get("targetPlatform")
    if isinstance(tp, str) and tp.startswith("android"):
        print(d["id"])
        sys.exit(0)
print("", end="")
PY
}

pick_ios_device() {
  if xcrun simctl list devices booted | grep -q '(Booted)'; then
    echo "booted"
    return
  fi
  echo ""
}

run_android() {
  local device="$1"
  echo "▶ Validating Android deep links on $device"
  adb -s "$device" shell am start -W -a android.intent.action.VIEW -d 'maat://share/share-123?t=test-token'
  adb -s "$device" shell am start -W -a android.intent.action.VIEW -d 'https://maat.app/share/share-123?token=test-token'
  adb -s "$device" shell am start -W -a android.intent.action.VIEW -d 'https://www.maat.app/f/share-short-id'
  adb -s "$device" shell am start -W -a android.intent.action.VIEW -d 'kemet.app://login-callback?code=fake-code'
}

run_ios() {
  local device="$1"
  echo "▶ Validating iOS deep links on $device"
  xcrun simctl openurl "$device" 'maat://share/share-123?t=test-token'
  xcrun simctl openurl "$device" 'https://maat.app/share/share-123?token=test-token'
  xcrun simctl openurl "$device" 'https://www.maat.app/f/share-short-id'
  xcrun simctl openurl "$device" 'kemet.app://login-callback?code=fake-code'
}

is_ios_simulator_target() {
  local device="$1"
  if [[ "$device" == "booted" ]]; then
    return 0
  fi
  xcrun simctl list devices | grep -q -- "$device"
}

if [[ -z "$DEVICE" ]]; then
  if [[ "$PLATFORM" == "android" ]]; then
    DEVICE="$(pick_android_device)"
  else
    DEVICE="$(pick_ios_device)"
  fi
fi

if [[ -z "$DEVICE" ]]; then
  if [[ "$PLATFORM" == "ios" ]]; then
    echo "❌ No booted iOS simulator found. Boot one first, then re-run." >&2
  else
    echo "❌ No $PLATFORM device/simulator found." >&2
  fi
  exit 1
fi

if [[ "$PLATFORM" == "android" ]]; then
  run_android "$DEVICE"
else
  if ! is_ios_simulator_target "$DEVICE"; then
    echo "❌ iOS deep-link validation supports simulators only. Pass a booted simulator or simulator UDID." >&2
    exit 1
  fi
  run_ios "$DEVICE"
fi

cat <<'EOF'

Checklist:
- The app opens for each link without duplicate routing.
- `maat://...` and `https://maat.app/...` routes land on the shared-flow preview.
- `kemet.app://login-callback?...` wakes the app; fake codes may fail auth exchange, but the callback should still be received.
- Universal links require live domain files at:
  - https://maat.app/.well-known/assetlinks.json
  - https://maat.app/.well-known/apple-app-site-association
EOF
