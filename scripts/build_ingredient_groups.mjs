// Every World cuisine ingredient, grouped into "neighborhoods" of what's cooked together,
// for the ingredients page (/world-cuisine/ingredients/).
//
// 1. Links: two ingredients in three or more dishes are linked by how often they share a
//    dish, scaled so that everyday ingredients (sugar, egg, flour) don't link to
//    everything: together / sqrt(dishesA * dishesB). Each keeps its strongest few links.
// 2. Neighborhoods: Louvain community detection on those links (groups with many links
//    inside and few outside), with tiny groups folded into their closest neighbor. Each is
//    named for its two most-used ingredients, plus the cuisines its dishes come from most.
// 3. Everyone else: an ingredient in fewer dishes joins the neighborhood its dish-mates
//    belong to most (rare dish-mates count for more than everyday ones). Ingredients whose
//    dishes share nothing with a neighborhood go on a last shelf, so every ingredient is listed.
// 4. Order: neighborhoods that share the most sit next to each other, biggest first.
//
// Writes data/ingredient_groups.json. Run: node scripts/build_ingredient_groups.mjs
import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { slug } from '../render_item.js';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');

export const MIN_DISHES = 3; // an ingredient needs this many dishes to help form a neighborhood
export const MIN_TOGETHER = 2; // two ingredients need this many shared dishes to be linked
export const KEEP_LINKS = 6; // strongest links kept per ingredient
export const MIN_GROUP = 4; // smaller neighborhoods are folded into their closest one
export const LEAD = 8; // most-used ingredients shown first and larger on each shelf

/** Ingredients in enough dishes, their dish counts, and the scaled links between them. Skips bad records. */
export function linksFrom(dishes, { minDishes = MIN_DISHES, minTogether = MIN_TOGETHER, keep = KEEP_LINKS } = {}) {
  const valid = (Array.isArray(dishes) ? dishes : []).filter((d) => d && Array.isArray(d.ingredients));
  const count = new Map();
  for (const d of valid) for (const i of new Set(d.ingredients.filter((x) => typeof x === 'string' && x))) count.set(i, (count.get(i) ?? 0) + 1);
  const on = new Set([...count].filter(([, n]) => n >= minDishes).map(([i]) => i));
  const together = new Map();
  for (const d of valid) {
    const l = [...new Set(d.ingredients)].filter((i) => on.has(i)).sort();
    for (let a = 0; a < l.length; a++) for (let b = a + 1; b < l.length; b++) {
      const k = l[a] + '\u0000' + l[b];
      together.set(k, (together.get(k) ?? 0) + 1);
    }
  }
  const all = [];
  for (const [k, n] of together) {
    if (n < minTogether) continue;
    const [a, b] = k.split('\u0000');
    all.push({ a, b, n, w: n / Math.sqrt(count.get(a) * count.get(b)) });
  }
  // Keep each ingredient's strongest links (a link stays if either end keeps it)
  const byNode = new Map();
  for (const l of all) for (const x of [l.a, l.b]) (byNode.get(x) ?? byNode.set(x, []).get(x)).push(l);
  const kept = new Set();
  for (const ls of byNode.values()) for (const l of ls.sort((p, q) => q.w - p.w || q.n - p.n).slice(0, keep)) kept.add(l);
  const links = [...kept].sort((p, q) => q.w - p.w || (p.a + p.b).localeCompare(q.a + q.b));
  const linked = new Set(links.flatMap((l) => [l.a, l.b]));
  const nodes = [...on].filter((i) => linked.has(i)).sort();
  return { nodes, count, links };
}

