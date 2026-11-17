#!/bin/bash
# Compila StayAwake e lo installa in ~/Applications. Uso: ./installa.sh
set -euo pipefail
# Le macro di SwiftUI (@State) richiedono Xcode completo, non solo i Command Line Tools.
if [ -d /Applications/Xcode.app ]; then export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer; fi
cd "$(dirname "$0")"

APP="$HOME/Applications/StayAwake.app"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT

mkdir -p "$BUILD/StayAwake.app/Contents/MacOS" "$HOME/Applications"

swiftc -O -parse-as-library -swift-version 5 Sources/*.swift -o "$BUILD/StayAwake.app/Contents/MacOS/StayAwake"

cat > "$BUILD/StayAwake.app/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0"><dict>
  <key>CFBundleIdentifier</key><string>it.riccardo.stayawake</string>
  <key>CFBundleName</key><string>StayAwake</string>
  <key>CFBundleExecutable</key><string>StayAwake</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>1.0</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSUIElement</key><true/>
</dict></plist>
PLIST

codesign --force --sign - "$BUILD/StayAwake.app"

pkill -x StayAwake 2>/dev/null || true
rm -rf "$APP"
cp -R "$BUILD/StayAwake.app" "$APP"
open "$APP"
echo "Installato in $APP — cerca il fulmine nella barra dei menu."
