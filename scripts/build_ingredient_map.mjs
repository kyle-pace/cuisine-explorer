// The ingredient map: World cuisine's ingredients grouped into "neighborhoods" of what's
// cooked together, laid out once at build time so the page is a plain drawing.
//
// 1. Links: two ingredients are linked by how often they share a dish, scaled so that
//    everyday ingredients (sugar, egg, flour) don't link to everything:
//    together / sqrt(dishesA * dishesB). Each ingredient keeps its strongest few links.
// 2. Neighborhoods: Louvain community detection on those links (groups with many links
//    inside and few outside), with tiny groups folded into their closest neighbor.
// 3. Names: each neighborhood is named for its two most-used ingredients, plus the
//    cuisines its dishes come from most.
// 4. Layout (d3-force, deterministic): first each neighborhood is placed as one circle,
//    sized to fit its ingredients, with neighborhoods that share many links pulled close;
//    then each neighborhood's ingredients are packed around its spot.
//
// Writes data/ingredient_map.json. Run: node scripts/build_ingredient_map.mjs
import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { forceSimulation, forceLink, forceManyBody, forceX, forceY, forceCollide } from 'd3-force';
import { slug } from '../render_item.js';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');

export const MIN_DISHES = 3; // an ingredient needs this many dishes to be on the map
export const MIN_TOGETHER = 2; // two ingredients need this many shared dishes to be linked
export const KEEP_LINKS = 6; // strongest links kept per ingredient
export const MIN_GROUP = 4; // smaller neighborhoods are folded into their closest one
export const WIDTH = 1240;
export const HEIGHT = 900;

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

