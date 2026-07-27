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
TARGET_BRANCH="${BRANCH:-production}"
WRANGLER_VERSION="4.114.0"

EXTRACT_DIR="$(mktemp -d "/tmp/kemetic-web-upload.XXXXXX")"
EVIDENCE_ROOT="$(dirname "$RELEASE_DIR")/web-deployment-receipts"
mkdir -p "$EVIDENCE_ROOT"
ATTEMPT_DIR="$(mktemp -d "$EVIDENCE_ROOT/attempt.XXXXXX")"
UPLOAD_RESULT="$ATTEMPT_DIR/wrangler.log"
UPLOAD_ATTEMPT_RECEIPT="$ATTEMPT_DIR/upload-attempt.json"
VERIFY_RESULT="$ATTEMPT_DIR/served-verification.log"
SERVED_RECEIPT="$ATTEMPT_DIR/served-deployment.json"
trap 'rm -rf "$EXTRACT_DIR"' EXIT

python3 scripts/served_artifact_verifier.py preflight-target \
  --release-dir "$RELEASE_DIR" \
  --expected-archive-sha256 "$EXPECTED_ARCHIVE_SHA256" \
  --project "$PROJECT" \
  --branch "$TARGET_BRANCH"

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

set +e
"${CMD[@]}" 2>&1 | tee "$UPLOAD_RESULT"
WRANGLER_STATUS="${PIPESTATUS[0]}"
set -e
python3 scripts/served_artifact_verifier.py record-upload-attempt \
  --release-dir "$RELEASE_DIR" \
  --expected-archive-sha256 "$EXPECTED_ARCHIVE_SHA256" \
  --project "$PROJECT" \
  --branch "$TARGET_BRANCH" \
  --wrangler-version "$WRANGLER_VERSION" \
  --upload-result "$UPLOAD_RESULT" \
  --upload-status "$WRANGLER_STATUS" \
  --receipt "$UPLOAD_ATTEMPT_RECEIPT"
if [[ "$WRANGLER_STATUS" -ne 0 ]]; then
  echo "ERROR: Wrangler upload failed; evidence preserved in $ATTEMPT_DIR." >&2
  exit "$WRANGLER_STATUS"
fi

if [[ -n "$BRANCH" ]]; then
  ALIAS_URL="https://${BRANCH}.${PROJECT}.pages.dev"
else
  ALIAS_URL="https://${PROJECT}.pages.dev"
fi
IMMUTABLE_URL="$(
  python3 scripts/served_artifact_verifier.py extract-immutable-url \
    --upload-result "$UPLOAD_RESULT" \
    --project "$PROJECT" \
    --alias-url "$ALIAS_URL"
)"
DEPLOYMENT_ID="$(printf '%s' "$IMMUTABLE_URL" | shasum -a 256 | awk '{print substr($1,1,16)}')"

set +e
python3 scripts/served_artifact_verifier.py verify \
  --release-dir "$RELEASE_DIR" \
  --expected-archive-sha256 "$EXPECTED_ARCHIVE_SHA256" \
  --immutable-url "$IMMUTABLE_URL" \
  --alias-url "$ALIAS_URL" \
  --project "$PROJECT" \
  --branch "$TARGET_BRANCH" \
  --wrangler-version "$WRANGLER_VERSION" \
  --upload-result "$UPLOAD_RESULT" \
  --receipt "$SERVED_RECEIPT" 2>&1 | tee "$VERIFY_RESULT"
VERIFY_STATUS="${PIPESTATUS[0]}"
set -e
if [[ "$VERIFY_STATUS" -ne 0 ]]; then
  echo "ERROR: Served verification failed; evidence preserved in $ATTEMPT_DIR." >&2
  exit "$VERIFY_STATUS"
fi
echo "▶ Deployment ID: $DEPLOYMENT_ID"
echo "▶ Deployment evidence: $ATTEMPT_DIR"
