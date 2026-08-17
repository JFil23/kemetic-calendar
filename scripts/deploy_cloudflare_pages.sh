#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ $# -ne 3 ]]; then
  cat >&2 <<'USAGE'
Usage:
  scripts/deploy_cloudflare_pages.sh \
    <release-directory> <authorized-archive-sha256> <staging|production>

This command uploads an already-built, verified artifact. It never rebuilds.
USAGE
  exit 1
fi

RELEASE_DIR="$1"
EXPECTED_ARCHIVE_SHA256="$2"
ENVIRONMENT="$3"
case "$ENVIRONMENT" in
  staging)
    PROJECT="kemet-rc"
    CLOUDFLARE_BRANCH="main"
    ALIAS_URL="https://kemet-rc.pages.dev"
    ;;
  production)
    PROJECT="kemet"
    CLOUDFLARE_BRANCH="main"
    ALIAS_URL="https://kemet.pages.dev"
    ;;
  *)
    echo "ERROR: Deployment environment must be staging or production." >&2
    exit 1
    ;;
esac
WRANGLER_VERSION="4.114.0"

EXTRACT_DIR="$(mktemp -d "/tmp/kemetic-web-upload.XXXXXX")"
EVIDENCE_ROOT="$(dirname "$RELEASE_DIR")/web-deployment-receipts"
mkdir -p "$EVIDENCE_ROOT"
ATTEMPT_DIR="$(mktemp -d "$EVIDENCE_ROOT/attempt.XXXXXX")"
UPLOAD_RESULT="$ATTEMPT_DIR/wrangler.log"
UPLOAD_ATTEMPT_RECEIPT="$ATTEMPT_DIR/upload-attempt.json"
VERIFY_RESULT="$ATTEMPT_DIR/served-verification.log"
SERVED_RECEIPT="$ATTEMPT_DIR/served-deployment.json"
DEPLOYMENT_METADATA="$ATTEMPT_DIR/cloudflare-production-deployments.json"
DEPLOYMENT_METADATA_LOG="$ATTEMPT_DIR/cloudflare-production-deployments.stderr.log"
trap 'rm -rf "$EXTRACT_DIR"' EXIT

python3 scripts/served_artifact_verifier.py preflight-target \
  --release-dir "$RELEASE_DIR" \
  --expected-archive-sha256 "$EXPECTED_ARCHIVE_SHA256" \
  --project "$PROJECT" \
  --branch "$CLOUDFLARE_BRANCH"

python3 scripts/web_release_pipeline.py verify \
  --release-dir "$RELEASE_DIR" \
  --expected-archive-sha256 "$EXPECTED_ARCHIVE_SHA256" \
  --extract-to "$EXTRACT_DIR"

python3 scripts/web_release_pipeline.py assert-canonical-source \
  "$ENVIRONMENT" \
  --repo-root "$PWD" \
  --release-dir "$RELEASE_DIR"

CMD=(
  npx
  --yes
  "wrangler@$WRANGLER_VERSION"
  pages
  deploy
  "$EXTRACT_DIR/web"
  --project-name
  "$PROJECT"
  --branch
  "$CLOUDFLARE_BRANCH"
)

echo "▶ Uploading the verified artifact without rebuilding"
echo "▶ Cloudflare Pages project: $PROJECT"
echo "▶ Cloudflare production branch: $CLOUDFLARE_BRANCH"
echo "▶ Wrangler version: $WRANGLER_VERSION"

set +e
"${CMD[@]}" 2>&1 | tee "$UPLOAD_RESULT"
WRANGLER_STATUS="${PIPESTATUS[0]}"
set -e
python3 scripts/served_artifact_verifier.py record-upload-attempt \
  --release-dir "$RELEASE_DIR" \
  --expected-archive-sha256 "$EXPECTED_ARCHIVE_SHA256" \
  --project "$PROJECT" \
  --branch "$CLOUDFLARE_BRANCH" \
  --wrangler-version "$WRANGLER_VERSION" \
  --upload-result "$UPLOAD_RESULT" \
  --upload-status "$WRANGLER_STATUS" \
  --receipt "$UPLOAD_ATTEMPT_RECEIPT"
if [[ "$WRANGLER_STATUS" -ne 0 ]]; then
  echo "ERROR: Wrangler upload failed; evidence preserved in $ATTEMPT_DIR." >&2
  exit "$WRANGLER_STATUS"
fi

IMMUTABLE_URL="$(
  python3 scripts/served_artifact_verifier.py extract-immutable-url \
    --upload-result "$UPLOAD_RESULT" \
    --project "$PROJECT" \
    --alias-url "$ALIAS_URL"
)"

set +e
npx --yes "wrangler@$WRANGLER_VERSION" pages deployment list \
  --project-name "$PROJECT" \
  --environment production \
  --json 2>"$DEPLOYMENT_METADATA_LOG" | tee "$DEPLOYMENT_METADATA"
METADATA_STATUS="${PIPESTATUS[0]}"
set -e
if [[ "$METADATA_STATUS" -ne 0 ]]; then
  echo "ERROR: Cloudflare production metadata lookup failed; evidence preserved in $ATTEMPT_DIR." >&2
  exit "$METADATA_STATUS"
fi

set +e
python3 scripts/served_artifact_verifier.py verify \
  --release-dir "$RELEASE_DIR" \
  --expected-archive-sha256 "$EXPECTED_ARCHIVE_SHA256" \
  --immutable-url "$IMMUTABLE_URL" \
  --alias-url "$ALIAS_URL" \
  --project "$PROJECT" \
  --branch "$CLOUDFLARE_BRANCH" \
  --wrangler-version "$WRANGLER_VERSION" \
  --upload-result "$UPLOAD_RESULT" \
  --deployment-metadata "$DEPLOYMENT_METADATA" \
  --receipt "$SERVED_RECEIPT" 2>&1 | tee "$VERIFY_RESULT"
VERIFY_STATUS="${PIPESTATUS[0]}"
set -e
if [[ "$VERIFY_STATUS" -ne 0 ]]; then
  echo "ERROR: Served verification failed; evidence preserved in $ATTEMPT_DIR." >&2
  exit "$VERIFY_STATUS"
fi
echo "▶ Deployment evidence: $ATTEMPT_DIR"
