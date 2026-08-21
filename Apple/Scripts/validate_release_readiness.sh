#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

cd "$ROOT_DIR"

echo "== Localization completeness =="
Scripts/validate_localizations.rb

echo
echo "== Localization placeholder parity =="
Scripts/validate_string_placeholders.rb

echo
echo "== Localization source coverage =="
Scripts/validate_localization_sources.rb

echo
echo "== App Intent metadata restricted terms =="
Scripts/validate_app_intent_metadata_terms.sh

echo
echo "== Production raw logging =="
Scripts/validate_raw_logging.rb

echo
echo "Release readiness validation passed."
