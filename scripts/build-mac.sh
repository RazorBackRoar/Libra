#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/.."

# Machine-safe SwiftPM product / Mach-O name (no `!`).
EXEC_NAME="Libra"
# User-facing bundle + DMG names (brand).
DISPLAY_NAME="L!bra"
BUNDLE_ID="com.razorbackroar.libra"

# Resolve Swift Package version from version.json
VERSION="$(sed -n 's/.*"version".*"\([^"]*\)".*/\1/p' "$PROJECT_DIR/Sources/Libra/Resources/version.json")"

RELEASE_DIR="$PROJECT_DIR/build/Release"

# Prevent stale artifacts from previous builds with different display names.
rm -rf "$RELEASE_DIR"/*.app "$RELEASE_DIR"/*.dmg
APP_PATH="$RELEASE_DIR/${DISPLAY_NAME}.app"
# Output file uses the machine-safe name (GitHub rejects "!" in asset filenames).
DMG_PATH="$RELEASE_DIR/${EXEC_NAME}.dmg"
EXEC_PATH="$PROJECT_DIR/.build/release/$EXEC_NAME"
RESOURCE_BUNDLE="$PROJECT_DIR/.build/release/${EXEC_NAME}_${EXEC_NAME}.bundle"

echo "Building L!bra release..."
cd "$PROJECT_DIR"
swift build -c release

echo "Packaging ${DISPLAY_NAME}.app (executable ${EXEC_NAME})..."
rm -rf "$APP_PATH"
mkdir -p "$APP_PATH/Contents/MacOS"
mkdir -p "$APP_PATH/Contents/Resources"

cp "$EXEC_PATH" "$APP_PATH/Contents/MacOS/$EXEC_NAME"
cp "$PROJECT_DIR/Sources/Libra/Resources/AppIcon.icns" "$APP_PATH/Contents/Resources/AppIcon.icns"
cp "$PROJECT_DIR/Sources/Libra/Resources/version.json" "$APP_PATH/Contents/Resources/version.json"

# Keep the SwiftPM resource bundle in Contents/Resources for the Resources resolver.
if [ -d "$RESOURCE_BUNDLE" ]; then
    cp -R "$RESOURCE_BUNDLE" "$APP_PATH/Contents/Resources/${EXEC_NAME}_${EXEC_NAME}.bundle"
fi

# Generate Info.plist
cat > "$APP_PATH/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key>
    <string>${DISPLAY_NAME}</string>
    <key>CFBundleDisplayName</key>
    <string>${DISPLAY_NAME}</string>
    <key>CFBundleIdentifier</key>
    <string>$BUNDLE_ID</string>
    <key>CFBundleVersion</key>
    <string>$VERSION</string>
    <key>CFBundleShortVersionString</key>
    <string>$VERSION</string>
    <key>CFBundleIconFile</key>
    <string>AppIcon</string>
    <key>CFBundleExecutable</key>
    <string>$EXEC_NAME</string>
    <key>CFBundlePackageType</key>
    <string>APPL</string>
    <key>LSMinimumSystemVersion</key>
    <string>14.0</string>
    <key>NSHighResolutionCapable</key>
    <true/>
</dict>
</plist>
EOF

chmod +x "$APP_PATH/Contents/MacOS/$EXEC_NAME"

echo "Ad-hoc signing ${DISPLAY_NAME}.app..."
codesign --force --deep --sign - "$APP_PATH"

echo "Creating ${DISPLAY_NAME}.dmg with shared layout..."
mkdir -p "$RELEASE_DIR"
RAZORCORE_DIR="$(cd "$SCRIPT_DIR/../../.razorcore" && pwd)"
DMG_SETTINGS="$RAZORCORE_DIR/dmg-settings.py"
VOL_ICNS="$APP_PATH/Contents/Resources/AppIcon.icns"
rm -f "$DMG_PATH"

dmg_defines=(-D "app=$APP_PATH" -D "app_name=$DISPLAY_NAME")
if [ -f "$VOL_ICNS" ]; then
    dmg_defines+=(-D "vol_icon=$VOL_ICNS")
fi

dmg_ok=0
for attempt in 1 2 3; do
    if [ -d "/Volumes/$DISPLAY_NAME" ]; then
        hdiutil detach "/Volumes/$DISPLAY_NAME" -force -quiet 2>/dev/null || true
    fi
    rm -f "$DMG_PATH"
    if uvx --from dmgbuild dmgbuild -s "$DMG_SETTINGS" "${dmg_defines[@]}" "$DISPLAY_NAME" "$DMG_PATH"; then
        dmg_ok=1
        break
    fi
    echo "Warning: DMG build attempt ${attempt}/3 failed for ${DISPLAY_NAME}; retrying..."
    sleep 2
done

if [ "$dmg_ok" -ne 1 ]; then
    echo "Error: DMG build failed after 3 attempts for ${DISPLAY_NAME}." >&2
    exit 1
fi

echo "Verifying locked DMG layout..."
python3 "$RAZORCORE_DIR/verify-dmg-layout.py" "$DMG_PATH" "$DISPLAY_NAME"

# Package as a single DMG; do not leave the .app bundle in the app folder.
rm -rf "$APP_PATH"

echo "Build complete: $DMG_PATH"
