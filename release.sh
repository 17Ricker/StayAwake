#!/bin/bash
# Prepara la release: test, app universale (Apple Silicon + Intel) firmata ad-hoc con hardened runtime,
# zip e hash SHA-256.
# Uso: ./release.sh   →   build/release/StayAwake.zip  +  build/release/StayAwake.zip.sha256
set -euo pipefail
# Le macro di SwiftUI richiedono Xcode completo, non solo i Command Line Tools.
if [ -z "${DEVELOPER_DIR:-}" ] && [ -d /Applications/Xcode.app ]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
cd "$(dirname "$0")"

./test.sh

OUT="build/release"
APP="$OUT/StayAwake.app"
rm -rf "$OUT"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

for ARCH in arm64 x86_64; do
  echo "Compilo per ${ARCH}…"
  swiftc -O -parse-as-library -swift-version 5 -target "$ARCH-apple-macos14" \
    Sources/*.swift -o "$OUT/StayAwake-$ARCH"
done
lipo -create "$OUT/StayAwake-arm64" "$OUT/StayAwake-x86_64" -output "$APP/Contents/MacOS/StayAwake"
rm "$OUT/StayAwake-arm64" "$OUT/StayAwake-x86_64"
cp Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"

# Firma ad-hoc (gratuita, senza Developer ID) con hardened runtime.
codesign --force --options runtime --sign - "$APP"

ditto -c -k --keepParent "$APP" "$OUT/StayAwake.zip"
(cd "$OUT" && shasum -a 256 StayAwake.zip > StayAwake.zip.sha256)

echo "Pronto: $OUT/StayAwake.zip ($(lipo -archs "$APP/Contents/MacOS/StayAwake"))"
cat "$OUT/StayAwake.zip.sha256"
