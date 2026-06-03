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

PYTHON_BIN="${PYTHON_BIN:-}"
if [[ -z "$PYTHON_BIN" ]]; then
  if command -v python3 >/dev/null 2>&1; then
    PYTHON_BIN="python3"
  elif command -v python >/dev/null 2>&1; then
    PYTHON_BIN="python"
  else
    echo "❌ Python 3 is required to validate $ENV_FILE." >&2
    exit 1
  fi
fi

"$PYTHON_BIN" - <<'PY' "$ENV_FILE"
import json, sys, re
from pathlib import Path
from urllib.parse import urlparse
path = sys.argv[1]
try:
    with open(path) as f:
        data = json.load(f)
except json.JSONDecodeError as e:
    print(f"❌ Invalid JSON in {path}: {e}", file=sys.stderr)
    sys.exit(1)
url = data.get("SUPABASE_URL", "")
anon = data.get("SUPABASE_ANON_KEY", "")
default_app_env = "prod" if Path(path).name == "prod.json" else "dev"
app_env = str(data.get("APP_ENV", default_app_env)).strip().lower()
site_url = str(data.get("APP_SITE_URL", "https://maat.app")).strip()
errors = []
def looks_placeholder(value: str) -> bool:
    lowered = value.lower()
    return any(token in lowered for token in (
        "your-", "your_", "your_project", "placeholder", "example", "change-me"
    ))
if not url:
    errors.append("SUPABASE_URL is missing or empty")
if not anon:
    errors.append("SUPABASE_ANON_KEY is missing or empty")
if url and not url.startswith("https://"):
    errors.append("SUPABASE_URL must start with https://")
if url and not re.search(r"\.supabase\.co/?$", url):
    errors.append("SUPABASE_URL must end with .supabase.co")
if url and looks_placeholder(url):
    errors.append("SUPABASE_URL still looks like a placeholder")
if anon and (len(anon) <= 20 or looks_placeholder(anon)):
    errors.append("SUPABASE_ANON_KEY is too short or still looks like a placeholder")
if "service_role" in anon.lower() or "service-role" in anon.lower():
    errors.append("SUPABASE_ANON_KEY must not be a service role key")
if app_env not in {"dev", "staging", "prod"}:
    errors.append("APP_ENV must be one of dev, staging, or prod")
if Path(path).name == "prod.json" and app_env == "dev":
    errors.append("env/prod.json must not set APP_ENV to dev")
parsed_site = urlparse(site_url)
if not site_url or parsed_site.scheme != "https" or not parsed_site.netloc or looks_placeholder(site_url):
    errors.append("APP_SITE_URL must be a real https URL")
if errors:
    print("❌ Validation failed for", path, file=sys.stderr)
    for e in errors:
        print(f"- {e}", file=sys.stderr)
    sys.exit(1)
def mask(k: str) -> str:
    return f"{len(k)} chars ({k[:4]}...{k[-4:]})" if k else ""
print(f"✅ {path} ok")
print(f"APP_ENV: {app_env}")
print(f"APP_SITE_URL: {site_url}")
print(f"SUPABASE_URL: {url}")
print(f"SUPABASE_ANON_KEY: {mask(anon)}")
PY
