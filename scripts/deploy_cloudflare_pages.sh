#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ $# -lt 3 || $# -gt 4 ]]; then
  cat >&2 <<'USAGE'
Usage:
  scripts/deploy_cloudflare_pages.sh \
    <release-directory> <authorized-archive-sha256> <project> [preview-branch]

This command uploads an already-built, verified artifact. It never rebuilds.
USAGE
  exit 1
fi

RELEASE_DIR="$1"
EXPECTED_ARCHIVE_SHA256="$2"
PROJECT="$3"
BRANCH="${4:-}"
WRANGLER_VERSION="4.114.0"

EXTRACT_DIR="$(mktemp -d "/tmp/kemetic-web-upload.XXXXXX")"
trap 'rm -rf "$EXTRACT_DIR"' EXIT

python3 scripts/web_release_pipeline.py verify \
  --release-dir "$RELEASE_DIR" \
  --expected-archive-sha256 "$EXPECTED_ARCHIVE_SHA256" \
  --extract-to "$EXTRACT_DIR"

CMD=(
  npx
  --yes
  "wrangler@$WRANGLER_VERSION"
  pages
  deploy
  "$EXTRACT_DIR/web"
  --project-name
  "$PROJECT"
)
if [[ -n "$BRANCH" ]]; then
  CMD+=(--branch "$BRANCH")
fi

echo "▶ Uploading the verified artifact without rebuilding"
echo "▶ Cloudflare Pages project: $PROJECT"
echo "▶ Wrangler version: $WRANGLER_VERSION"
if [[ -n "$BRANCH" ]]; then
  echo "▶ Preview branch: $BRANCH"
fi
"${CMD[@]}"
