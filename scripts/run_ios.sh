#!/usr/bin/env bash
set -euo pipefail

# Run on the first available iOS device (physical or simulator) using env/dev.json.
# Usage:
#   scripts/run_ios.sh            # auto-picks iOS device
#   scripts/run_ios.sh <device>   # specify device id
#
# Compatible with macOS /bin/bash 3.2 (no readarray).

cd "$(dirname "$0")/.."

ENV_FILE="${ENV_FILE:-env/dev.json}"
[[ -f "$ENV_FILE" ]] || { echo "⚠️  $ENV_FILE not found. Copy or create it with your SUPABASE_URL / SUPABASE_ANON_KEY (and any other defines)." >&2; exit 1; }

# Prefer python3 on macOS; fall back to python when present.
if command -v python3 >/dev/null 2>&1; then
  PYTHON=python3
elif command -v python >/dev/null 2>&1; then
  PYTHON=python
else
  echo "❌ python3 (or python) is required to parse $ENV_FILE." >&2
  exit 1
fi

if [[ $# -gt 0 ]]; then
  DEVICE="$1"
else
  # Use -c so flutter JSON stays on stdin (a heredoc would replace it).
  DEVICE=$(flutter devices --machine | "$PYTHON" -c '
import json, sys
devices = json.load(sys.stdin)
for d in devices:
    if d.get("targetPlatform") == "ios":
        print(d["id"])
        raise SystemExit(0)
')
fi

if [[ -z "${DEVICE:-}" ]]; then
  echo "❌ No iOS device found. Plug one in or start a simulator, then re-run." >&2
  exit 1
fi

ENV_INFO=()
while IFS= read -r line; do
  ENV_INFO+=("$line")
done < <("$PYTHON" - "$ENV_FILE" <<'PY'
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

echo "▶️  Running on iOS device $DEVICE with $ENV_FILE (SUPABASE_URL=$SUPABASE_URL, ANON=$ANON_MASK)"
scripts/ensure_ios_firebase.sh
flutter run --dart-define-from-file="$ENV_FILE" -d "$DEVICE"
