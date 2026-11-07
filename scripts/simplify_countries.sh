#!/usr/bin/env bash
# Country shapes for the globe: Natural Earth 1:50m countries, with Tibet drawn as
# its own area (the Tibet Autonomous Region, from Natural Earth's 1:10m provinces)
# rather than as part of China. Simplified, then rings flipped to the clockwise
# winding globe.gl expects (mapshaper writes counterclockwise).
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p raw
NE=https://raw.githubusercontent.com/nvkelso/natural-earth-vector/master/geojson
[ -f raw/ne_50m.geojson ] || curl -sSfL -o raw/ne_50m.geojson "$NE/ne_50m_admin_0_countries.geojson"
[ -f raw/ne_10m_admin1.geojson ] || curl -sSfL -o raw/ne_10m_admin1.geojson "$NE/ne_10m_admin_1_states_provinces.geojson"

python3 - <<'PY'
import json
g = json.load(open("raw/ne_10m_admin1.geojson"))["features"]
tibet = next(f for f in g if f["properties"]["adm0_a3"] == "CHN" and f["properties"]["name"] == "Xizang")
json.dump({"type": "FeatureCollection", "features": [{"type": "Feature",
    "properties": {"NAME": "Tibet", "ADM0_A3": "TIB", "ISO_A3_EH": "TIB"},
    "geometry": tibet["geometry"]}]}, open("raw/tibet.geojson", "w"))
PY

# Cut Tibet out of China, add it back as its own shape, then simplify everything together
npx -y mapshaper@0.6 -i raw/ne_50m.geojson raw/tibet.geojson combine-files \
  -filter-fields target=ne_50m NAME,ADM0_A3,ISO_A3_EH \
  -erase target=ne_50m tibet \
  -merge-layers target=ne_50m,tibet force \
  -simplify 12% keep-shapes \
  -o data/countries.geojson precision=0.01 format=geojson

python3 - <<'PY'
import json
def area(r): return sum(r[i][0]*r[i+1][1]-r[i+1][0]*r[i][1] for i in range(len(r)-1))
g = json.load(open("data/countries.geojson"))
g["features"] = [f for f in g["features"] if f.get("geometry")]
for f in g["features"]:
    geom = f["geometry"]
    polys = geom["coordinates"] if geom["type"] == "MultiPolygon" else [geom["coordinates"]]
    for poly in polys:
        for i, ring in enumerate(poly):
            # exterior clockwise, holes counterclockwise
            if (area(ring) > 0) == (i == 0):
                ring.reverse()
json.dump(g, open("data/countries.geojson", "w"), separators=(",", ":"))
print(len(g["features"]), "shapes, including", [f["properties"]["NAME"] for f in g["features"] if f["properties"]["ADM0_A3"] in ("TIB", "CHN")])
PY
