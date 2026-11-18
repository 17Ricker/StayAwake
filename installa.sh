#!/bin/bash
# Compila StayAwake da questo codice e lo installa in ~/Applications. Uso: ./installa.sh
set -euo pipefail
# Le macro di SwiftUI (@State) richiedono Xcode completo, non solo i Command Line Tools.
if [ -d /Applications/Xcode.app ]; then export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer; fi
cd "$(dirname "$0")"

APP="$HOME/Applications/StayAwake.app"
BUILD="$(mktemp -d)"
trap 'rm -rf "$BUILD"' EXIT

mkdir -p "$BUILD/StayAwake.app/Contents/MacOS" "$BUILD/StayAwake.app/Contents/Resources" "$HOME/Applications"

swiftc -O -parse-as-library -swift-version 5 -target "$(uname -m)-apple-macos14" \
  Sources/*.swift -o "$BUILD/StayAwake.app/Contents/MacOS/StayAwake"
cp Info.plist "$BUILD/StayAwake.app/Contents/Info.plist"
cp Resources/AppIcon.icns "$BUILD/StayAwake.app/Contents/Resources/AppIcon.icns"

# Firma ad-hoc con hardened runtime.
codesign --force --options runtime --sign - "$BUILD/StayAwake.app"

pkill -x StayAwake 2>/dev/null || true
rm -rf "$APP"
cp -R "$BUILD/StayAwake.app" "$APP"
open "$APP"
echo "Installato in $APP — cerca il fulmine nella barra dei menu."