/** Louvain community detection on a weighted, undirected graph. Deterministic. Returns Map(node -> group number). */
export function louvain(nodes, links, resolution = 1) {
  let ids = nodes.map((_, i) => i);
  let edges = links.map((l) => [nodes.indexOf(l.a), nodes.indexOf(l.b), l.w]).filter(([a, b]) => a >= 0 && b >= 0);
  let member = nodes.map((_, i) => i); // original node -> current super-node
  for (let level = 0; level < 10; level++) {
    const n = ids.length;
    const adj = Array.from({ length: n }, () => new Map());
    for (const [a, b, w] of edges) {
      adj[a].set(b, (adj[a].get(b) ?? 0) + w);
      if (a !== b) adj[b].set(a, (adj[b].get(a) ?? 0) + w);
    }
    const k = adj.map((m, i) => [...m].reduce((s, [j, w]) => s + (j === i ? 2 * w : w), 0));
    const m2 = k.reduce((s, x) => s + x, 0);
    if (!m2) break;
    const comm = ids.map((_, i) => i);
    const tot = [...k];
    let moved = true;
    let anyMove = false;
    for (let pass = 0; moved && pass < 50; pass++) {
      moved = false;
      for (let i = 0; i < n; i++) {
        const ci = comm[i];
        const toComm = new Map();
        for (const [j, w] of adj[i]) if (j !== i) toComm.set(comm[j], (toComm.get(comm[j]) ?? 0) + w);
        tot[ci] -= k[i];
        let best = ci;
        let bestGain = (toComm.get(ci) ?? 0) - (resolution * tot[ci] * k[i]) / m2;
        for (const [c, w] of [...toComm].sort((p, q) => p[0] - q[0])) {
          const gain = w - (resolution * tot[c] * k[i]) / m2;
          if (gain > bestGain + 1e-12) { best = c; bestGain = gain; }
        }
        tot[best] += k[i];
        if (best !== ci) { comm[i] = best; moved = true; anyMove = true; }
      }
    }
    if (!anyMove) break;
    const renum = new Map();
    for (const c of comm) if (!renum.has(c)) renum.set(c, renum.size);
    member = member.map((s) => renum.get(comm[s]));
    const agg = new Map();
    for (const [a, b, w] of edges) {
      const x = renum.get(comm[a]); const y = renum.get(comm[b]);
      const key = Math.min(x, y) + ',' + Math.max(x, y);
      agg.set(key, (agg.get(key) ?? 0) + w);
    }
    edges = [...agg].map(([key, w]) => { const [x, y] = key.split(',').map(Number); return [x, y, w]; });
    ids = [...renum.values()];
  }
  return new Map(nodes.map((id, i) => [id, member[i]]));
}

/** Folds groups smaller than minGroup into the group they link to most, and numbers groups biggest first. */
export function tidyGroups(group, links, minGroup = MIN_GROUP) {
  const g = new Map(group);
  for (let round = 0; round < 5; round++) {
    const size = new Map();
    for (const c of g.values()) size.set(c, (size.get(c) ?? 0) + 1);
    let changed = false;
    for (const [node, c] of [...g].sort((p, q) => p[0].localeCompare(q[0]))) {
      if (size.get(c) >= minGroup) continue;
      const pull = new Map();
      for (const l of links) {
        const other = l.a === node ? l.b : l.b === node ? l.a : null;
        if (other && g.get(other) !== c) pull.set(g.get(other), (pull.get(g.get(other)) ?? 0) + l.w);
      }
      const best = [...pull].sort((p, q) => q[1] - p[1] || p[0] - q[0])[0];
      if (best) { size.set(c, size.get(c) - 1); size.set(best[0], (size.get(best[0]) ?? 0) + 1); g.set(node, best[0]); changed = true; }
    }
    if (!changed) break;
  }
  const size = new Map();
  for (const c of g.values()) size.set(c, (size.get(c) ?? 0) + 1);
  const order = [...size].sort((p, q) => q[1] - p[1] || p[0] - q[0]).map(([c]) => c);
  return new Map([...g].map(([node, c]) => [node, order.indexOf(c)]));
}

const shortCuisine = (c) => c.replace(/ cuisine$/i, '').replace(/^Cuisine of (the )?/i, '');
const byName = (a, b) => a.name.localeCompare(b.name, 'en', { sensitivity: 'base' });

