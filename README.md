# Cuisine Explorer

A globe for exploring the world's cuisines. Wikipedia's [List of cuisines](https://en.wikipedia.org/wiki/List_of_cuisines) is the source of truth: the explorer maps what's on that list, shows each cuisine's Wikipedia intro live, and links back for everything else. On top of that sit hand-picked cookbooks and recipe sites for each cuisine.

A [kylepace.net](https://kylepace.net) labs project.

## How it works

- **Countries** are colored by continent, using the cuisine Wikipedia lists as that country's own.
- **Regional cuisines** (Sichuan, Oaxacan, Lanna) are small points of light, placed with coordinates from Wikidata.
- **Diaspora routes** are arcs from where a cuisine came from to where it took root (Chinese to Peru, Italian to the U.S.), worked out from names like "Peruvian-Chinese cuisine."
- **Beyond borders** collects what doesn't belong to one country: cuisines of peoples, religious diets, historical cuisines, and styles of cooking.

Nothing from Wikipedia is copied into the repo except page titles, links, and short Wikidata descriptions (used as a fallback). The intro on each card is fetched from Wikipedia when you open it.

## Adding picks

Edit `data/picks.json`. Key each cuisine by its Wikipedia page title, the same `id` used in `data/cuisines.json`:

```json
"cuisines": {
  "Thai cuisine": {
    "note": "Optional line on why these.",
    "cookbooks": [
      { "title": "...", "author": "...", "year": 2020, "isbn": "978...", "note": "..." }
    ],
    "sites": [
      { "name": "...", "url": "https://...", "type": "blog", "note": "..." }
    ]
  }
}
```

Covers load from Open Library when a cookbook has an ISBN. Picks show up as soon as the file is saved; no rebuild needed.

## Updating from Wikipedia

`./scripts/update.sh` re-reads the list, looks everything up on Wikidata, and rebuilds `data/cuisines.json`. A GitHub Action runs it every Monday and commits any changes.

When the automatic match puts something in the wrong place, fix it in `data/overrides.json`:

- `coords`: pin a cuisine to `[lat, lon]` (useful for peoples and historical cuisines Wikidata can't place).
- `iso`: force a cuisine's country (ISO 3166 alpha-3).

## Files

| Path | What it is |
| --- | --- |
| `index.html` | The whole explorer: one page, no build step |
| `data/cuisines.json` | Generated index of ~640 cuisines |
| `data/countries.geojson` | Country shapes (Natural Earth 1:50m, simplified) |
| `data/picks.json` | Hand-picked cookbooks and recipe sites |
| `data/overrides.json` | Hand fixes for places and countries |
| `scripts/` | The data pipeline, plus `build_preview.py` for a single-file preview with data inlined |
| `og.png` | Share card |

## Running locally

```sh
python3 -m http.server 8000
# open http://localhost:8000
```

## Credits

Cuisine list and descriptions from Wikipedia and Wikidata (CC BY-SA / CC0). Country shapes from Natural Earth. Globe by [globe.gl](https://globe.gl).
