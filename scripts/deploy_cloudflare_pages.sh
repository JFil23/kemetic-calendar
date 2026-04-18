#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

PROJECT="${CLOUDFLARE_PAGES_PROJECT:-}"
ENV_FILE_ARG="${ENV_FILE:-}"
BRANCH="${CLOUDFLARE_PAGES_BRANCH:-}"

if [[ -z "$PROJECT" && $# -gt 0 ]]; then
  PROJECT="$1"
  shift
fi

if [[ -z "$ENV_FILE_ARG" && $# -gt 0 ]]; then
  ENV_FILE_ARG="$1"
  shift
fi

if [[ -z "$BRANCH" && $# -gt 0 ]]; then
  BRANCH="$1"
  shift
fi

if [[ -z "$PROJECT" ]]; then
  echo "Usage: CLOUDFLARE_PAGES_PROJECT=<project> scripts/deploy_cloudflare_pages.sh [env-file] [branch]" >&2
  echo "   or: scripts/deploy_cloudflare_pages.sh <project> [env-file] [branch]" >&2
  exit 1
fi

if [[ -n "$ENV_FILE_ARG" ]]; then
  scripts/build_web_release.sh "$ENV_FILE_ARG"
else
  scripts/build_web_release.sh
fi

CMD=(npx wrangler@latest pages deploy build/web --project-name "$PROJECT")
if [[ -n "$BRANCH" ]]; then
  CMD+=(--branch "$BRANCH")
fi

echo "▶ Deploying build/web to Cloudflare Pages project $PROJECT"
"${CMD[@]}"
