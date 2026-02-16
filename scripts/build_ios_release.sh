#!/usr/bin/env bash
set -euo pipefail

# Builds iOS release with dart-defines from env/prod.json (or ENV_FILE override).
# Usage:
#   scripts/build_ios_release.sh               # uses env/prod.json
#   ENV_FILE=env/stage.json scripts/build_ios_release.sh  # override env file
#   scripts/build_ios_release.sh --flavor prod  # passes through extra flutter build args

cd "$(dirname "$0")/.."

ENV_FILE="${ENV_FILE:-env/prod.json}"
[[ -f "$ENV_FILE" ]] || { echo "❌ $ENV_FILE not found. Copy env/prod.example.json and fill it." >&2; exit 1; }

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

echo "🚀 Building iOS release with $ENV_FILE (SUPABASE_URL=$SUPABASE_URL, ANON=$ANON_MASK)"
flutter build ios --release --dart-define-from-file="$ENV_FILE" "$@"
