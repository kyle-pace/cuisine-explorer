#!/usr/bin/env bash
# Rebuild data/cuisines.json from Wikipedia's List of cuisines.
# Run locally or from the scheduled GitHub Action.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p raw data

UA="WorldCuisine/0.1 (https://kylepace.dev/world-cuisine/)"
curl -sSfL -A "$UA" "https://en.wikipedia.org/w/index.php?title=List_of_cuisines&action=raw" -o raw/list.wikitext

python3 scripts/parse_list.py raw/list.wikitext data/list_entries.json
python3 scripts/resolve_redirects.py data/list_entries.json raw/redirects.json
python3 scripts/fetch_summaries.py data/list_entries.json data/summaries.json
python3 scripts/fetch_wikidata.py data/list_entries.json raw/wikidata.json

# Look up redirect targets on Wikidata too, and merge them in
python3 - <<'PY'
import json, sys
sys.path.insert(0, "scripts")
import fetch_wikidata as f
red = json.load(open("raw/redirects.json"))
json.dump([{"title": t} for t in set(red.values())], open("raw/_redirect_entries.json", "w"))
f.main("raw/_redirect_entries.json", "raw/_wikidata_redirects.json")
wd = json.load(open("raw/wikidata.json"))
wd.update(json.load(open("raw/_wikidata_redirects.json")))
json.dump(wd, open("raw/wikidata.json", "w"), ensure_ascii=False, indent=1)
PY

python3 scripts/build.py
python3 scripts/merge_notes.py
python3 scripts/build_regions.py

# Dishes and ingredients: Wikidata first, then infobox ingredients, then again to merge them
python3 scripts/fetch_dishes.py
python3 scripts/fetch_infobox_ingredients.py
python3 scripts/fetch_dishes.py
# Hand-written notes (content/) on top of the food data, then intros
python3 scripts/merge_notes.py
python3 scripts/fetch_food_summaries.py

# Where ingredients are grown (FAOSTAT, CC BY 4.0)
python3 scripts/fetch_faostat.py

# Photos and their credits (Wikidata, Wikipedia page images, Wikimedia Commons)
python3 scripts/fetch_images.py

# The web view: page models, the skeleton and the graph layout (needs `npm ci` for d3-force)
node scripts/build_web.mjs
node scripts/build_app_index.mjs
# Dish drop's pool of playable dishes (drop.html)
node scripts/build_drop.mjs

# Last step: refuse to publish a build that lost a big share of its cuisines, dishes,
# ingredients or photos since the last commit (a fetch that failed partway). The run goes
# red and the commit step never happens.
python3 scripts/check_data.py
