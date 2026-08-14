#!/usr/bin/env bash
set -euo pipefail

if [[ $# -ne 1 ]]; then
  echo "usage: $0 <output-directory>" >&2
  exit 64
fi

output_directory="$1"
script_dir="$(cd "$(dirname "$0")" && pwd)"
mobile_root="$(cd "$script_dir/.." && pwd)"
snapshot="$output_directory/environment.txt"

mkdir -p "$output_directory"
: >"$snapshot"

record() {
  local label="$1"
  shift
  printf '\n[%s]\n' "$label" >>"$snapshot"
  "$@" >>"$snapshot" 2>&1 || printf '<command unavailable or failed>\n' >>"$snapshot"
}

cd "$mobile_root"

record timestamp_utc date -u +%Y-%m-%dT%H:%M:%SZ
record repository_root pwd
record git_head git rev-parse HEAD
record git_status git status --short
record git_worktrees git worktree list --porcelain
record git_submodules git submodule status
record system uname -a
record macos sw_vers
record disk df -k "$mobile_root"
record flutter_version flutter --version --machine
record dart_version dart --version
record xcode_version xcodebuild -version
record java_version java -version
record cocoapods_version pod --version
record adb_devices adb devices -l
record flutter_devices flutter devices --machine

printf '\n[lockfile_hashes]\n' >>"$snapshot"
for lockfile in \
  pubspec.lock \
  ios/Podfile.lock \
  macos/Podfile.lock \
  android/gradle/wrapper/gradle-wrapper.properties; do
  if [[ -f "$lockfile" ]]; then
    shasum -a 256 "$lockfile" >>"$snapshot"
    cp "$lockfile" "$output_directory/${lockfile//\//_}"
  fi
done

flutter pub deps --json >"$output_directory/flutter-pub-deps.json"
shasum -a 256 "$output_directory/flutter-pub-deps.json" >>"$snapshot"

printf '%s\n' "$snapshot"