/** Groups every ingredient in food.json into named neighborhoods, in reading order. */
export function buildGroups(food, { resolution = 1.6, lead = LEAD } = {}) {
  const dishes = (Array.isArray(food?.dishes) ? food.dishes : []).filter((d) => d && Array.isArray(d.ingredients));
  const { nodes, count, links } = linksFrom(dishes);
  // Ingredients with one page between them ("Atta flour" and "Atta (flour)" are both
  // /ingredient/atta-flour/) are listed once, under the name used in more dishes
  const bySlug = new Map();
  for (const i of Array.isArray(food?.ingredients) ? food.ingredients : []) {
    if (!i || typeof i.id !== 'string' || !i.id) continue;
    const s = slug(i.id), had = bySlug.get(s);
    if (!had || (count.get(i.id) ?? 0) > (count.get(had.id) ?? 0)) bySlug.set(s, i);
  }
  const ingredients = [...bySlug.values()];
  const group = tidyGroups(louvain(nodes, links, resolution), links);

  // Neighborhoods from the ingredients in enough dishes
  const groups = [];
  for (const [node, c] of group) (groups[c] ??= { id: c, core: [] }).core.push(node);
  for (const g of groups) {
    g.core.sort((a, b) => count.get(b) - count.get(a) || a.localeCompare(b));
    const set = new Set(g.core);
    const cz = new Map();
    for (const d of dishes) {
      if (d.ingredients.filter((i) => set.has(i)).length < 2) continue;
      for (const c of d.cuisines ?? []) cz.set(c, (cz.get(c) ?? 0) + 1);
    }
    g.cuisines = [...cz].sort((p, q) => q[1] - p[1] || p[0].localeCompare(q[0])).slice(0, 3).map(([c]) => shortCuisine(c));
  }

  // Everyone else joins the neighborhood its dish-mates belong to most
  const place = new Map(group);
  for (const ing of ingredients) {
    if (place.has(ing.id)) continue;
    const vote = new Map();
    for (const d of dishes) {
      if (!d.ingredients.includes(ing.id)) continue;
      for (const o of new Set(d.ingredients)) {
        if (o === ing.id || !group.has(o)) continue;
        vote.set(group.get(o), (vote.get(group.get(o)) ?? 0) + 1 / Math.sqrt(count.get(o)));
      }
    }
    const best = [...vote].sort((p, q) => q[1] - p[1] || p[0] - q[0])[0];
    place.set(ing.id, best ? best[0] : -1);
  }

  // Shelves: the most-used first, then the rest A to Z
  const entry = (i) => ({ id: i.id, name: i.name ?? i.id, slug: slug(i.id), dishes: count.get(i.id) ?? 0 });
  const shelf = (members) => {
    const all = members.map(entry);
    const top = [...all].sort((a, b) => b.dishes - a.dishes || byName(a, b)).slice(0, lead).filter((x) => x.dishes > 1);
    const topIds = new Set(top.map((x) => x.id));
    return { lead: top, rest: all.filter((x) => !topIds.has(x.id)).sort(byName), size: all.length };
  };
  const members = new Map();
  for (const ing of ingredients) (members.get(place.get(ing.id)) ?? members.set(place.get(ing.id), []).get(place.get(ing.id))).push(ing);
  const named = new Map(ingredients.map((i) => [i.id, i.name ?? i.id]));
  const out = groups.map((g) => {
    const [a, b] = g.core.map((m) => (named.get(m) ?? m).toLowerCase());
    const name = b ? `${a[0].toUpperCase()}${a.slice(1)} and ${b}` : `${a[0].toUpperCase()}${a.slice(1)}`;
    return { id: `hood-${g.id}`, n: g.id, name, cuisines: g.cuisines, ...shelf(members.get(g.id) ?? []) };
  });

  // Reading order: start with the biggest, then each time the one sharing the most with the last
  const between = new Map();
  for (const l of links) {
    const ga = group.get(l.a), gb = group.get(l.b);
    if (ga !== gb) { const k = Math.min(ga, gb) + ',' + Math.max(ga, gb); between.set(k, (between.get(k) ?? 0) + l.w); }
  }
  const share = (a, b) => between.get(Math.min(a, b) + ',' + Math.max(a, b)) ?? 0;
  const left = [...out].sort((a, b) => b.size - a.size || a.n - b.n);
  const ordered = [left.shift()].filter(Boolean);
  while (left.length) {
    const last = ordered.at(-1).n;
    left.sort((a, b) => share(last, b.n) - share(last, a.n) || b.size - a.size || a.n - b.n);
    ordered.push(left.shift());
  }
  const alone = members.get(-1) ?? [];
  if (alone.length) ordered.push({ id: 'on-their-own', n: -1, name: 'On their own', cuisines: [], ...shelf(alone) });

  return {
    about: 'Every World cuisine ingredient, grouped by what it is cooked with. Built by scripts/build_ingredient_groups.mjs from data/food.json.',
    ingredients: ordered.reduce((s, g) => s + g.size, 0),
    groups: ordered.map(({ n, ...g }) => g),
  };
}

function main() {
  const food = JSON.parse(readFileSync(join(root, 'data/food.json'), 'utf8'));
  const out = buildGroups(food);
  const listed = new Set(out.groups.flatMap((g) => [...g.lead, ...g.rest].map((x) => x.id)));
  if (listed.size < 500 || out.groups.length < 4 || listed.size < food.ingredients.length * 0.9) {
    console.error(`Ingredient groups came out wrong (${listed.size} of ${food.ingredients.length} ingredients, ${out.groups.length} groups). Keeping the last ones.`);
    process.exit(1);
  }
  writeFileSync(join(root, 'data/ingredient_groups.json'), JSON.stringify(out) + '\n');
  console.log(`Ingredient groups: ${out.ingredients} ingredients on ${out.groups.length} shelves`);
  for (const g of out.groups) console.log(`  ${g.name} (${g.size}): ${g.cuisines.join(', ')}`);
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) main();
