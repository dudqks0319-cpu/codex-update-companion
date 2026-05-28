#!/usr/bin/env bash
set -euo pipefail

ARCHIVE_PATH="${1:-dist/CodexUpdateCompanion.dmg}"
KEYCHAIN_PROFILE="${2:-}"

if [[ -z "$KEYCHAIN_PROFILE" ]]; then
  echo "usage: $0 <dmg-or-zip-path> <notarytool-keychain-profile>" >&2
  exit 2
fi

test -f "$ARCHIVE_PATH"
xcrun notarytool submit "$ARCHIVE_PATH" --keychain-profile "$KEYCHAIN_PROFILE" --wait
xcrun stapler staple "$ARCHIVE_PATH"
