#!/bin/bash
# Rigenera le immagini vere dell'app: per la promo (promo/assets/ui/<lang>/, non in git)
# e per i README (docs/media/<lang>/). Uso: promo/build-assets.sh
set -euo pipefail
if [ -z "${DEVELOPER_DIR:-}" ] && [ -d /Applications/Xcode.app ]; then
  export DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer
fi
cd "$(dirname "$0")/.."

mkdir -p build
swiftc -D PREVIEW -swift-version 5 Sources/*.swift Preview/main.swift -o build/preview

for lang in en it es; do
  ui="promo/assets/ui/$lang"
  media="docs/media/$lang"
  rm -rf "$ui" && mkdir -p "$ui" "$media"
  build/preview "$ui" --lang "$lang" --promo > /dev/null
  for f in night-idle-90 night-timed-1 night-continuous retro-idle modern-idle settings menubar-timed; do
    cp "$ui/$f.png" "$media/$f.png"
    # Solo riduzioni: le immagini piccole (la barra dei menu) restano come sono
    width=$(sips -g pixelWidth "$media/$f.png" | awk '/pixelWidth/{print $2}')
    if [ "$width" -gt 900 ]; then sips -Z 900 "$media/$f.png" > /dev/null; fi
  done
done
echo "Immagini pronte: promo/assets/ui/{en,it,es} e docs/media/{en,it,es}"
