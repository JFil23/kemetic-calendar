#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
TARGET="${1:-}"
if [[ -z "$TARGET" ]]; then
  echo "Usage: $0 /path/to/kemetic-calendar-backend" >&2
  exit 1
fi
cp -a "$ROOT/admin/." "$TARGET/admin/"
cp -a "$ROOT/supabase/migrations/." "$TARGET/supabase/migrations/"
echo "Applied admin ledger into $TARGET"
echo "Next: cd $TARGET && git checkout -b cursor/admin-activity-ledger-c86f && git add admin supabase/migrations && git commit && git push"
