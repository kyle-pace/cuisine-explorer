# World cuisine

A globe for exploring the world's cuisines. Wikipedia's [List of cuisines](https://en.wikipedia.org/wiki/List_of_cuisines) is the source of truth: the explorer maps what's on that list, shows each cuisine's Wikipedia intro live, and links back for everything else. On top of that sit hand-picked cookbooks and recipe sites for each cuisine.

Live at **[kylepace.dev/world-cuisine](https://kylepace.dev/world-cuisine/)**, one of the experiments on [kylepace.dev](https://kylepace.dev). (It used to be Cuisine Explorer, at kylepace.net/labs/cuisines/.)

## How it works

- **Countries** are colored by continent, using the cuisine Wikipedia lists as that country's own.
- **Regional cuisines** (Sichuan, Oaxacan, Lanna) appear when you pick a country or zoom in: the provinces or states they come from are drawn as shapes, with a name label for each. Shapes come from matching Wikidata's "located in" places against Natural Earth's states and provinces (`scripts/build_regions.py`, `data/regions.geojson`).
- **Diaspora routes** are arcs from where a cuisine came from to where it took root (Chinese to Peru, Italian to the U.S.), worked out from names like "Peruvian-Chinese cuisine."
- **Beyond borders** collects what doesn't belong to one country: cuisines of peoples, religious diets, historical cuisines, and styles of cooking.

Nothing from Wikipedia is copied into the repo except page titles, links, and short Wikidata descriptions (used as a fallback). The intro on each card is fetched from Wikipedia when you open it.

## Dish drop (prototype)

`drop.html` is a daily game on the same globe: five dish photos a day, drop a pin where each comes from, scored by distance (the right country counts as full marks for a national dish). Everyone gets the same five on a given day; results stay in the browser. It plays at [kylepace.dev/world-cuisine/app/drop.html](https://kylepace.dev/world-cuisine/app/drop.html) and isn't linked from anywhere yet.

Its pool, `data/drop.json`, is built by `scripts/build_drop.mjs`: every dish with a photo that belongs to exactly one national or regional cuisine with a place on the map. Design notes are in `design/PLAN.md`.

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
- `regions`: hand-pick the states or provinces for a regional cuisine's shape, as `COUNTRY:Name` (for example `"Lanna cuisine": ["THA:Chiang Mai", ...]`). An empty list means no shape.

## Recipes for ingredients

Each ingredient is linked to [KitchenCatalog](https://github.com/kyle-pace/kitchen-catalog), the grocery list Recipe search, Henwood and Seattle Grocery Deals share, so an ingredient page can say "143 recipes with palm sugar" and link to [Recipe search](https://kylepace.dev/recipe-search/) with that ingredient picked. `scripts/link_catalog.mjs` runs in the weekly update:

1. A hand decision in `data/catalog_overrides.json` wins: a catalog id, or `null` for "don't link". Use it for names only Wikipedia uses (Agaricus bisporus is mushrooms, Maize is corn) and to turn off a wrong guess.
2. Otherwise the catalog's own matcher decides, keeping only strong matches to ingredients, not ready-made products.
3. Recipe counts come from Recipe search's public index. If it can't be reached, last week's counts stay.

It writes `data/catalog_links.json`. If a grocery is missing from the catalog altogether, add it in KitchenCatalog (and check its answer keys), then run `npm run sync-catalog` here: the copy lives in `scripts/kitchen-catalog/`, not `vendor/`, so it isn't published with the site. Tests: `node --test tests/*.test.mjs`.

## Every ingredient

[kylepace.dev/world-cuisine/ingredients/](https://kylepace.dev/world-cuisine/ingredients/) lists every ingredient under the part of the world where it's most at home. `scripts/build_ingredient_groups.mjs` runs in the weekly update and writes `data/ingredient_groups.json`:

1. Each cuisine gets a part of the world from Wikipedia's List of cuisines ("Asian cuisine > Maritime Southeast Asian cuisine" is Southeast Asia). A cuisine listed with only a continent borrows its part from related cuisines, then from other cuisines of the same country, on the same continent. Cuisines with no place (Jewish, Soviet) are Beyond borders, as on the globe. `REGION_FIXES` in the script holds the few places the list gets wrong (New Zealand is listed under Asia).
2. Each ingredient goes where the biggest share of a part's dishes use it, smoothed so one dish in a small part doesn't outweigh many elsewhere. One found in dishes from six or more parts is "All over the world" (garlic, sugar, egg). Ingredients in no dish yet get their own group.
3. Each part lists its six most-used first, then the rest A to Z. Ingredients that share a page (Wikipedia's "Atta flour" and "Atta (flour)") are listed once.

The page (`src/pages/world-cuisine/ingredients.astro`) has both orders, by part of the world and A to Z, as plain lists of links, with a find box, a part-of-the-world filter and an order switch kept in the address (`?where=southeast-asia&order=az`). Without JavaScript it shows the list by part of the world with links to each part. Ingredient pages link to their spot ("More from Southeast Asia", `#ing-<slug>`).

It started on November 14, 2026 as the ingredient map, a drawing of ingredients grouped by what they're cooked with; that was too crowded, then grouping by cooked-with read as arbitrary, so it became this. `/world-cuisine/ingredient-map/` redirects here. Share card: `node scripts/render-og.mjs ingredients`. Tests: `node --test tests/*.test.mjs`.

## Files

| Path | What it is |
| --- | --- |
| `index.html` | The whole explorer: one page, no build step |
| `data/cuisines.json` | Generated index of ~640 cuisines |
| `data/countries.geojson` | Country shapes (Natural Earth 1:50m, simplified) |
| `data/regions.geojson` | Shapes for regional cuisines (Natural Earth 1:10m states and provinces) |
| `data/summaries.json` | Each cuisine's Wikipedia intro, refreshed weekly |
| `data/suggestions.json` | Researched recipe sites and cookbooks, not yet reviewed |
| `data/picks.json` | Hand-picked cookbooks and recipe sites |
| `data/overrides.json` | Hand fixes for places and countries |
| `data/catalog_links.json` | Generated: each ingredient's KitchenCatalog id and recipe count |
| `data/catalog_overrides.json` | Hand decisions for linking ingredients to the catalog |
| `data/ingredient_groups.json` | Generated: every ingredient under its part of the world, for the Every ingredient page |
| `scripts/` | The data pipeline, plus `build_preview.py` for a single-file preview with data inlined |
| `og.png` | Share card |

## Running locally

```sh
python3 -m http.server 8000
# open http://localhost:8000
```

## Credits

Cuisine list and descriptions from Wikipedia and Wikidata (CC BY-SA / CC0). Country shapes from Natural Earth. Globe by [globe.gl](https://globe.gl).

## The site

The explorer is served by an Astro site on its own Cloudflare Worker, at kylepace.dev/world-cuisine/:

```sh
npm install
npm run dev       # http://localhost:4321/world-cuisine/
npm run build     # stages the explorer into public/world-cuisine/app/, then builds
npm run preview   # builds, then runs it the way Cloudflare will
```

| What | Where |
| --- | --- |
| The framed page | `src/pages/world-cuisine/index.astro` |
| Cuisine, dish and ingredient pages | `src/pages/world-cuisine/[type]/[slug].astro` (rendered on request, noindex) |
| Photos | `src/pages/world-cuisine/img/[...path].ts`, kept in the R2 bucket `kylepace-cuisine-images` |
| Staging the explorer | `scripts/stage-app.mjs` |
| Share card | `scripts/og-card.html`, rendered to `og.png` by `node scripts/render-og.mjs` |

Cloudflare Workers Builds deploys `main` (build `npm run build`, deploy `npx wrangler deploy`).
