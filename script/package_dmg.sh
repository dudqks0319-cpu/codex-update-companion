#!/usr/bin/env bash
set -euo pipefail

APP_BUNDLE="${1:-dist/Codex Update Companion.app}"
DMG_PATH="${2:-dist/CodexUpdateCompanion.dmg}"
VOLUME_NAME="Codex Update Companion"

test -d "$APP_BUNDLE"
mkdir -p "$(dirname "$DMG_PATH")"
rm -f "$DMG_PATH"

hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$APP_BUNDLE" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo "$DMG_PATH"
