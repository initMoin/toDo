#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SEARCH_ROOTS=(
  "$ROOT_DIR/Core/AppIntents"
  "$ROOT_DIR/ToDo Watch App"
  "$ROOT_DIR/ToDoWidget"
)

# App Store Connect rejects some App Intent description metadata when it contains
# reserved platform assistant/vendor terms. Keep descriptions generic; use shortcut
# phrases/titles for product-facing wording instead.
BLOCKED_PATTERN='IntentDescription\([^)]*(Apple|Siri|apple|siri)'

if rg -n "$BLOCKED_PATTERN" "${SEARCH_ROOTS[@]}"; then
  echo "Blocked App Intent metadata term found. Remove Apple/Siri from IntentDescription strings before archiving." >&2
  exit 1
fi

echo "App Intent metadata term validation passed."
