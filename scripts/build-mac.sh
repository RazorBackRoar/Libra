#!/bin/bash
set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$SCRIPT_DIR/.."

# Machine-safe SwiftPM product / Mach-O name.
EXEC_NAME="Libra"
# User-facing bundle + DMG names (brand).
DISPLAY_NAME="Libra"
BUNDLE_ID="com.razorbackroar.libra"

# Resolve Swift Package version from version.json
VERSION="$(sed -n 's/.*"version".*"\([^"]*\)".*/\1/p' "$PROJECT_DIR/Sources/Libra/Resources/version.json")"

RELEASE_DIR="$PROJECT_DIR/build/Release"

# Named paths only — razorbuild invokes this script with zsh, which errors
# on unmatched *.app globs.
rm -rf \
  "$RELEASE_DIR/${DISPLAY_NAME}.app" \
  "$RELEASE_DIR/${EXEC_NAME}.app" \
  "$RELEASE_DIR/${DISPLAY_NAME}.dmg" \
  "$RELEASE_DIR/${EXEC_NAME}.dmg"
APP_PATH="$RELEASE_DIR/${DISPLAY_NAME}.app"
# Output file uses the machine-safe name.
DMG_PATH="$RELEASE_DIR/${EXEC_NAME}.dmg"
EXEC_PATH="$PROJECT_DIR/.build/release/$EXEC_NAME"
RESOURCE_BUNDLE="$PROJECT_DIR/.build/release/${EXEC_NAME}_${EXEC_NAME}.bundle"

# Packaging requires the shared razorcore helpers (locked DMG layout +
# branding gate). Fail fast with a pointer instead of a half-built release.
RAZORCORE_DIR="$(cd "$SCRIPT_DIR/../../.razorcore" 2>/dev/null && pwd || true)"
if [[ -z "$RAZORCORE_DIR" || ! -f "$RAZORCORE_DIR/package-dmg.sh" ]]; then
    echo "Error: razorcore packaging helpers not found." >&2
    echo "Libra's DMG layout is owned by Apps/.razorcore (see docs/BUILD_AND_RELEASE.md)." >&2
    echo "Build inside the RazorBackRoar workspace, or run 'swift build -c release' for the binary only." >&2
    exit 1
fi

echo "Building Libra release..."
cd "$PROJECT_DIR"

if [[ -f "$PROJECT_DIR/Libra.png" ]]; then
    ICON_PYTHON="${LIBRA_ICON_PYTHON:-}"
    if [[ -z "$ICON_PYTHON" ]] && command -v uv >/dev/null 2>&1; then
        echo "Generating Libra.icns with uv + Pillow..."
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
# package-dmg.sh fail-closes unless the plist carries the current year, so the
# year stamp must stay date-derived — not a fixed literal.
"$RAZORCORE_DIR/patch-app-branding.sh" "$APP_PATH"

echo "Ad-hoc signing ${DISPLAY_NAME}.app..."
# No nested code in this bundle — --deep is deprecated and unnecessary.
codesign --force --sign - "$APP_PATH"

echo "Creating ${DISPLAY_NAME}.dmg with shared layout..."
mkdir -p "$RELEASE_DIR"
"$RAZORCORE_DIR/package-dmg.sh" \
  --app "$APP_PATH" \
  --dmg "$DMG_PATH" \
  --app-name "$DISPLAY_NAME" \
  --volname "$DISPLAY_NAME"

# package-dmg.sh keeps the in-repo DMG and copies one to the Desktop. Do not mount or install.
# Delete only the staging .app.
rm -rf "$APP_PATH" "$RELEASE_DIR/.previous-build"

echo "Build complete: $DMG_PATH"
