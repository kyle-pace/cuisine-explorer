// Lay out the whole web once, so the graph opens instantly and holds still.
// Builds the same nodes and links as web.html (cuisines, dishes, ingredients,
// recipe sites by host, cookbooks by title, links written in notes), runs a
// force layout twice: by links alone (like Obsidian), and with each cuisine
// pulled gently toward its continent. Writes data/graph.json:
//   { meta, nodes: { key: [x, y, X, Y] } }   x, y by links; X, Y by continent
// Usage: node scripts/build_graph.mjs
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";
import { forceSimulation, forceLink, forceManyBody, forceX, forceY, forceCollide } from "d3-force";

const ROOT = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const read = f => JSON.parse(fs.readFileSync(path.join(ROOT, "data", f), "utf8"));
const data = read("cuisines.json").cuisines;
const food = read("food.json");
const picks = read("picks.json").cuisines || {};
const suggestions = read("suggestions.json").cuisines || {};
const notes = { cuisines: {}, dishes: {}, ingredients: {}, ...read("notes.json") };
const slug = s => String(s).toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "").replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");
const host = u => { try { return new URL(u).hostname.replace(/^www\./, ""); } catch (e) { return ""; } };

const nodes = new Map();
const links = new Map();
const add = (key, props = {}) => { if (!nodes.has(key)) nodes.set(key, { key, ...props }); return key; };
const link = (a, b) => { if (!a || !b || a === b || !nodes.has(a) || !nodes.has(b)) return; const k = a < b ? a + "|" + b : b + "|" + a; links.set(k, { source: a, target: b }); };

const byId = new Map(data.map(c => [c.id, c]));
const national = new Map(data.filter(c => c.kind === "national").map(c => [c.iso3, c]));
const continent = c => (c.region || [])[0] || (c.iso3 && national.get(c.iso3) && (national.get(c.iso3).region || [])[0]) || null;
for (const c of data) add("cuisine:" + c.id, { cont: continent(c), weight: c.kind === "national" ? 2 : 1 });
for (const c of data) for (const p of c.parents || []) link("cuisine:" + c.id, "cuisine:" + p);

const ing = new Map((food.ingredients || []).map(i => [i.id, i]));
for (const d of food.dishes || []) {
  if (!d.cuisines.some(id => byId.has(id))) continue;
  const dk = add("dish:" + d.id);
  for (const cid of d.cuisines) link(dk, "cuisine:" + cid);
  for (const iid of d.ingredients || []) if (ing.has(iid)) { add("ingredient:" + iid); link(dk, "ingredient:" + iid); }
}
for (const id of Object.keys(notes.ingredients)) if (ing.has(id)) add("ingredient:" + id);
const shelf = (cid, l) => {
  if (!byId.has(cid)) return;
  for (const s of l.sites || []) { const h = host(s.url); if (h) link(add("site:" + h), "cuisine:" + cid); }
  for (const b of l.cookbooks || []) link(add("book:" + slug(b.title)), "cuisine:" + cid);
};
for (const [cid, l] of Object.entries(picks)) shelf(cid, l);
for (const [cid, l] of Object.entries(suggestions)) shelf(cid, l);
for (const [cid, n] of Object.entries(notes.cuisines)) shelf(cid, { sites: n.sites, cookbooks: n.cookbooks });
for (const [bucket, type] of [["cuisines", "cuisine"], ["dishes", "dish"], ["ingredients", "ingredient"]])
  for (const [id, n] of Object.entries(notes[bucket])) for (const l of n.links || []) link(type + ":" + id, l.kind + ":" + l.id);

// Leaves (dishes, sites, books) take their first cuisine's continent, so the
// continent layout keeps them near home too
const cuisineOf = new Map();
for (const { source, target } of links.values()) {
  const [a, b] = [source, target];
  if (b.startsWith("cuisine:") && !a.startsWith("cuisine:") && !cuisineOf.has(a)) cuisineOf.set(a, b);
  if (a.startsWith("cuisine:") && !b.startsWith("cuisine:") && !cuisineOf.has(b)) cuisineOf.set(b, a);
}

// Rough world map for the continent layout
const ANCHOR = { "Cuisine of the Americas": [-900, 40], "European cuisine": [-80, -560], "African cuisine": [-60, 600], "Asian cuisine": [780, -40], "Oceanic cuisine": [980, 720] };

function layout(byContinent) {
  const list = [...nodes.values()].map(n => ({ key: n.key, cont: n.cont || (cuisineOf.has(n.key) ? nodes.get(cuisineOf.get(n.key)).cont : null), weight: n.weight || 1 }));
  // Same starting spiral both times, so runs are repeatable
  list.forEach((n, i) => { const r = 10 * Math.sqrt(i), a = i * 2.39996; n.x = r * Math.cos(a); n.y = r * Math.sin(a); });
  const anchor = n => byContinent && n.cont && ANCHOR[n.cont] && n.key.startsWith("cuisine:") && ANCHOR[n.cont];
  // Dishes, sites and books hold tight to their cuisine; ingredients float
  // loosely between the dishes that use them
  const kind = k => k.slice(0, k.indexOf(":"));
  const ls = [...links.values()].map(l => ({ ...l, kinds: [kind(l.source), kind(l.target)].sort().join("-") }));
  const LINK = { "cuisine-cuisine": [28, 0.5], "cuisine-dish": [10, 0.9], "cuisine-site": [10, 0.9], "book-cuisine": [10, 0.9], "dish-ingredient": [34, 0.06] };
  const sim = forceSimulation(list).stop()
    .force("link", forceLink(ls).id(n => n.key).distance(l => (LINK[l.kinds] || [24, 0.2])[0]).strength(l => (LINK[l.kinds] || [24, 0.2])[1]))
    .force("charge", forceManyBody().strength(-16).distanceMax(300).theta(0.9))
    .force("collide", forceCollide(n => n.key.startsWith("cuisine:") ? 4 * n.weight : 2.4))
    .force("x", forceX(n => anchor(n) ? anchor(n)[0] : 0).strength(n => anchor(n) ? 0.08 : 0.012))
    .force("y", forceY(n => anchor(n) ? anchor(n)[1] : 0).strength(n => anchor(n) ? 0.08 : 0.012));
  for (let i = 0; i < 500; i++) sim.tick();
  return new Map(list.map(n => [n.key, [Math.round(n.x), Math.round(n.y)]]));
}

const t = Date.now();
const a = layout(false), b = layout(true);
const out = {};
for (const k of nodes.keys()) out[k] = [...a.get(k), ...b.get(k)];
fs.writeFileSync(path.join(ROOT, "data", "graph.json"), JSON.stringify({ meta: { nodes: nodes.size, links: links.size, layouts: ["links", "continent"] }, nodes: out }));
console.log(`graph: ${nodes.size} nodes, ${links.size} links, laid out in ${((Date.now() - t) / 1000).toFixed(1)} s`);
