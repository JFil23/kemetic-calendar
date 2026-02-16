#!/usr/bin/env bash
set -euo pipefail

# Verifies the env JSON contains required keys and a valid Supabase URL.
# Usage:
#   scripts/verify_env.sh                # defaults to env/dev.json
#   scripts/verify_env.sh env/prod.json  # check another env file
#   scripts/verify_env.sh --env env/prod.json

cd "$(dirname "$0")/.."

ENV_FILE="env/dev.json"
if [[ $# -gt 0 ]]; then
  if [[ "$1" == "--env" && $# -ge 2 ]]; then
    ENV_FILE="$2"
  else
    ENV_FILE="$1"
  fi
fi

if [[ ! -f "$ENV_FILE" ]]; then
  echo "❌ Missing $ENV_FILE. Copy an example and fill it locally." >&2
  exit 1
fi

python - <<'PY' "$ENV_FILE"
import json, sys, re
path = sys.argv[1]
try:
    with open(path) as f:
        data = json.load(f)
except json.JSONDecodeError as e:
    print(f"❌ Invalid JSON in {path}: {e}", file=sys.stderr)
    sys.exit(1)
url = data.get("SUPABASE_URL", "")
anon = data.get("SUPABASE_ANON_KEY", "")
errors = []
if not url:
    errors.append("SUPABASE_URL is missing or empty")
if not anon:
    errors.append("SUPABASE_ANON_KEY is missing or empty")
if url and not url.startswith("https://"):
    errors.append("SUPABASE_URL must start with https://")
if url and not re.search(r"\.supabase\.co/?$", url):
    errors.append("SUPABASE_URL must end with .supabase.co")
if errors:
    print("❌ Validation failed for", path, file=sys.stderr)
    for e in errors:
        print(f"- {e}", file=sys.stderr)
    sys.exit(1)
def mask(k: str) -> str:
    return f"{len(k)} chars ({k[:4]}...{k[-4:]})" if k else ""
print(f"✅ {path} ok")
print(f"SUPABASE_URL: {url}")
print(f"SUPABASE_ANON_KEY: {mask(anon)}")
PY
