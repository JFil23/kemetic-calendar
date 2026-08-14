#!/usr/bin/env bash
set -euo pipefail

if [[ $# -lt 3 || $# -gt 4 ]]; then
  echo "usage: $0 <device-id> <revision-label> <output-directory> [browser-dimension]" >&2
  exit 64
fi

device_id="$1"
revision_label="$2"
output_directory="$3"
browser_dimension="${4:-390x844@1}"

script_dir="$(cd "$(dirname "$0")" && pwd)"
mobile_root="$(cd "$script_dir/.." && pwd)"
safe_device="$(printf '%s' "$device_id" | tr -cs 'A-Za-z0-9._-' '_')"
safe_revision="$(printf '%s' "$revision_label" | tr -cs 'A-Za-z0-9._-' '_')"
output_name="calendar-dormant-observer-${safe_revision}-${safe_device}"

mkdir -p "$output_directory"

drive_args=(
  drive
  --no-pub
  --profile
  --device-id "$device_id"
  --driver test_driver/calendar_boundary_performance_test.dart
  --target integration_test/calendar_dormant_observer_performance_test.dart
  --dart-define "CALENDAR_BENCHMARK_REVISION=$revision_label"
  --dart-define "CALENDAR_BENCHMARK_REPETITIONS=${CALENDAR_BENCHMARK_REPETITIONS:-5}"
)

if [[ "$device_id" == "chrome" ]]; then
  drive_args+=(
    --browser-dimension "$browser_dimension"
    --dart-define FLUTTER_WEB_USE_SKIA=true
    --dart-define FLUTTER_WEB_USE_SKWASM=false
  )
fi

cd "$mobile_root"
CALENDAR_BENCHMARK_OUTPUT_DIR="$output_directory" \
CALENDAR_BENCHMARK_OUTPUT_NAME="$output_name" \
  flutter "${drive_args[@]}"

printf '%s\n' "$output_directory/$output_name.json"
