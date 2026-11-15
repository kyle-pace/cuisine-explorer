// Links World cuisine's ingredients to KitchenCatalog, the grocery list Henwood, Grocery
// Deals and Recipe search share, so an ingredient page can send you to recipes for it.
//
// For each ingredient in data/food.json:
//   1. a hand decision in data/catalog_overrides.json wins (a catalog id, or null for "don't link");
//   2. otherwise the catalog's own matcher, keeping only strong matches to ingredients
//      (not ready-made products).
// Then it adds how many recipes Recipe search has for each catalog id, read from its public
// index. If that can't be reached, the last counts are kept.
//
// Writes data/catalog_links.json: { built, recipesChecked, links: { <ingredient id>: { id, name, recipes } } }
//
//   node scripts/link_catalog.mjs            (normal run)
//   node scripts/link_catalog.mjs --offline  (don't fetch recipe counts; keep the last ones)
import { readFileSync, writeFileSync, existsSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { load, match } from './kitchen-catalog/catalog.mjs';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
export const RECIPE_INDEX = 'https://kylepace.dev/recipe-search/index.json';
export const recipesUrl = (id) => `https://kylepace.dev/recipe-search/?with=${encodeURIComponent(id)}`;

/** Wikipedia titles carry disambiguation in parentheses ("Maida (flour)"); the matcher wants the name. */
const plain = (name) => String(name).replace(/\s*\([^)]*\)/g, '').trim();

/**
 * The catalog id for each ingredient, or nothing. Skips (and reports) records it can't read,
 * so one bad record never takes down the rest.
 */
export function linkIngredients(catalog, ingredients, overrides = {}) {
  const links = {};
  const skipped = [];
  for (const ing of ingredients) {
    const key = ing?.id;
    const name = ing?.name ?? ing?.id;
    if (typeof key !== 'string' || !key || typeof name !== 'string' || !name) {
      skipped.push(ing);
      continue;
    }
    let id;
    if (Object.hasOwn(overrides, key)) id = overrides[key];
    else {
      const m = match(catalog, plain(name));
      id = m && m.strength === 'strong' && !catalog.items[m.id].product ? m.id : null;
    }
    if (id && catalog.items[id]) links[key] = { id, name: catalog.items[id].name };
    else if (id) skipped.push({ id: key, reason: `no catalog item ${id}` });
  }
  return { links, skipped };
}

/** { catalog id: number of recipes } from Recipe search's index (its `ing` rows are [id, name, count, ...]). */
export function recipeCounts(index) {
  const out = {};
  for (const row of index?.ing ?? []) if (Array.isArray(row) && typeof row[0] === 'string' && Number.isFinite(row[2])) out[row[0]] = row[2];
  return out;
}

async function fetchCounts() {
  const res = await fetch(RECIPE_INDEX, { signal: AbortSignal.timeout(30_000), headers: { 'user-agent': 'WorldCuisine/0.1 (https://kylepace.dev/world-cuisine/)' } });
  if (!res.ok) throw new Error(`${RECIPE_INDEX} answered ${res.status}`);
  const counts = recipeCounts(await res.json());
  if (Object.keys(counts).length < 50) throw new Error(`${RECIPE_INDEX} listed only ${Object.keys(counts).length} ingredients`);
  return counts;
}

async function main() {
  const read = (f) => JSON.parse(readFileSync(join(root, f), 'utf8'));
  const catalog = load(join(root, 'scripts/kitchen-catalog/catalog.json'));
  const ingredients = read('data/food.json').ingredients ?? [];
  const overrides = read('data/catalog_overrides.json').links ?? {};
  const outPath = join(root, 'data/catalog_links.json');
  const last = existsSync(outPath) ? JSON.parse(readFileSync(outPath, 'utf8')) : { links: {} };

  const { links, skipped } = linkIngredients(catalog, ingredients, overrides);
  if (ingredients.length && !Object.keys(links).length) {
    console.error('No ingredient linked to the catalog. Refusing to replace data/catalog_links.json.');
    process.exit(1);
  }

  // Recipe counts: fresh if Recipe search answers, otherwise the last run's.
  let counts = null;
  let recipesChecked = last.recipesChecked ?? null;
  if (!process.argv.includes('--offline')) {
    try {
      counts = await fetchCounts();
      recipesChecked = new Date().toISOString().slice(0, 10);
    } catch (e) {
      console.warn(`Recipe counts not refreshed, keeping the last ones: ${e.message}`);
    }
  }
  const lastCount = (id) => Object.values(last.links ?? {}).find((l) => l.id === id)?.recipes ?? 0;
  for (const l of Object.values(links)) l.recipes = counts ? (counts[l.id] ?? 0) : lastCount(l.id);

  const sorted = Object.fromEntries(Object.entries(links).sort(([a], [b]) => a.localeCompare(b)));
  writeFileSync(outPath, JSON.stringify({ built: new Date().toISOString().slice(0, 10), recipesChecked, links: sorted }, null, 1) + '\n');
  const withRecipes = Object.values(sorted).filter((l) => l.recipes > 0).length;
  console.log(`Linked ${Object.keys(sorted).length} of ${ingredients.length} ingredients to the catalog; ${withRecipes} have recipes.`);
  for (const s of skipped) console.warn('Skipped:', JSON.stringify(s));
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) await main();
