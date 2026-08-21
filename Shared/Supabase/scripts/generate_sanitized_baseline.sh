#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
SUPABASE_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
OUTPUT_PATH="${1:-/private/tmp/todo-supabase-public-baseline.sql}"
TEMP_PATH="$(mktemp /private/tmp/todo-supabase-baseline.XXXXXX.sql)"

cleanup() {
  rm -f "$TEMP_PATH"
}
trap cleanup EXIT

cd "$SUPABASE_ROOT"
supabase db dump --linked --schema public --file "$TEMP_PATH"

for forbidden_text in 'supabase_functions.http_request'
do
  if grep -Fq "$forbidden_text" "$TEMP_PATH"; then
    echo "Baseline rejected: legacy webhook configuration remains in the schema dump." >&2
    exit 1
  fi
done

if grep -Eq 'https://[a-z0-9]+\.supabase\.co/functions/v1/todo-sync-push' "$TEMP_PATH"; then
  echo "Baseline rejected: a fixed production webhook endpoint remains in the schema dump." >&2
  exit 1
fi

for environment_file in .env.todo-sync-push .env
do
  [[ -f "$environment_file" ]] || continue

  while IFS='=' read -r name value
  do
    [[ "$name" == *SECRET* || "$name" == *KEY* ]] || continue
    value="${value%\"}"
    value="${value#\"}"
    value="${value%\'}"
    value="${value#\'}"
    [[ ${#value} -ge 12 ]] || continue

    if grep -Fq "$value" "$TEMP_PATH"; then
      echo "Baseline rejected: a value from $environment_file is present in the dump." >&2
      exit 1
    fi
  done < "$environment_file"
done

install -m 600 "$TEMP_PATH" "$OUTPUT_PATH"
echo "Sanitized public-schema candidate written to: $OUTPUT_PATH"
echo "This is a review artifact, not an approved migration baseline."
