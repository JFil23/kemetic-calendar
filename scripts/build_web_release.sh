#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

ENV_FILE="${ENV_FILE:-}"
if [[ $# -gt 0 ]]; then
  ENV_FILE="$1"
fi

if [[ -z "$ENV_FILE" ]]; then
  if [[ -f "env/prod.json" ]]; then
    ENV_FILE="env/prod.json"
  elif [[ -f "env/dev.json" ]]; then
    ENV_FILE="env/dev.json"
  fi
fi

BUILD_ENV_FILE="$(mktemp "${TMPDIR:-/tmp}/kemetic-web-env.XXXXXX")"
trap 'rm -f "$BUILD_ENV_FILE"' EXIT

python3 - <<'PY' "$ENV_FILE" "$BUILD_ENV_FILE"
import json
import os
import re
import sys

source_path, out_path = sys.argv[1], sys.argv[2]

defaults = {
    "FIREBASE_WEB_API_KEY": "AIzaSyDxi7_OQx76JaPgjBTEF-Rfv2-1EZh0GeY",
    "FIREBASE_WEB_APP_ID": "1:867956659884:web:08c4b8b604332669727109",
    "FIREBASE_WEB_PROJECT_ID": "kemet-ead9d",
    "FIREBASE_WEB_SENDER_ID": "867956659884",
    "FIREBASE_WEB_AUTH_DOMAIN": "kemet-ead9d.firebaseapp.com",
    "FIREBASE_WEB_STORAGE_BUCKET": "kemet-ead9d.firebasestorage.app",
    "FIREBASE_WEB_VAPID_KEY": "BCL_DxiCA9I2kweZh33mnnNv2-41OLh1FZbO8lX-JjdVSHs7XS9e8gxZldJRYWVRh0WxhffmH37gMM7-qjPQgMY",
    "WEB_PUSH_PUBLIC_KEY": "BLF5usfirDkmfJaEDDUzIVLzQOuF5XMdTEIscpYZxMpm26KvEuQ716kN2a2W6_gbVUAj7-xU7WEUWCi2ZLoUlYA",
}

known_keys = [
    "SUPABASE_URL",
    "SUPABASE_ANON_KEY",
    "FIREBASE_WEB_API_KEY",
    "FIREBASE_WEB_APP_ID",
    "FIREBASE_WEB_PROJECT_ID",
    "FIREBASE_WEB_SENDER_ID",
    "FIREBASE_WEB_AUTH_DOMAIN",
    "FIREBASE_WEB_STORAGE_BUCKET",
    "FIREBASE_WEB_VAPID_KEY",
    "WEB_PUSH_PUBLIC_KEY",
]


def load_json(path: str) -> dict:
    if not path or not os.path.isfile(path):
        return {}
    with open(path, encoding="utf-8") as handle:
        return json.load(handle)


merged: dict[str, str] = {}
merged.update(defaults)
merged.update(load_json("web/env.json"))
merged.update(load_json(source_path))

for key in known_keys:
    raw = os.environ.get(key, "").strip()
    if raw:
        merged[key] = raw

url = str(merged.get("SUPABASE_URL", "")).strip()
anon = str(merged.get("SUPABASE_ANON_KEY", "")).strip()

errors: list[str] = []
if not url:
    errors.append("SUPABASE_URL is missing.")
elif "YOUR_PROJECT" in url or not url.startswith("https://") or not re.search(r"\.supabase\.co/?$", url):
    errors.append(f"SUPABASE_URL looks invalid: {url}")

if not anon:
    errors.append("SUPABASE_ANON_KEY is missing.")
elif "YOUR_SUPABASE_ANON_KEY" in anon or len(anon) <= 20:
    errors.append("SUPABASE_ANON_KEY still looks like a placeholder.")

if errors:
    print("❌ Web build configuration is incomplete.", file=sys.stderr)
    for error in errors:
        print(f"- {error}", file=sys.stderr)
    print(
        "- Provide a real env file (for example env/prod.json) or export SUPABASE_URL and SUPABASE_ANON_KEY.",
        file=sys.stderr,
    )
    sys.exit(1)

with open(out_path, "w", encoding="utf-8") as handle:
    json.dump(merged, handle, indent=2)
    handle.write("\n")

masked = f"{anon[:4]}...{anon[-4:]}" if len(anon) >= 8 else anon
source_label = source_path or "<environment variables/defaults>"
print(f"▶ Web build env source: {source_label}")
print(f"▶ SUPABASE_URL: {url}")
print(f"▶ SUPABASE_ANON_KEY: {masked} (len={len(anon)})")
PY

flutter clean
flutter build web --release \
  --dart-define-from-file="$BUILD_ENV_FILE" \
  --no-wasm-dry-run \
  --pwa-strategy=none

cp "$BUILD_ENV_FILE" build/web/env.json
[[ -f "web/env.example.json" ]] && cp "web/env.example.json" "build/web/env.example.json"
[[ -f "web/_headers" ]] && cp "web/_headers" "build/web/_headers"
[[ -f "web/_redirects" ]] && cp "web/_redirects" "build/web/_redirects"
if [[ -d "web/.well-known" ]]; then
  mkdir -p "build/web/.well-known"
  cp -R "web/.well-known/." "build/web/.well-known/"
fi

echo "✅ Web build complete at build/web"
