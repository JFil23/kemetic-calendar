#!/usr/bin/env bash
set -euo pipefail

# Runs Flutter with a consistent set of dart-defines from env/dev.json.
# Usage:
#   scripts/run_dev.sh               # auto-pick a device
#   scripts/run_dev.sh <device_id>   # target a specific device (see `flutter devices`)

cd "$(dirname "$0")/.."

ENV_FILE="env/dev.json"
[[ -f "$ENV_FILE" ]] || { echo "⚠️  $ENV_FILE not found. Copy or create it with your SUPABASE_URL / SUPABASE_ANON_KEY (and any other defines)." >&2; exit 1; }

readarray -t ENV_INFO < <(python - <<'PY' "$ENV_FILE"
import json, sys
path = sys.argv[1]
try:
    with open(path) as f:
        data = json.load(f)
except Exception as e:
    print(f"Failed to read {path}: {e}", file=sys.stderr)
    sys.exit(1)
url = data.get("SUPABASE_URL", "")
anon = data.get("SUPABASE_ANON_KEY", "")
def mask(k: str) -> str:
    if not k:
        return ""
    return f"{len(k)} chars ({k[:4]}...{k[-4:]})"
print(url)
print(mask(anon))
PY
)
SUPABASE_URL="${ENV_INFO[0]:-}"
ANON_MASK="${ENV_INFO[1]:-}"

DEVICE="${1:-}"

echo "▶️  Running with $ENV_FILE (SUPABASE_URL=$SUPABASE_URL, ANON=$ANON_MASK) ${DEVICE:+device=$DEVICE}"

if [[ -n "$DEVICE" ]]; then
  flutter run --dart-define-from-file="$ENV_FILE" -d "$DEVICE"
else
  flutter run --dart-define-from-file="$ENV_FILE"
fi
