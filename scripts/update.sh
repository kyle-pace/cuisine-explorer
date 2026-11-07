#!/usr/bin/env bash
# Rebuild data/cuisines.json from Wikipedia's List of cuisines.
# Run locally or from the scheduled GitHub Action.
set -euo pipefail
cd "$(dirname "$0")/.."
mkdir -p raw data

UA="CuisineExplorer/0.1 (https://kylepace.net/labs)"
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
