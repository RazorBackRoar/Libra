#!/bin/bash
set -e
# Brand name contains `!` (L!bra). Disable history expansion so echo/printf stay literal.
set +o histexpand

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

# Named paths only — razorbuild invokes this script with zsh, which errors
# on unmatched *.app globs. Cover both L!bra and machine-safe Libra names.
rm -rf \
  "$RELEASE_DIR/${DISPLAY_NAME}.app" \
  "$RELEASE_DIR/${EXEC_NAME}.app" \
  "$RELEASE_DIR/${DISPLAY_NAME}.dmg" \
  "$RELEASE_DIR/${EXEC_NAME}.dmg"
APP_PATH="$RELEASE_DIR/${DISPLAY_NAME}.app"
# Output file uses the machine-safe name (GitHub rejects "!" in asset filenames).
DMG_PATH="$RELEASE_DIR/${EXEC_NAME}.dmg"
EXEC_PATH="$PROJECT_DIR/.build/release/$EXEC_NAME"
RESOURCE_BUNDLE="$PROJECT_DIR/.build/release/${EXEC_NAME}_${EXEC_NAME}.bundle"

echo "Building L!bra release..."
cd "$PROJECT_DIR"

if [[ -f "$PROJECT_DIR/Libra.png" ]]; then
    ICON_PYTHON="${LIBRA_ICON_PYTHON:-}"
    if [[ -z "$ICON_PYTHON" ]] && command -v uv >/dev/null 2>&1; then
        echo "Generating L!bra.icns with uv + Pillow..."
        uv run --with pillow python "$SCRIPT_DIR/generate-icon.py"
    elif [[ -n "$ICON_PYTHON" ]]; then
        "$ICON_PYTHON" "$SCRIPT_DIR/generate-icon.py"
    else
        echo "Pillow not found; using existing AppIcon.icns"
    fi
fi

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
    <key>NSHumanReadableCopyright</key>
    <string>Copyright © $(date +%Y) RazorBackRoar. All rights reserved.</string>
</dict>
</plist>
EOF

chmod +x "$APP_PATH/Contents/MacOS/$EXEC_NAME"

# Keep copyright year current via shared helper (does not touch DMG layout).
RAZORCORE_DIR="$(cd "$SCRIPT_DIR/../../.razorcore" && pwd)"
"$RAZORCORE_DIR/patch-app-branding.sh" "$APP_PATH"

echo "Ad-hoc signing ${DISPLAY_NAME}.app..."
codesign --force --deep --sign - "$APP_PATH"

echo "Creating ${DISPLAY_NAME}.dmg with shared layout..."
mkdir -p "$RELEASE_DIR"
"$RAZORCORE_DIR/package-dmg.sh" \
  --app "$APP_PATH" \
  --dmg "$DMG_PATH" \
  --app-name "$DISPLAY_NAME" \
  --volname "$DISPLAY_NAME"

# package-dmg.sh owns Desktop copy / mount. Never install into /Applications.
# Keep the in-repo DMG. Delete only the staging .app.
rm -rf "$APP_PATH" "$RELEASE_DIR/.previous-build"

echo "Build complete: $DMG_PATH and ${HOME}/Desktop/${DISPLAY_NAME}.dmg"
