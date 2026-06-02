#!/usr/bin/env bash
set -euo pipefail

# Builds a Play Store-ready Android app bundle with dart-defines from
# env/prod.json (or ENV_FILE override).
# Usage:
#   scripts/build_android_release.sh
#   ENV_FILE=env/stage.json scripts/build_android_release.sh
#   scripts/build_android_release.sh --flavor prod

cd "$(dirname "$0")/.."

ENV_FILE="${ENV_FILE:-env/prod.json}"
[[ -f "$ENV_FILE" ]] || { echo "❌ $ENV_FILE not found. Copy env/prod.example.json and fill it." >&2; exit 1; }

ENV_INFO="$(python3 - <<'PY' "$ENV_FILE"
import json
import sys

path = sys.argv[1]
with open(path, encoding="utf-8") as handle:
    data = json.load(handle)

url = (data.get("SUPABASE_URL") or "").strip()
anon = (data.get("SUPABASE_ANON_KEY") or "").strip()
app_env = (data.get("APP_ENV") or "").strip().lower()
site_url = (data.get("APP_SITE_URL") or "").strip()

if not url or url == "https://your-prod-project.supabase.co":
    print(f"❌ {path} has a placeholder SUPABASE_URL", file=sys.stderr)
    sys.exit(1)

if not anon or anon == "your-prod-anon-key":
    print(f"❌ {path} has a placeholder SUPABASE_ANON_KEY", file=sys.stderr)
    sys.exit(1)

if app_env not in {"staging", "prod"}:
    print(f"❌ {path} must set APP_ENV to staging or prod for release builds", file=sys.stderr)
    sys.exit(1)

if not site_url.startswith("https://") or "your-" in site_url.lower():
    print(f"❌ {path} must set APP_SITE_URL to a real https URL", file=sys.stderr)
    sys.exit(1)

if "service_role" in anon.lower() or "service-role" in anon.lower():
    print(f"❌ {path} must use the Supabase anon key, not a service role key", file=sys.stderr)
    sys.exit(1)

def mask(value: str) -> str:
    return f"{len(value)} chars ({value[:4]}...{value[-4:]})"

print(url)
print(mask(anon))
PY
)"

SUPABASE_URL="${ENV_INFO%%$'\n'*}"
ANON_MASK="${ENV_INFO#*$'\n'}"
if [[ "$ANON_MASK" == "$ENV_INFO" ]]; then
  ANON_MASK=""
fi

scripts/verify_release_config.sh --strict-signing

echo "🚀 Building Android app bundle with $ENV_FILE (SUPABASE_URL=$SUPABASE_URL, ANON=$ANON_MASK)"
flutter build appbundle --release --dart-define-from-file="$ENV_FILE" "$@"
