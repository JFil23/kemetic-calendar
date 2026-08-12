#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")/.."

if [[ $# -ne 1 || ("$1" != "staging" && "$1" != "production") ]]; then
  echo "Usage: scripts/build_web_release.sh <staging|production>" >&2
  exit 1
fi

ENVIRONMENT="$1"
AUTHORITY_ROOT="$PWD"
STATE_DIR="$(mktemp -d "/tmp/kemetic-web-release.XXXXXX")"
SOURCE_DIR="$(mktemp -d "/tmp/kemetic-web-source.XXXXXX")"
trap 'rm -rf "$STATE_DIR" "$SOURCE_DIR"' EXIT

# These values affect command behavior but are fixed internally, never supplied
# as release inputs by the caller.
export TZ=UTC
export LC_ALL=C
export COPYFILE_DISABLE=1
umask 022

python3 scripts/web_release_pipeline.py prepare \
  "$ENVIRONMENT" \
  --repo-root "$AUTHORITY_ROOT" \
  --state-dir "$STATE_DIR"

BUILD_VERSION="$(
  python3 scripts/web_release_pipeline.py field \
    --prepared "$STATE_DIR/prepared.json" \
    build_version
)"
SOURCE_MAPS="$(
  python3 scripts/web_release_pipeline.py field \
    --prepared "$STATE_DIR/prepared.json" \
    source_maps
)"

echo "▶ Extracting the exact tracked mobile tree"
git archive --format=tar HEAD | tar -xf - -C "$SOURCE_DIR"

cd "$SOURCE_DIR"

echo "▶ Materializing all named web inputs before Flutter compilation"
python3 scripts/web_release_pipeline.py materialize \
  --build-root "$SOURCE_DIR" \
  --state-dir "$STATE_DIR"

echo "▶ Resolving exact locked dependencies in the clean source extraction"
PUB_CACHE="$STATE_DIR/pub-cache" \
PUB_HOSTED_URL="https://pub.dev" \
FLUTTER_STORAGE_BASE_URL="https://storage.googleapis.com" \
  flutter pub get --enforce-lockfile

python3 scripts/web_release_pipeline.py verify-lockfile \
  --prepared "$STATE_DIR/prepared.json" \
  --lockfile pubspec.lock

build_args=(
  web
  --release
  --dart-define-from-file="$STATE_DIR/runtime-env.json"
  --dart-define="HYDRATION_DIAGNOSTIC_BUILD=$BUILD_VERSION"
  --no-pub
  --no-wasm-dry-run
  --pwa-strategy=none
)
if [[ "$SOURCE_MAPS" == "1" ]]; then
  build_args+=(--source-maps)
fi

echo "▶ Building named web environment: $ENVIRONMENT"
echo "▶ Deterministic build version: $BUILD_VERSION"
PUB_CACHE="$STATE_DIR/pub-cache" \
PUB_HOSTED_URL="https://pub.dev" \
FLUTTER_STORAGE_BASE_URL="https://storage.googleapis.com" \
  flutter build "${build_args[@]}"

python3 scripts/web_release_pipeline.py finalize \
  --build-root "$SOURCE_DIR" \
  --authority-root "$AUTHORITY_ROOT" \
  --state-dir "$STATE_DIR"
