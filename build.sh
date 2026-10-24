#!/bin/bash
# Builds "SL Template Editor.app" for Apple Silicon (and Intel if available) and puts it next to this folder.
set -euo pipefail
cd "$(dirname "$0")"

echo "▸ Running tests…"
swift test 2>&1 | tail -n 5

echo "▸ Building release binary…"
swift build -c release
BIN_DIR="$(swift build -c release --show-bin-path)"

APP="../SL Template Editor.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN_DIR/SLTemplateEditor" "$APP/Contents/MacOS/SLTemplateEditor"
# App icon: drawn in the app's display font (system, black, condensed), then packed into an .icns.
echo "▸ Drawing app icon…"
swift Tools/make_icon.swift Assets/AppIcon.iconset
iconutil -c icns Assets/AppIcon.iconset -o Assets/AppIcon.icns
cp Assets/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>SL Template Editor</string>
    <key>CFBundleDisplayName</key><string>SL Template Editor</string>
    <key>CFBundleIdentifier</key><string>local.sl-template-editor</string>
    <key>CFBundleExecutable</key><string>SLTemplateEditor</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>13.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSPrincipalClass</key><string>NSApplication</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.music</string>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP" >/dev/null
# Make Finder and the Dock pick up a changed icon.
touch "$APP"
echo "✓ Built: $(cd .. && pwd)/SL Template Editor.app"
