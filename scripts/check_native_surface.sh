#!/usr/bin/env bash
set -euo pipefail

if rg -n -S '(?i)hammerspoon|\.lua\b' README.md CONTRIBUTING.md macos-app; then
  echo "Unexpected legacy automation reference found"
  exit 1
fi

printf 'Native surface check passed\n'
