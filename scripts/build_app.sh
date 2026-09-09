#!/bin/bash
# Builds AD-PLAYER.app for local/internal use on macOS Monterey+.
# The app is only ad-hoc signed (codesign --sign -), which is NOT a real
# Developer ID / notarized signature. It satisfies the OS requirement to
# run arm64 binaries, but Gatekeeper will still warn on first launch since
# the app comes from an unidentified developer (expected for internal use).
set -euo pipefail

APP_NAME="AD-PLAYER"
EXECUTABLE_NAME="ADPlayer"
BUNDLE_ID="com.studiosvoa.adplayer"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_DIR="$DIST_DIR/$APP_NAME.app"

cd "$ROOT_DIR"
echo "==> Building release binary..."
swift build -c release

BIN_PATH=".build/release/$EXECUTABLE_NAME"
if [ ! -f "$BIN_PATH" ]; then
  echo "error: built binary not found at $BIN_PATH" >&2
  exit 1
fi

echo "==> Creating app bundle at $APP_DIR"
rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp "$BIN_PATH" "$APP_DIR/Contents/MacOS/$APP_NAME"
chmod +x "$APP_DIR/Contents/MacOS/$APP_NAME"

if [ -f "$ROOT_DIR/Help.html" ]; then
  cp "$ROOT_DIR/Help.html" "$DIST_DIR/Help.html"
  cp "$ROOT_DIR/Help.html" "$APP_DIR/Contents/Resources/Help.html"
fi

cat > "$APP_DIR/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>$APP_NAME</string>
    <key>CFBundleDisplayName</key>
    <string>$APP_NAME</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleExecutable</key>
    <string>$APP_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>CFBundleShortVersionString</key>
    <string>1.0</string>
    <key>CFBundleVersion</key>
    <string>1</string>
    <key>LSMinimumSystemVersion</key>
    <string>12.0</string>
    <key>LSApplicationCategoryType</key>
    <string>public.app-category.video</string>
    <key>NSHighResolutionCapable</key>
    <true/>
    <key>LSUIElement</key>
    <false/>
    <key>NSPrincipalClass</key>
    <string>NSApplication</string>
</dict>
</plist>
PLIST

echo "==> Ad-hoc signing (unsigned, internal use only)..."
codesign --force --deep --sign - "$APP_DIR"

echo "==> Done: $APP_DIR"
echo "First launch: right-click > Open (or System Settings > Privacy & Security > Open Anyway),"
echo "since the app is not signed with a Developer ID / notarized."
