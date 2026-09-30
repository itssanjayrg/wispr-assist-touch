#!/usr/bin/env bash
# Builds a universal "Wispr Assist.app" into ./build.
# Optional: SIGN_IDENTITY="Apple Development: Your Name (TEAMID)" keeps the Accessibility
# grant across rebuilds (ad-hoc signatures change every build and macOS forgets the grant).
set -euo pipefail
cd "$(dirname "$0")/.."

APP="build/Wispr Assist.app"
# Universal builds need full Xcode (xcbuild); fall back to the host architecture without it.
ARCH_FLAGS=(--arch arm64 --arch x86_64)
if ! swift build -c release "${ARCH_FLAGS[@]}" 2>/dev/null; then
    echo "Universal build unavailable; building for the host architecture only." >&2
    ARCH_FLAGS=()
    swift build -c release
fi
BIN="$(swift build -c release ${ARCH_FLAGS[@]+"${ARCH_FLAGS[@]}"} --show-bin-path)/WisprAssist"

rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/WisprAssist"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
# Optional release metadata: VERSION=1.2.3 [BUILD_NUMBER=45]
if [ -n "${VERSION:-}" ]; then
    /usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString $VERSION" "$APP/Contents/Info.plist"
    /usr/libexec/PlistBuddy -c "Set :CFBundleVersion ${BUILD_NUMBER:-$VERSION}" "$APP/Contents/Info.plist"
fi

# Hardened runtime is required for notarization; a secure timestamp is required for Developer ID.
codesign --force --options runtime ${SIGN_IDENTITY:+--timestamp} --sign "${SIGN_IDENTITY:--}" "$APP"
echo "Built: $APP"
