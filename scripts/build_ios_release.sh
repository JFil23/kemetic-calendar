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

ENV_INFO="$(python3 - <<'PY' "$ENV_FILE"
import json, sys
path = sys.argv[1]
with open(path) as f:
    data = json.load(f)
url = (data.get("SUPABASE_URL") or "").strip()
anon = (data.get("SUPABASE_ANON_KEY") or "").strip()
app_env = (data.get("APP_ENV") or "").strip().lower()
site_url = (data.get("APP_SITE_URL") or "").strip()
if not url or url == "https://your-prod-project.supabase.co" or "your-" in url.lower():
    print(f"❌ {path} has a placeholder SUPABASE_URL", file=sys.stderr)
    sys.exit(1)
if not anon or anon == "your-prod-anon-key" or len(anon) <= 20 or "your-" in anon.lower():
    print(f"❌ {path} has a placeholder SUPABASE_ANON_KEY", file=sys.stderr)
    sys.exit(1)
if "service_role" in anon.lower() or "service-role" in anon.lower():
    print(f"❌ {path} must use the Supabase anon key, not a service role key", file=sys.stderr)
    sys.exit(1)
if app_env not in {"staging", "prod"}:
    print(f"❌ {path} must set APP_ENV to staging or prod for release builds", file=sys.stderr)
    sys.exit(1)
if not site_url.startswith("https://") or "your-" in site_url.lower():
    print(f"❌ {path} must set APP_SITE_URL to a real https URL", file=sys.stderr)
    sys.exit(1)
def mask(k: str) -> str:
    if not k:
        return ""
    return f"{len(k)} chars ({k[:4]}...{k[-4:]})"
print(url)
print(mask(anon))
PY
)"
SUPABASE_URL="${ENV_INFO%%$'\n'*}"
ANON_MASK="${ENV_INFO#*$'\n'}"
if [[ "$ANON_MASK" == "$ENV_INFO" ]]; then
  ANON_MASK=""
fi

scripts/ensure_ios_firebase.sh
scripts/verify_release_config.sh

echo "🚀 Building iOS release with $ENV_FILE (SUPABASE_URL=$SUPABASE_URL, ANON=$ANON_MASK)"
flutter build ios --release --dart-define-from-file="$ENV_FILE" "$@"
