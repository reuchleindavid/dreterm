#!/bin/zsh
# Baut DRETerm.app. Aufruf: ./build.sh [--install]  (--install kopiert nach /Applications)
set -e
cd "$(dirname "$0")"
APP=dist/DRETerm.app
swift build -c release 2>&1 | grep -v "xcrun: error" | tail -3
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp .build/release/DRETerm "$APP/Contents/MacOS/DRETerm"
if [[ ! -f Resources/AppIcon.icns || Scripts/make_icon.swift -nt Resources/AppIcon.icns || Resources/dre-logo.png -nt Resources/AppIcon.icns ]]; then
  mkdir -p Resources
  ICONSET=$(mktemp -d)/AppIcon.iconset
  swift Scripts/make_icon.swift Resources/dre-logo.png "$ICONSET"
  iconutil -c icns "$ICONSET" -o Resources/AppIcon.icns
fi
cp Resources/AppIcon.icns "$APP/Contents/Resources/"
VERSION=$(cat VERSION 2>/dev/null || echo 1.0)
cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleName</key><string>DRETerm</string>
  <key>CFBundleDisplayName</key><string>DRETerm</string>
  <key>CFBundleIdentifier</key><string>de.reuchlein.dreterm</string>
  <key>CFBundleExecutable</key><string>DRETerm</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>$VERSION</string>
  <key>CFBundleVersion</key><string>$VERSION</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.developer-tools</string>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSPrincipalClass</key><string>NSApplication</string>
  <key>CFBundleDevelopmentRegion</key><string>de</string>
</dict></plist>
PLIST
codesign --force --deep -s - "$APP" >/dev/null 2>&1
echo "Fertig: $APP"
if [[ "$1" == "--install" ]]; then
  osascript -e 'quit app "DRETerm"' 2>/dev/null || true
  rm -rf /Applications/DRETerm.app
  cp -R "$APP" /Applications/
  echo "Installiert: /Applications/DRETerm.app"
fi
