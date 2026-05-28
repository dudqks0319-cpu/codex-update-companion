#!/usr/bin/env bash
set -euo pipefail

APP_BUNDLE="${1:-dist/Codex Update Companion.app}"
MODE="${2:-structure}"
APP_BINARY="$APP_BUNDLE/Contents/MacOS/CodexUpdateCompanion"
INFO_PLIST="$APP_BUNDLE/Contents/Info.plist"

test -d "$APP_BUNDLE"
test -x "$APP_BINARY"
test -f "$INFO_PLIST"

[[ "$(plutil -extract CFBundlePackageType raw "$INFO_PLIST")" == "APPL" ]]
[[ "$(plutil -extract LSUIElement raw "$INFO_PLIST")" == "1" ]]
[[ "$(plutil -extract CFBundleIdentifier raw "$INFO_PLIST")" == "com.jyb.codex-update-companion" ]]

if [[ "$MODE" == "--strict-signing" ]]; then
  codesign --verify --deep --strict "$APP_BUNDLE"
  spctl --assess --type execute --verbose "$APP_BUNDLE"
fi

echo "Bundle verified: $APP_BUNDLE"
