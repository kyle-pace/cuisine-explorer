// Every World cuisine ingredient, placed under the part of the world where it's most at home,
// for the ingredients page (/world-cuisine/ingredients/).
//
// 1. Each cuisine gets a part of the world from Wikipedia's List of cuisines (data/cuisines.json),
//    e.g. "Asian cuisine > Maritime Southeast Asian cuisine" becomes Southeast Asia. A cuisine
//    listed with only a continent borrows the part from its parent or child cuisines, then from
//    other cuisines of the same country, as long as it's on the same continent. Cuisines with no
//    place (Jewish, Soviet, vegetarian) are Beyond borders, as on the globe. REGION_FIXES holds
//    the few places Wikipedia's list gets wrong.
// 2. Each ingredient goes where the biggest share of a part's dishes use it (smoothed, so one
//    dish in a part with few dishes doesn't outweigh many dishes elsewhere). One that shows up
//    in dishes from EVERYWHERE or more parts goes under All over the world instead.
// 3. Each part lists its most-used ingredients first, then the rest A to Z. Ingredients that
//    share a page (Wikipedia's "Atta flour" and "Atta (flour)") are listed once.
//
// Writes data/ingredient_groups.json. Run: node scripts/build_ingredient_groups.mjs
import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { slug } from '../render_item.js';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');

export const EVERYWHERE = 6; // parts of the world an ingredient needs to be "all over the world"
export const SMOOTH = 20; // dishes added to each part's count when comparing shares
export const LEAD = 6; // most-used ingredients shown first and larger in each part

// Wikipedia's second level, as the page names it, by continent
export const PARTS = {
  Africa: { 'North African cuisine': 'North Africa', 'West African cuisine': 'West Africa', 'Central African cuisine': 'Central Africa', 'East African cuisine': 'East Africa', 'Southern African cuisine': 'Southern Africa' },
  'The Americas': { 'North American cuisine': 'North America', 'Central American cuisine': 'Central America', 'Caribbean cuisine': 'The Caribbean', 'South American cuisine': 'South America' },
  Asia: { 'West Asian cuisine': 'West Asia', 'Central Asian cuisine': 'Central and North Asia', 'North Asian cuisine': 'Central and North Asia', 'Highland Asian cuisine': 'Central and North Asia', 'South Asian cuisine': 'South Asia', 'East Asian cuisine': 'East Asia', 'Mainland Southeast Asian cuisine': 'Southeast Asia', 'Maritime Southeast Asian cuisine': 'Southeast Asia' },
  Europe: { 'Northern European cuisine': 'Northern Europe', 'British Isles cuisine': 'The British Isles', 'Western European cuisine': 'Western Europe', 'Central European cuisine': 'Central Europe', 'Eastern European cuisine': 'Eastern Europe', 'Southern European cuisine': 'Southern Europe', 'South Eastern European cuisine': 'Southeast Europe' },
  Oceania: {},
};
const CONTINENT = { 'African cuisine': 'Africa', 'Cuisine of the Americas': 'The Americas', 'Asian cuisine': 'Asia', 'European cuisine': 'Europe', 'Oceanic cuisine': 'Oceania' };
// Where Wikipedia's list puts a cuisine on the wrong continent
export const REGION_FIXES = { 'New Zealand cuisine': ['Oceanic cuisine'] };
export const ALL_OVER = 'All over the world';
export const BEYOND = 'Beyond borders';
export const NO_DISH = 'Not in a dish yet';

export const idOf = (name) => slug(name);

/** Map of cuisine id -> { part, continent }. */
export function cuisineParts(cuisines) {
  const list = (Array.isArray(cuisines) ? cuisines : []).filter((c) => c && typeof c.id === 'string');
  const byId = new Map(list.map((c) => [c.id, c]));
  const region = (c) => REGION_FIXES[c.id] ?? c.region ?? [];
  const own = (c) => {
    const cont = CONTINENT[region(c)[0]];
    const part = cont && PARTS[cont][region(c)[1]];
    return cont ? { continent: cont, part: part ?? null } : null;
  };
  const byIso = new Map();
  for (const c of list) {
    const o = own(c);
    if (o?.part && c.iso3) (byIso.get(c.iso3) ?? byIso.set(c.iso3, []).get(c.iso3)).push(o);
  }
  const most = (xs, continent) => {
    const n = new Map();
    for (const x of xs) if (x?.part && x.continent === continent) n.set(x.part, (n.get(x.part) ?? 0) + 1);
    return [...n].sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0]))[0]?.[0] ?? null;
  };
  const out = new Map();
  for (const c of list) {
    const o = own(c);
    if (!o) { out.set(c.id, { part: BEYOND, continent: null }); continue; }
    const part = o.part
      ?? most([...(c.parents ?? []), ...(c.children ?? [])].map((id) => byId.get(id) && own(byId.get(id))), o.continent)
      ?? most(byIso.get(c.iso3) ?? [], o.continent)
      ?? o.continent; // Oceania, or a continent-wide cuisine
    out.set(c.id, { part, continent: o.continent });
  }
  return out;
}

const byName = (a, b) => a.name.localeCompare(b.name, 'en', { sensitivity: 'base' });
const shortCuisine = (c) => c.replace(/ cuisine$/i, '').replace(/ foodways$/i, '').replace(/^Cuisine of (the )?/i, '');

