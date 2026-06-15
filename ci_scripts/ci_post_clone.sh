#!/bin/zsh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

if [[ ! -x "./ToDo/Scripts/validate_release_readiness.sh" ]]; then
  echo "Release readiness script is missing or not executable." >&2
  exit 1
fi

./ToDo/Scripts/validate_release_readiness.sh
