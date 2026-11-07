#!/usr/bin/env bash
# Simplify Natural Earth 1:50m countries for the globe, then flip rings to the
# clockwise winding globe.gl expects (mapshaper writes counterclockwise).
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p raw
[ -f raw/ne_50m.geojson ] || curl -sSfL -o raw/ne_50m.geojson \
  https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson/ne_50m_admin_0_countries.geojson
npx -y mapshaper@0.6 raw/ne_50m.geojson -filter-fields NAME,ADM0_A3,ISO_A3_EH \
  -simplify 12% keep-shapes -o data/countries.geojson precision=0.01 format=geojson
python3 - <<'PY'
import json
def area(r): return sum(r[i][0]*r[i+1][1]-r[i+1][0]*r[i][1] for i in range(len(r)-1))
g = json.load(open("data/countries.geojson"))
for f in g["features"]:
    geom = f["geometry"]
    polys = geom["coordinates"] if geom["type"] == "MultiPolygon" else [geom["coordinates"]]
    for poly in polys:
        for i, ring in enumerate(poly):
            # exterior clockwise, holes counterclockwise
            if (area(ring) > 0) == (i == 0):
                ring.reverse()
json.dump(g, open("data/countries.geojson", "w"), separators=(",", ":"))
PY
