#!/usr/bin/env bash
# Refreshes the self-hosted files in vendor/: the Atkinson Hyperlegible Next
# font and the two graph libraries. They're served from this site rather than
# from Google Fonts or a CDN, so visitors' browsers only talk to us.
#
# To update a library, change its version here and run: bash scripts/update-vendor.sh
set -euo pipefail

GLOBE_GL=2.46.2
FORCE_GRAPH=1.52.0
ATKINSON=5.3.0
WEIGHTS="400 500 600 700 800 400-italic"

root="$(cd "$(dirname "$0")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT

cd "$tmp"
npm pack --silent "globe.gl@$GLOBE_GL" "force-graph@$FORCE_GRAPH" "@fontsource/atkinson-hyperlegible-next@$ATKINSON" >/dev/null
for f in *.tgz; do mkdir "${f%.tgz}" && tar -xzf "$f" -C "${f%.tgz}"; done

mkdir -p "$root/vendor/fonts"
rm -f "$root/vendor/fonts/"*
cp "globe.gl-$GLOBE_GL/package/dist/globe.gl.min.js" "$root/vendor/globe.gl.min.js"
cp "force-graph-$FORCE_GRAPH/package/dist/force-graph.min.js" "$root/vendor/force-graph.min.js"

font="fontsource-atkinson-hyperlegible-next-$ATKINSON/package"
css="$root/vendor/fonts/atkinson.css"
echo "/* Atkinson Hyperlegible Next $ATKINSON (SIL Open Font License), from @fontsource. Made by scripts/update-vendor.sh. */" > "$css"
for w in $WEIGHTS; do
  # Keep the woff2 files only, and point the urls at this folder.
  sed -E \
    -e 's#url\(\./files/([^)]+\.woff2)\) format\(.woff2.\), url\([^)]+\.woff\) format\(.woff.\)#url(./\1) format("woff2")#' \
    "$font/$w.css" >> "$css"
  echo >> "$css"
  cp "$font/files/"*"-$( [[ $w == *italic ]] && echo "${w%-italic}-italic" || echo "$w-normal" ).woff2" "$root/vendor/fonts/"
done
cp "$font/LICENSE" "$root/vendor/fonts/LICENSE"

echo "vendor/ updated: globe.gl $GLOBE_GL, force-graph $FORCE_GRAPH, Atkinson Hyperlegible Next $ATKINSON"
