#!/usr/bin/env bash
set -euo pipefail

# Run on the first available Android device/emulator using env/dev.json.
# Usage:
#   scripts/run_android.sh            # auto-picks Android device
#   scripts/run_android.sh <device>   # specify device id

cd "$(dirname "$0")/.."

ENV_FILE="${ENV_FILE:-env/dev.json}"
[[ -f "$ENV_FILE" ]] || { echo "⚠️  $ENV_FILE not found. Copy or create it with your SUPABASE_URL / SUPABASE_ANON_KEY (and any other defines)." >&2; exit 1; }

if [[ $# -gt 0 ]]; then
  DEVICE="$1"
else
  DEVICE=$(flutter devices --machine | python - <<'PY'
import json, sys
devices = json.load(sys.stdin)
for d in devices:
    if isinstance(d.get("targetPlatform"), str) and d["targetPlatform"].startswith("android"):
        print(d["id"])
        sys.exit(0)
print("", end="")
PY
)
fi

if [[ -z "${DEVICE:-}" ]]; then
  echo "❌ No Android device/emulator found. Start one (e.g., emulator) or plug in a device, then re-run." >&2
  exit 1
fi

readarray -t ENV_INFO < <(python - <<'PY' "$ENV_FILE"
import json, sys
path = sys.argv[1]
with open(path) as f:
    data = json.load(f)
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

echo "▶️  Running on Android device $DEVICE with $ENV_FILE (SUPABASE_URL=$SUPABASE_URL, ANON=$ANON_MASK)"
flutter run --dart-define-from-file="$ENV_FILE" -d "$DEVICE"
