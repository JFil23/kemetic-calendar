#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

ENV_FILE="web/env.json"

if [[ ! -f "$ENV_FILE" ]]; then
  echo "⚠️  $ENV_FILE not found. Copy web/env.example.json and fill in your keys." >&2
  exit 1
fi

flutter clean
flutter build web --release \
  --dart-define-from-file="$ENV_FILE" \
  --pwa-strategy=offline-first

echo "✅ Web build complete at build/web"
