#!/bin/zsh
# Costruisce "Macropad Config.app" nella cartella Macropad_Cablato.
set -e
cd "$(dirname "$0")"
export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
APP="../Macropad Config.app"

python3 tools/defaults_json.py
swift build -c release
rm -rf "$APP" .build/icon.iconset
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/MacropadConfig "$APP/Contents/MacOS/"
swift tools/make_icon.swift .build/icon.iconset
iconutil -c icns .build/icon.iconset -o "$APP/Contents/Resources/AppIcon.icns"
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
    <key>CFBundleShortVersionString</key><string>1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>14.0</string>
    <key>NSHighResolutionCapable</key><true/>
    <key>NSBluetoothAlwaysUsageDescription</key><string>Serve per collegarsi al macropad e cambiare le funzioni dei tasti.</string>
</dict>
</plist>
PLIST
# firma col certificato sviluppatore se c'è: così il Mac riconosce l'app anche dopo un aggiornamento
# e il permesso di Accessibilità (per il macropad virtuale) resta valido
IDENT=$(security find-identity -v -p codesigning | awk '/Apple Development/ && !/REVOKED/ {print $2; exit}')
codesign --force --sign "${IDENT:--}" "$APP"
echo "Pronta: $(cd .. && pwd)/Macropad Config.app"
# se l'app è installata in Applicazioni, aggiorna anche quella
INST="/Applications/Macropad Config.app"
if [ -d "$INST" ]; then
    osascript -e 'quit app id "com.andrea3dlab.macropadconfig"' 2>/dev/null || true
    rm -rf "$INST" && ditto "$APP" "$INST"
    echo "Aggiornata anche: $INST"
fi
