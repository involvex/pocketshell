#!/usr/bin/env bash
# Extract a Keep a Changelog section for VERSION (e.g. 1.0.2) to stdout.
set -euo pipefail

VERSION="${1:?Usage: extract-changelog.sh <version>}"
VERSION="${VERSION#v}"
CHANGELOG="${2:-CHANGELOG.md}"

if [[ ! -f "$CHANGELOG" ]]; then
  echo "Changelog file not found: $CHANGELOG" >&2
  exit 1
fi

awk -v version="$VERSION" '
  BEGIN { found = 0 }
  /^## \[/ {
    if (found) { exit }
    if ($0 ~ "\\[" version "\\]") { found = 1; next }
  }
  found { print }
' "$CHANGELOG"