/** Places every ingredient in food.json under a part of the world. */
export function buildGroups(food, cuisines, { everywhere = EVERYWHERE, smooth = SMOOTH, lead = LEAD } = {}) {
  const parts = cuisineParts(cuisines);
  const dishes = (Array.isArray(food?.dishes) ? food.dishes : []).filter((d) => d && Array.isArray(d.ingredients));
  const total = new Map(); // part -> dishes
  const uses = new Map(); // ingredient -> part -> dishes
  const count = new Map(); // ingredient -> dishes
  const cuisineUses = new Map(); // part -> cuisine -> dishes, for each part's one-line description
  for (const d of dishes) {
    const cs = (Array.isArray(d.cuisines) ? d.cuisines : []).filter((c) => parts.has(c));
    const ps = [...new Set(cs.map((c) => parts.get(c).part))];
    for (const p of ps) total.set(p, (total.get(p) ?? 0) + 1);
    for (const c of cs) { const m = cuisineUses.get(parts.get(c).part) ?? cuisineUses.set(parts.get(c).part, new Map()).get(parts.get(c).part); m.set(c, (m.get(c) ?? 0) + 1); }
    for (const i of new Set(d.ingredients.filter((x) => typeof x === 'string' && x))) {
      count.set(i, (count.get(i) ?? 0) + 1);
      const m = uses.get(i) ?? uses.set(i, new Map()).get(i);
      for (const p of ps) m.set(p, (m.get(p) ?? 0) + 1);
    }
  }

  // Ingredients with one page between them are listed once, under the name used in more dishes
  const bySlug = new Map();
  for (const i of Array.isArray(food?.ingredients) ? food.ingredients : []) {
    if (!i || typeof i.id !== 'string' || !i.id) continue;
    const s = slug(i.id), had = bySlug.get(s);
    if (!had || (count.get(i.id) ?? 0) > (count.get(had.id) ?? 0)) bySlug.set(s, i);
  }

  const home = new Map(); // part -> [ingredient entries]
  const continentOf = new Map([[ALL_OVER, null], [BEYOND, null], [NO_DISH, null]]);
  for (const v of parts.values()) if (v.continent) continentOf.set(v.part, v.continent);
  for (const i of bySlug.values()) {
    const m = uses.get(i.id);
    let part = NO_DISH, here = 0;
    if (m?.size) {
      if (m.size >= everywhere) { part = ALL_OVER; here = count.get(i.id); }
      else {
        [part, here] = [...m].sort((a, b) => b[1] / (total.get(b[0]) + smooth) - a[1] / (total.get(a[0]) + smooth) || b[1] - a[1] || a[0].localeCompare(b[0]))[0];
      }
    }
    (home.get(part) ?? home.set(part, []).get(part)).push({ id: i.id, name: i.name ?? i.id, slug: slug(i.id), dishes: count.get(i.id) ?? 0, here });
  }

  const shelf = (part, items) => {
    const top = [...items].sort((a, b) => b.here - a.here || b.dishes - a.dishes || byName(a, b)).slice(0, lead).filter((x) => x.here > 1);
    const topIds = new Set(top.map((x) => x.id));
    const cz = [...(cuisineUses.get(part) ?? [])].sort((a, b) => b[1] - a[1] || a[0].localeCompare(b[0])).slice(0, 3).map(([c]) => shortCuisine(c));
    const cont = continentOf.get(part) ?? null;
    // A continent-wide cuisine's ingredients: "Across the Americas" (or just "Oceania", which has no parts)
    const name = cont && part === cont && Object.keys(PARTS[cont]).length ? `Across ${cont.replace(/^The /, 'the ')}` : part;
    return {
      id: idOf(name), name, continent: cont, dishes: total.get(part) ?? 0, cuisines: part === ALL_OVER ? [] : cz,
      lead: top.map(({ here, ...x }) => x), rest: items.filter((x) => !topIds.has(x.id)).sort(byName).map(({ here, ...x }) => x), size: items.length,
    };
  };
  // Reading order: all over the world, then continents A to Z with their parts in Wikipedia's order, then the rest
  const order = [ALL_OVER];
  for (const cont of Object.keys(PARTS)) {
    order.push(...new Set(Object.values(PARTS[cont])));
    order.push(cont);
  }
  order.push(BEYOND, NO_DISH);
  const groups = order.filter((p) => home.has(p)).map((p) => shelf(p, home.get(p)));
  const missing = [...home.keys()].filter((p) => !order.includes(p));
  if (missing.length) throw new Error(`No place in the reading order for: ${missing.join(', ')}`);
  return {
    about: 'Every World cuisine ingredient, under the part of the world where it is most at home. Built by scripts/build_ingredient_groups.mjs from data/food.json and data/cuisines.json.',
    ingredients: groups.reduce((s, g) => s + g.size, 0),
    everywhere,
    groups,
  };
}

function main() {
  const food = JSON.parse(readFileSync(join(root, 'data/food.json'), 'utf8'));
  const cuisines = JSON.parse(readFileSync(join(root, 'data/cuisines.json'), 'utf8')).cuisines;
  const out = buildGroups(food, cuisines);
  const listed = out.groups.flatMap((g) => [...g.lead, ...g.rest]).length;
  if (listed < 500 || out.groups.length < 8 || listed < food.ingredients.length * 0.9) {
    console.error(`Ingredient groups came out wrong (${listed} of ${food.ingredients.length} ingredients, ${out.groups.length} parts). Keeping the last ones.`);
    process.exit(1);
  }
  writeFileSync(join(root, 'data/ingredient_groups.json'), JSON.stringify(out) + '\n');
  console.log(`Ingredient groups: ${out.ingredients} ingredients in ${out.groups.length} parts of the world`);
  for (const g of out.groups) console.log(`  ${g.continent ? g.continent + ' / ' : ''}${g.name} (${g.size}): ${g.lead.map((x) => x.name).join(', ')}`);
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) main();
