#!/bin/bash
# Rende lo spot nelle tre lingue (promo/out/, non in git) e le GIF per i README (docs/media/).
# Uso: promo/render.sh   (prima: promo/build-assets.sh)
set -euo pipefail
cd "$(dirname "$0")"
mkdir -p out ../docs/media

for lang in en it es; do
  npx -y hyperframes@0.9.65 render --quality delivery --variables-file "copy/$lang.json" --output "out/StayAwake-$lang-master.mp4"

  # H.264 entro 10 MB: è il limite dei video allegati su GitHub (piano gratuito)
  crf=18
  while :; do
    ffmpeg -v error -y -i "out/StayAwake-$lang-master.mp4" -c:v libx264 -preset slow -crf "$crf" \
      -pix_fmt yuv420p -movflags +faststart -an "out/StayAwake-$lang.mp4"
    [ "$(stat -f%z "out/StayAwake-$lang.mp4")" -le 10000000 ] && break
    crf=$((crf + 2))
  done
  echo "$lang: MP4 con crf $crf"

  # GIF del README: scene 4–14 s, entro 5 MB (prima 800 px a 12 fps, poi più leggera se serve)
  for opt in "800 12" "800 10" "720 10" "640 10"; do
    set -- $opt
    ffmpeg -v error -y -ss 4 -t 10 -i "out/StayAwake-$lang.mp4" -vf "fps=$2,scale=$1:-1:flags=lanczos,palettegen=stats_mode=diff" "out/palette-$lang.png"
    ffmpeg -v error -y -ss 4 -t 10 -i "out/StayAwake-$lang.mp4" -i "out/palette-$lang.png" \
      -lavfi "fps=$2,scale=$1:-1:flags=lanczos[x];[x][1:v]paletteuse=dither=bayer:bayer_scale=4:diff_mode=rectangle" "../docs/media/promo-$lang.gif"
    [ "$(stat -f%z "../docs/media/promo-$lang.gif")" -le 5000000 ] && { echo "$lang: GIF ${1}px ${2}fps"; break; }
  done
done
ls -la out/StayAwake-??.mp4 ../docs/media/promo-*.gif
