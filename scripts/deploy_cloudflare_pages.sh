#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Preserve the three-argument interface; one owner coordinates qualification,
# upload, durable evidence and both served-origin checks.
exec python3 scripts/deploy_web_release.py "$@"
