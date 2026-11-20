#!/usr/bin/bash
# Render Legix branding to PNG: the boot-animation parts (branding/plymouth/)
# for the Plymouth theme, and the logo icon in the usual hicolor sizes.
# Runs in the branding-assets build stage (fedora:45), so rsvg-convert never
# has to be installed in the image itself.
#   render.sh <branding dir> <out dir>   ->  <out>/plymouth/*.png, <out>/icons/<size>.png
set -euxo pipefail
branding="$1"
src="$branding/plymouth"
out="$2/plymouth"
icons="$2/icons"
mkdir -p "$out" "$icons"
# Logo parts share one 200x200 canvas. 768 px covers a 30%-of-short-side logo
# on screens up to 2560 px; the theme scales down from there.
for part in l-left l-right v gem gem-glow; do
  rsvg-convert -w 768 -h 768 "$src/$part.svg" -o "$out/$part.png"
done
rsvg-convert -w 768 "$src/wordmark.svg" -o "$out/wordmark.png"
rsvg-convert -w 4 -h 4 "$src/bar.svg" -o "$out/bar.png"
rsvg-convert -w 4 -h 4 "$src/bar-bg.svg" -o "$out/bar-bg.png"
for size in 16 22 24 32 48 64 128 256 512; do
  rsvg-convert -w "$size" -h "$size" "$branding/legix-mark.svg" -o "$icons/$size.png"
done
ls -l "$out" "$icons"
