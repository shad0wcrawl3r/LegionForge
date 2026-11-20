#!/usr/bin/bash
# Render the Legix boot-animation parts (branding/plymouth/*.svg) to PNG for the
# Plymouth script theme. Runs in the plymouth-assets build stage (fedora:45),
# so rsvg-convert never has to be installed in the image itself.
#   render.sh <svg dir> <out dir>
set -euxo pipefail
src="$1"
out="$2"
mkdir -p "$out"
# Logo parts share one 200x200 canvas. 768 px covers a 30%-of-short-side logo
# on screens up to 2560 px; the theme scales down from there.
for part in l-left l-right v gem gem-glow; do
  rsvg-convert -w 768 -h 768 "$src/$part.svg" -o "$out/$part.png"
done
rsvg-convert -w 768 "$src/wordmark.svg" -o "$out/wordmark.png"
rsvg-convert -w 4 -h 4 "$src/bar.svg" -o "$out/bar.png"
rsvg-convert -w 4 -h 4 "$src/bar-bg.svg" -o "$out/bar-bg.png"
ls -l "$out"
