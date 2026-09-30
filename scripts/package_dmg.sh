#!/usr/bin/env bash
# Packages build/Wispr Assist.app into build/WisprAssist-<version>.dmg (app + /Applications shortcut).
# Usage: VERSION=1.2.3 ./scripts/package_dmg.sh
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/Wispr Assist.app"
VERSION="${VERSION:-$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")}"
DMG="build/WisprAssist-${VERSION}.dmg"
STAGE="$(mktemp -d)"
trap 'rm -rf "$STAGE"' EXIT

[ -d "$APP" ] || { echo "error: $APP not found; run scripts/build_app.sh first" >&2; exit 1; }
cp -R "$APP" "$STAGE/"
ln -s /Applications "$STAGE/Applications"
rm -f "$DMG"
hdiutil create -volname "Wispr Assist" -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null
echo "Built: $DMG"
