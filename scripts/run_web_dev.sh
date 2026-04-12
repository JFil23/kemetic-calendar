#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
flutter run -d chrome --no-wasm-dry-run "${@}"
