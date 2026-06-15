#!/bin/zsh
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$REPO_ROOT"

if [[ -x "./Scripts/validate_release_readiness.sh" ]]; then
  ./Scripts/validate_release_readiness.sh
elif [[ -x "./ToDo/Scripts/validate_release_readiness.sh" ]]; then
  ./ToDo/Scripts/validate_release_readiness.sh
else
  echo "Release readiness script is missing or not executable." >&2
  echo "Expected ./Scripts/validate_release_readiness.sh or ./ToDo/Scripts/validate_release_readiness.sh" >&2
  exit 1
fi