/** Builds the whole map: nodes with positions, kept links, and named neighborhoods. */
export function buildMap(food, { resolution = 1.6 } = {}) {
  const dishes = Array.isArray(food?.dishes) ? food.dishes : [];
  const ingName = new Map((food?.ingredients ?? []).filter((i) => i?.id).map((i) => [i.id, i.name ?? i.id]));
  const { nodes, count, links } = linksFrom(dishes);
  const group = tidyGroups(louvain(nodes, links, resolution), links);

  // Neighbors for each ingredient, strongest first
  const near = new Map(nodes.map((n) => [n, []]));
  for (const l of links) { near.get(l.a).push([l.b, l.w]); near.get(l.b).push([l.a, l.w]); }
  for (const l of near.values()) l.sort((p, q) => q[1] - p[1]);

  // Neighborhoods: members by dish count; cuisines of dishes with 2+ members
  const groups = [];
  for (const [node, c] of group) (groups[c] ??= { id: c, members: [] }).members.push(node);
  for (const g of groups) {
    g.members.sort((a, b) => count.get(b) - count.get(a) || a.localeCompare(b));
    const set = new Set(g.members);
    const cz = new Map();
    for (const d of dishes) {
      if (!Array.isArray(d?.ingredients) || d.ingredients.filter((i) => set.has(i)).length < 2) continue;
      for (const c of d.cuisines ?? []) cz.set(c, (cz.get(c) ?? 0) + 1);
    }
    g.cuisines = [...cz].sort((p, q) => q[1] - p[1] || p[0].localeCompare(q[0])).slice(0, 3).map(([c]) => shortCuisine(c));
    const [a, b] = g.members.map((m) => (ingName.get(m) ?? m).toLowerCase());
    g.name = b ? `${a[0].toUpperCase()}${a.slice(1)} and ${b}` : `${a[0].toUpperCase()}${a.slice(1)}`;
  }

  // Layout, step 1: each neighborhood as one circle, related ones pulled together
  const radius = (n) => 4 + Math.sqrt(count.get(n)) * 1.7;
  const between = new Map();
  for (const l of links) {
    const ga = group.get(l.a), gb = group.get(l.b);
    if (ga === gb) continue;
    const key = Math.min(ga, gb) + ',' + Math.max(ga, gb);
    between.set(key, (between.get(key) ?? 0) + l.w);
  }
  const hoods = groups.map((g) => {
    const area = g.members.reduce((s, m) => s + (radius(m) + 6) ** 2, 0);
    const r = Math.sqrt(area) * 1.6 + 24;
    return { g: g.id, r, room: Math.max(r, (g.name.length * 12.5) / 2 + 12) };
  });
  // A rough left-to-right order where each neighborhood sits next to the one it shares the
  // most with, starting from the biggest; then two rows, so the map comes out wide.
  const link = (a, b) => between.get(Math.min(a, b) + ',' + Math.max(a, b)) ?? 0;
  const order = [0];
  while (order.length < hoods.length) {
    const last = order.at(-1);
    const next = hoods.map((h) => h.g).filter((g) => !order.includes(g)).sort((a, b) => link(last, b) - link(last, a) || a - b)[0];
    order.push(next);
  }
  const rows = 2;
  const perRow = Math.ceil(order.length / rows);
  order.forEach((g, i) => {
    const row = Math.floor(i / perRow), col = row % 2 ? perRow - 1 - (i % perRow) : i % perRow; // snake, so neighbors stay close
    hoods[g].x = ((col + 0.5) / perRow) * WIDTH * 1.6;
    hoods[g].y = ((row + 0.5) / rows) * HEIGHT;
    hoods[g].hx = hoods[g].x;
  });
  const hoodLinks = [...between].map(([key, w]) => { const [a, b] = key.split(',').map(Number); return { source: hoods[a], target: hoods[b], w }; });
  const maxW = Math.max(...hoodLinks.map((l) => l.w), 1);
  forceSimulation(hoods)
    .force('link', forceLink(hoodLinks).distance((l) => l.source.room + l.target.room + 40).strength((l) => 0.02 + 0.1 * (l.w / maxW)))
    .force('collide', forceCollide((h) => h.room + 30).iterations(4))
    .force('x', forceX((h) => h.hx).strength(0.08))
    .force('y', forceY(HEIGHT / 2).strength(0.05))
    .stop()
    .tick(600);
  const homes = hoods.map((h) => [h.x, h.y]);

  // Step 2: each ingredient packed around its neighborhood's spot
  const sim = nodes.map((id) => ({ id, g: group.get(id), r: radius(id) }));
  const byId = new Map(sim.map((s) => [s.id, s]));
  sim.forEach((s, i) => { const [x, y] = homes[s.g]; s.x = x + Math.cos(i * 2.4) * 3 * Math.sqrt(i % 60); s.y = y + Math.sin(i * 2.4) * 3 * Math.sqrt(i % 60); });
  const simLinks = links.filter((l) => group.get(l.a) === group.get(l.b)).map((l) => ({ source: byId.get(l.a), target: byId.get(l.b), w: l.w }));
  forceSimulation(sim)
    .force('link', forceLink(simLinks).distance(30).strength((l) => 0.3 * l.w + 0.05))
    .force('charge', forceManyBody().strength(-14).distanceMax(80))
    .force('x', forceX((s) => homes[s.g][0]).strength(0.22))
    .force('y', forceY((s) => homes[s.g][1]).strength(0.22))
    .force('collide', forceCollide((s) => s.r + 8).iterations(3))
    .stop()
    .tick(500);

  // Fit to the drawing
  const pad = 90;
  const minX = Math.min(...sim.map((s) => s.x - s.r)); const maxX = Math.max(...sim.map((s) => s.x + s.r));
  const minY = Math.min(...sim.map((s) => s.y - s.r)); const maxY = Math.max(...sim.map((s) => s.y + s.r));
  const scale = Math.min((WIDTH - 2 * pad) / (maxX - minX), (HEIGHT - 2 * pad) / (maxY - minY), 1.4);
  const fit = (s) => [Math.round((pad + (s.x - minX) * scale) * 10) / 10, Math.round((pad + (s.y - minY) * scale) * 10) / 10];

  const outNodes = sim.map((s) => {
    const [x, y] = fit(s);
    return {
      id: s.id, name: ingName.get(s.id) ?? s.id, slug: slug(s.id), dishes: count.get(s.id), group: s.g, x, y,
      r: Math.round(s.r * scale * 10) / 10,
      near: near.get(s.id).slice(0, 5).map(([n]) => n),
    };
  }).sort((a, b) => b.dishes - a.dishes || a.id.localeCompare(b.id));
  // Each neighborhood's ground (a circle around its ingredients) and its name on top of it,
  // kept inside the drawing.
  const CHAR = 12.5; // about how wide a character of a 22px bold name is
  for (const g of groups) {
    const ms = outNodes.filter((n) => n.group === g.id);
    const cx = ms.reduce((s, n) => s + n.x, 0) / ms.length;
    const cy = ms.reduce((s, n) => s + n.y, 0) / ms.length;
    const gr = Math.max(...ms.map((n) => Math.hypot(n.x - cx, n.y - cy) + Math.min(n.r * 0.75, 20))) + 16;
    g.cx = Math.round(cx); g.cy = Math.round(cy); g.r = Math.round(gr);
    const half = (g.name.length * CHAR) / 2;
    g.x = Math.round(Math.min(Math.max(cx, half + 8), WIDTH - half - 8));
    g.y = Math.round(Math.max(cy - gr - 10, 26));
  }

  return {
    about: 'World cuisine ingredients grouped by what they are cooked with. Built by scripts/build_ingredient_map.mjs from data/food.json.',
    width: WIDTH,
    height: HEIGHT,
    nodes: outNodes,
    links: links.map((l) => ({ a: l.a, b: l.b, w: Math.round(l.w * 1000) / 1000, n: l.n })),
    groups,
  };
}

function main() {
  const food = JSON.parse(readFileSync(join(root, 'data/food.json'), 'utf8'));
  const map = buildMap(food);
  if (map.nodes.length < 50 || map.groups.length < 3) {
    console.error(`Ingredient map came out too small (${map.nodes.length} ingredients, ${map.groups.length} neighborhoods). Keeping the last one.`);
    process.exit(1);
  }
  writeFileSync(join(root, 'data/ingredient_map.json'), JSON.stringify(map) + '\n');
  console.log(`Ingredient map: ${map.nodes.length} ingredients, ${map.links.length} links, ${map.groups.length} neighborhoods`);
  for (const g of map.groups) console.log(`  ${g.name} (${g.members.length}): ${g.cuisines.join(', ')}`);
}

if (process.argv[1] && fileURLToPath(import.meta.url) === process.argv[1]) main();
