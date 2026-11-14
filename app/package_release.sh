#!/bin/zsh
# Builds "Macropad Config.app" for distribution: universal (Apple silicon + Intel), ad-hoc signed,
# zipped as dist/Macropad-Config-macOS.zip. Used by GitHub Actions for releases; also works locally.
set -e
cd "$(dirname "$0")"
python3 tools/defaults_json.py
swift build -c release --arch arm64 --arch x86_64
BIN=$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/MacropadConfig
OUT=dist; APP="$OUT/Macropad Config.app"
rm -rf "$OUT" .build/icon.iconset
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/"
swift tools/make_icon.swift .build/icon.iconset
iconutil -c icns .build/icon.iconset -o "$APP/Contents/Resources/AppIcon.icns"
VERSION=$(grep -o 'FW_VERSION "[^"]*' ../firmware/src/app_link.cpp | cut -d'"' -f2)
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Macropad Config</string>
    <key>CFBundleDisplayName</key><string>Macropad Config</string>
    <key>CFBundleIdentifier</key><string>com.andrea3dlab.macropadconfig</string>
    <key>CFBundleExecutable</key><string>MacropadConfig</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${VERSION}</string>
    <key>CFBundleVersion</key><string>${VERSION}</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSBluetoothAlwaysUsageDescription</key><string>Serve per collegarsi al macropad e cambiare le funzioni dei tasti.</string>
</dict>
</plist>
PLIST
codesign --force --deep --sign - "$APP"
(cd "$OUT" && ditto -c -k --keepParent "Macropad Config.app" Macropad-Config-macOS.zip)
lipo -info "$APP/Contents/MacOS/MacropadConfig"
echo "Ready: $(pwd)/$OUT/Macropad-Config-macOS.zip"
