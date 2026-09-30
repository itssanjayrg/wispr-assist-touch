#!/usr/bin/env bash
# Builds a universal "Assist Touch.app" into ./build.
# Optional: SIGN_IDENTITY="Apple Development: Your Name (TEAMID)" keeps the Accessibility
# grant across rebuilds (ad-hoc signatures change every build and macOS forgets the grant).
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/Assist Touch.app"
swift build -c release --arch arm64 --arch x86_64
BIN="$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/AssistTouch"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/AssistTouch"
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force --options runtime --sign "${SIGN_IDENTITY:--}" "$APP"
echo "Built: $APP"
