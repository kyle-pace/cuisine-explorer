// Builds the web of cuisines once, in the weekly rebuild, so the views stay light.
//
// Writes data/web/:
//   skeleton.json     every page's name, type, color and links, plus the graph
//                     layout (by continent and by links), for search, hubs and graphs
//   items/xx.json     page models, packed into 256 buckets by a hash of each page's
//                     address (bucketOf in render_item.js), so a page loads one small file
//
// Page models are rendered by render_item.js, the same code in the browser
// (web.html) and on the server (kylepace.net's /labs/cuisines/<type>/<slug>/).
// Usage: node scripts/build_web.mjs
import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";
import { forceSimulation, forceLink, forceManyBody, forceX, forceY, forceCollide } from "d3-force";
import { bucketOf, slug } from "../render_item.js";

const ROOT = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const read = (f, fallback) => { try { return JSON.parse(fs.readFileSync(path.join(ROOT, "data", f), "utf8")); } catch (e) { if (fallback !== undefined) return fallback; throw e; } };
const data = read("cuisines.json").cuisines;
const food = read("food.json");
const picks = read("picks.json", {}).cuisines || {};
const suggestions = read("suggestions.json", {}).cuisines || {};
const notes = { cuisines: {}, dishes: {}, ingredients: {}, ...read("notes.json", {}) };
const summaries = read("summaries.json", {});
const foodSummaries = read("food_summaries.json", {});
const grown = read("grown.json", { items: {} });
const countries = read("countries.geojson");
const images = read("images.json", { files: {}, items: {} });

const COLORS = { "African cuisine": "#e46a3f", "Cuisine of the Americas": "#94bd5c", "Asian cuisine": "#f0b340", "European cuisine": "#cf5f87", "Oceanic cuisine": "#55b8ad" };
const CONTINENT = { "African cuisine": "Africa", "Cuisine of the Americas": "The Americas", "Asian cuisine": "Asia", "European cuisine": "Europe", "Oceanic cuisine": "Oceania" };
const NEUTRAL = "#a99fb5";
const TYPE_COLOR = { dish: "#ede6da", ingredient: "#c9b8dd", site: "#55b8ad", book: "#f0b340" };
const PATH = { cuisine: "cuisine", dish: "dish", ingredient: "ingredient", site: "site", book: "cookbook" };
const KIND_LABEL = { national: "National cuisine", regional: "Regional cuisine", diaspora: "Diaspora cuisine", peoples: "Cuisine of a people",
  religious: "Religious cuisine or diet", historical: "Historical cuisine", style: "Style of cooking" };
const host = u => { try { return new URL(u).hostname.replace(/^www\./, ""); } catch (e) { return ""; } };
const capital = s => s.charAt(0).toUpperCase() + s.slice(1).replace(/\.$/, "");
const byName = (a, b) => a.name.localeCompare(b.name);
const isoName = new Map();
for (const f of countries.features) {
  const p = f.properties;
  isoName.set(p.ADM0_A3, p.NAME);
  if (p.ISO_A3_EH && p.ISO_A3_EH !== "-99") isoName.set(p.ISO_A3_EH, p.NAME);
}

// --- Nodes and edges (same rules the web view used to compute in the browser) ---
const nodes = new Map();
const add = (type, id, props) => {
  const key = type + ":" + id;
  if (!nodes.has(key)) nodes.set(key, { key, type, id, out: new Map(), ...props });
  return nodes.get(key);
};
function link(a, b, rel, back, extra) {
  if (!a || !b || a === b) return;
  if (!a.out.has(b.key)) a.out.set(b.key, { node: b, rel, ...extra });
  if (!b.out.has(a.key)) b.out.set(a.key, { node: a, rel: back, ...extra });
}
const byId = new Map(data.map(c => [c.id, c]));
const national = new Map(data.filter(c => c.kind === "national").map(c => [c.iso3, c]));
const continentOf = c => (c.region || [])[0] || (c.iso3 && national.get(c.iso3) && (national.get(c.iso3).region || [])[0]) || null;
for (const c of data) add("cuisine", c.id, { name: c.name, c, cont: continentOf(c), color: COLORS[continentOf(c)] || NEUTRAL });
for (const c of data) for (const p of c.parents || []) link(nodes.get("cuisine:" + c.id), nodes.get("cuisine:" + p), "parent", "child");

const ingById = new Map((food.ingredients || []).map(i => [i.id, i]));
const dishes = (food.dishes || []).filter(d => d.cuisines.some(id => byId.has(id)));
for (const d of dishes) {
  const dn = add("dish", d.id, { name: d.name, d, color: TYPE_COLOR.dish });
  for (const cid of d.cuisines) if (byId.has(cid)) link(dn, nodes.get("cuisine:" + cid), "cuisine", "dish");
  for (const iid of d.ingredients || []) {
    const i = ingById.get(iid);
    if (i) link(dn, add("ingredient", i.id, { name: i.name, i, color: TYPE_COLOR.ingredient }), "ingredient", "dish");
  }
}
for (const id of Object.keys(notes.ingredients)) { const i = ingById.get(id); if (i) add("ingredient", i.id, { name: i.name, i, color: TYPE_COLOR.ingredient }); }
const addShelf = (cid, list, suggested) => {
  const cn = nodes.get("cuisine:" + cid);
  if (!cn) return;
  for (const s of list.sites || []) {
    const h = host(s.url);
    if (!h) continue;
    const n = add("site", h, { name: s.name, host: h, color: TYPE_COLOR.site, names: new Map() });
    n.names.set(s.name, (n.names.get(s.name) || 0) + 1);
    link(n, cn, "cuisine", "site", { entry: { ...s, suggested } });
  }
  for (const b of list.cookbooks || []) link(add("book", slug(b.title), { name: b.title, b, color: TYPE_COLOR.book }), cn, "cuisine", "book", { entry: { ...b, suggested } });
};
for (const [cid, l] of Object.entries(picks)) addShelf(cid, l, false);
for (const [cid, l] of Object.entries(suggestions)) addShelf(cid, l, true);
for (const [cid, n] of Object.entries(notes.cuisines)) addShelf(cid, { sites: n.sites, cookbooks: n.cookbooks }, true);
for (const n of nodes.values()) if (n.type === "site") n.name = [...n.names].sort((a, b) => b[1] - a[1] || a[0].length - b[0].length)[0][0];
for (const [bucket, type] of [["cuisines", "cuisine"], ["dishes", "dish"], ["ingredients", "ingredient"]])
  for (const [id, note] of Object.entries(notes[bucket]))
    for (const l of note.links || []) link(nodes.get(type + ":" + id), nodes.get(l.kind + ":" + l.id), "mentions", "mentioned");

for (const n of nodes.values()) n.ref = PATH[n.type] + "/" + slug(n.id);
const edges = (n, rel) => [...n.out.values()].filter(e => !rel || e.rel === rel);
const L = n => [n.name, n.ref];
const list = arr => arr.map(L);

// --- Intro text: our notes first, then Wikipedia's intro --------------------------
function clean(text) {
  return text.replace(/\s*\((?:[^()]*\([^()]*\))*[^()]*\)/, m => /[:;\[]|pronounced|listen|[^\u0000-ɏ‘-”]/i.test(m) ? "" : m)
    .replace(/\s*\[\d+\]/g, "").replace(/\.\./g, ".").replace(/\s+([,.;])/g, "$1").trim();
}
// A note's paragraphs with [[links]] turned into [text, ref] pieces
function noteParas(note) {
  const links = new Map((note.links || []).map(l => [l.text.toLowerCase(), l]));
  return (note.text || []).map(p => {
    const out = [];
    let last = 0;
    for (const m of p.matchAll(/\[\[([^\]|#]+)(?:#[^\]|]*)?(?:\|([^\]]+))?\]\]/g)) {
      if (m.index > last) out.push(p.slice(last, m.index));
      const l = links.get(m[1].trim().toLowerCase());
      const target = l && nodes.get(l.kind + ":" + l.id);
      out.push(target ? [m[2] || m[1], target.ref] : (m[2] || m[1]));
      last = m.index + m[0].length;
    }
    if (last < p.length) out.push(p.slice(last));
    return out;
  });
}
function intro(own, title, fallback) {
  if (own && (own.text || []).length) return { intro: noteParas(own), src: "note", sources: (own.sources || []).filter(x => x.url) };
  const text = title && (summaries[title] || foodSummaries[title]);
  if (text) return { intro: text.split(/\n+/).map(t => clean(t.trim())).filter(Boolean).map(p => [p]), src: "wikipedia" };
  return { intro: fallback ? [[fallback]] : [], src: null, wiki: title || undefined };
}
const wikiUrl = t => "https://en.wikipedia.org/wiki/" + encodeURIComponent(t.replace(/ /g, "_"));
const shelfRow = e => {
  const n = e.node, x = e.entry;
  return { name: n.type === "site" ? n.name : x.title, ref: n.ref, color: n.color, shape: n.type,
    sub: n.type === "site" ? n.host : [x.author, x.year].filter(Boolean).join(", "), note: x.note || "",
    url: x.url || (x.isbn ? "https://openlibrary.org/isbn/" + x.isbn : ""), suggested: !!x.suggested };
};

// --- Page models ------------------------------------------------------------------
const items = {};
const ofType = t => [...nodes.values()].filter(n => n.type === t);
for (const n of nodes.values()) {
  let m;
  if (n.type === "cuisine") {
    const c = n.c, own = notes.cuisines[c.id];
    const country = c.iso3 && isoName.get(c.iso3);
    const parents = edges(n, "parent").map(e => e.node);
    const kids = edges(n, "child").map(e => e.node).sort(byName);
    const ds = edges(n, "dish").map(e => e.node).sort(byName);
    const sites = edges(n, "site").sort((a, b) => a.entry.suggested - b.entry.suggested);
    const books = edges(n, "book").sort((a, b) => a.entry.suggested - b.entry.suggested);
    const count = new Map();
    for (const d of ds) for (const e of edges(d, "ingredient")) count.set(e.node, (count.get(e.node) || 0) + 1);
    const ings = [...count].sort((a, b) => b[1] - a[1]).slice(0, 24).map(([x]) => x);
    const same = c.kind === "national" ? ofType("cuisine").filter(o => o !== n && o.c.iso3 === c.iso3 && !kids.includes(o)).sort(byName) : [];
    const region = (c.region || [])[0];
    m = {
      crumb: [...(region ? [[CONTINENT[region] || region, "cuisines#" + slug(CONTINENT[region] || region)]] : []), ...(parents.length ? list(parents) : [["Cuisine"]])],
      sub: c.indigenous ? `Indigenous foodways${own?.area ? ", " + own.area : ""}`
        : (KIND_LABEL[c.kind] || "Cuisine") + (country ? (c.kind === "national" ? " of " : " in ") + country : ""),
      names: own?.names,
      ...intro(own, c.title, c.desc && capital(c.desc) + "."),
      actions: [...(c.loc || c.iso3 ? [{ kind: "globe", hash: slug(c.id) }] : []), ...(c.url ? [{ kind: "wiki", url: c.url }] : [])],
      sections: [
        sites.length ? { h: "Recipe sites", count: sites.length, rows: sites.map(shelfRow) }
          : { h: "Recipe sites", empty: "None yet", tryLinks: list(parents) },
        books.length && { h: "Cookbooks", count: books.length, rows: books.map(shelfRow) },
        ds.length && { h: "Dishes", count: ds.length, links: list(ds) },
        ings.length && { h: "Key ingredients", links: list(ings), note: "Most used across its dishes." },
        parents.length && { h: "Part of", links: list(parents) },
        kids.length && { h: `Within ${c.name.replace(/ (cuisine|foodways)$/, "")} cooking`, count: kids.length, links: list(kids) },
        same.length && { h: `More from ${country}`, count: same.length, links: list(same) },
      ],
    };
    m.cont = n.cont;
  } else if (n.type === "dish") {
    const d = n.d, own = notes.dishes[d.id];
    const homes = edges(n, "cuisine").map(e => e.node);
    const ings = edges(n, "ingredient").map(e => e.node).sort(byName);
    const siblings = homes[0] ? edges(homes[0], "dish").map(e => e.node).filter(x => x !== n).sort(byName).slice(0, 40) : [];
    const cook = homes.flatMap(h => edges(h, "site")).slice(0, 4);
    const title = d.note && !d.title ? null : (d.title || d.id);
    m = {
      crumb: [["Dishes", "dishes"]],
      sub: homes.length === 1 ? `Dish from ${homes[0].name}` : `Dish found in ${homes.length} cuisines`,
      dot: homes[0]?.color,
      ...intro(own, title),
      actions: [{ kind: "globe", hash: "dish-" + slug(d.id) }, ...(title ? [{ kind: "wiki", url: wikiUrl(title) }] : [])],
      sections: [
        { h: "Where it's from", links: list(homes) },
        ings.length && { h: "Ingredients", count: ings.length, links: list(ings) },
        cook.length && { h: "Cook it", rows: cook.map(shelfRow) },
        siblings.length && { h: `More from ${homes[0].name}`, links: list(siblings) },
      ],
    };
  } else if (n.type === "ingredient") {
    const i = n.i, own = notes.ingredients[i.id];
    const ds = edges(n, "dish").map(e => e.node);
    const byC = new Map();
    for (const d of ds) for (const e of edges(d, "cuisine")) { if (!byC.has(e.node)) byC.set(e.node, []); byC.get(e.node).push(d); }
    const rows = [...byC].sort((a, b) => b[1].length - a[1].length || byName(a[0], b[0]));
    const pairs = new Map();
    for (const d of ds) for (const e of edges(d, "ingredient")) if (e.node !== n) pairs.set(e.node, (pairs.get(e.node) || 0) + 1);
    const paired = [...pairs].sort((a, b) => b[1] - a[1]).slice(0, 16).map(([x]) => x);
    const g = grown.items[i.id];
    m = {
      crumb: [["Ingredients", "ingredients"]],
      sub: `Ingredient in ${ds.length} ${ds.length === 1 ? "dish" : "dishes"} across ${rows.length} ${rows.length === 1 ? "cuisine" : "cuisines"}`,
      ...intro(own, i.title),
      actions: [...(ds.length ? [{ kind: "globe", hash: "ingredient-" + slug(i.id) }] : []), ...(i.title ? [{ kind: "wiki", url: wikiUrl(i.title) }] : [])],
      sections: [
        rows.length && { h: "Where it's cooked with", count: rows.length, groups: rows.map(([c, l]) => [c.name, c.ref, list(l.sort(byName))]) },
        g && { h: "Where it's grown", grown: { what: g.fao.replace(/;/g, ","), years: grown.meta.years, url: grown.meta.url, world: g.world,
          top: g.top.slice(0, 15).map(([iso, t]) => { const nat = national.get(iso); return [isoName.get(iso) || iso, nat ? nodes.get("cuisine:" + nat.id).ref : null, t]; }) } },
        paired.length && { h: "Often cooked with", links: list(paired) },
      ],
    };
  } else if (n.type === "site") {
    const covers = edges(n, "cuisine").sort((a, b) => byName(a.node, b.node));
    const note = covers.map(e => e.entry.note).find(Boolean);
    m = {
      crumb: [["Recipe sites", "sites"]],
      sub: `Recipe site, ${n.host}`, square: true, suggested: covers.every(e => e.entry.suggested),
      intro: note ? [[note]] : [],
      actions: [{ kind: "out", url: "https://" + n.host, label: "Visit " + n.host }],
      sections: [{ h: "Cuisines it covers", count: covers.length,
        rows: covers.map(e => ({ name: e.node.name, ref: e.node.ref, color: e.node.color, shape: "cuisine", sub: e.entry.name, url: e.entry.url })) }],
    };
  } else if (n.type === "book") {
    const covers = edges(n, "cuisine").sort((a, b) => byName(a.node, b.node));
    const b = { ...n.b, ...covers.map(e => e.entry).find(x => x.isbn || x.url) };
    const href = b.url || (b.isbn ? "https://openlibrary.org/isbn/" + b.isbn : null);
    m = {
      crumb: [["Cookbooks", "cookbooks"]],
      sub: "Cookbook" + (b.author ? " by " + b.author : "") + (b.year ? ", " + b.year : ""), square: true,
      suggested: covers.every(e => e.entry.suggested), isbn: b.isbn,
      intro: b.note ? [[b.note]] : [],
      actions: href ? [{ kind: "out", url: href, label: b.url ? "Publisher or book page" : "Open Library" }] : [],
      sections: [{ h: "Cuisines it covers", count: covers.length, links: list(covers.map(e => e.node)) }],
    };
  }
  const mentioned = edges(n, "mentioned").map(e => e.node).sort(byName);
  if (mentioned.length) m.sections.push({ h: "Mentioned in", links: list(mentioned) });
  m.sections = m.sections.filter(Boolean);
  items[n.ref] = { t: n.type, r: n.ref, n: n.type === "book" ? (n.b?.title || n.name) : n.name, c: n.color, ...m };
}

// --- Photos (scripts/fetch_images.py): free licenses only, each with its credit ---------
const usedImages = new Set();
const photo = (key, of) => {
  const name = images.items[key], f = name && images.files[name];
  if (!f) return null;
  usedImages.add(f.p);
  return { src: "/labs/cuisines/img/" + f.p, w: f.w, h: f.h, by: f.by, lic: f.lic, licUrl: f.licUrl,
    page: "https://commons.wikimedia.org/wiki/File:" + encodeURIComponent(name.replace(/ /g, "_")), ...(of ? { of } : {}) };
};
for (const n of nodes.values()) {
  const own = n.type === "cuisine" || n.type === "dish" || n.type === "ingredient" ? photo(n.type + ":" + n.id) : null;
  let img = own;
  // A cuisine without its own photo shows one of its dishes, and says which
  if (!img && n.type === "cuisine") {
    const d = edges(n, "dish").map(e => e.node).sort(byName).find(d => images.items["dish:" + d.id] && images.files[images.items["dish:" + d.id]]);
    if (d) img = photo("dish:" + d.id, d.name);
  }
  if (img) items[n.ref].img = img;
}

// --- Layout (by links like Obsidian, and with cuisines pulled toward their continent) ---
const ANCHOR = { "Cuisine of the Americas": [-900, 40], "European cuisine": [-80, -560], "African cuisine": [-60, 600], "Asian cuisine": [780, -40], "Oceanic cuisine": [980, 720] };
const pairs = new Map();
for (const a of nodes.values()) for (const [k, e] of a.out) if (a.key < k) pairs.set(a.key + "|" + k, { source: a.key, target: k });
function layout(byContinent) {
  const arr = [...nodes.values()].map(n => ({ key: n.key, type: n.type, cont: n.cont, weight: n.c?.kind === "national" ? 2 : 1 }));
  arr.forEach((n, i) => { const r = 10 * Math.sqrt(i), a = i * 2.39996; n.x = r * Math.cos(a); n.y = r * Math.sin(a); });
  const anchor = n => byContinent && n.type === "cuisine" && n.cont && ANCHOR[n.cont];
  const kind = k => k.slice(0, k.indexOf(":"));
  const ls = [...pairs.values()].map(l => ({ ...l, kinds: [kind(l.source), kind(l.target)].sort().join("-") }));
  const LINK = { "cuisine-cuisine": [28, 0.5], "cuisine-dish": [10, 0.9], "cuisine-site": [10, 0.9], "book-cuisine": [10, 0.9], "dish-ingredient": [34, 0.06] };
  const sim = forceSimulation(arr).stop()
    .force("link", forceLink(ls).id(n => n.key).distance(l => (LINK[l.kinds] || [24, 0.2])[0]).strength(l => (LINK[l.kinds] || [24, 0.2])[1]))
    .force("charge", forceManyBody().strength(-16).distanceMax(300).theta(0.9))
    .force("collide", forceCollide(n => n.type === "cuisine" ? 4 * n.weight : 2.4))
    .force("x", forceX(n => anchor(n) ? anchor(n)[0] : 0).strength(n => anchor(n) ? 0.08 : 0.012))
    .force("y", forceY(n => anchor(n) ? anchor(n)[1] : 0).strength(n => anchor(n) ? 0.08 : 0.012));
  for (let i = 0; i < 500; i++) sim.tick();
  return new Map(arr.map(n => [n.key, [Math.round(n.x), Math.round(n.y)]]));
}
const t0 = Date.now();
const byLinks = layout(false), byCont = layout(true);

// --- Skeleton -------------------------------------------------------------------
const list_ = [...nodes.values()];
const index = new Map(list_.map((n, i) => [n.key, i]));
const TYPES = ["cuisine", "dish", "ingredient", "site", "book"];
const palette = [...new Set(list_.map(n => n.color))];
const BEYOND = new Set(["religious", "historical", "style"]);
const skeleton = {
  types: TYPES, colors: palette, continents: CONTINENT,
  // [ref, name, type, color, flags, sub, x, y, X, Y]; flags: 1 national, 2 indigenous, 4 beyond borders
  nodes: list_.map(n => {
    const flags = n.type === "cuisine" ? (n.c.kind === "national" ? 1 : 0) | (n.c.indigenous ? 2 : 0) | (!n.c.iso3 || BEYOND.has(n.c.kind) ? 4 : 0) : 0;
    const sub = n.type === "cuisine" ? (n.c.iso3 ? isoName.get(n.c.iso3) || "" : "") : n.type === "site" ? n.host : "";
    return [n.ref, items[n.ref].n, TYPES.indexOf(n.type), palette.indexOf(n.color), flags, sub, ...byLinks.get(n.key), ...byCont.get(n.key)];
  }),
  links: [...pairs.values()].map(l => [index.get(l.source), index.get(l.target)]),
};

// --- Write ---------------------------------------------------------------------
const out = path.join(ROOT, "data", "web");
fs.rmSync(out, { recursive: true, force: true });
fs.mkdirSync(path.join(out, "items"), { recursive: true });
fs.writeFileSync(path.join(out, "skeleton.json"), JSON.stringify(skeleton));
// The photos kylepace.net may fetch and keep (its image route refuses anything else)
fs.writeFileSync(path.join(out, "images.json"), JSON.stringify([...usedImages].sort()));
const buckets = {};
for (const [ref, item] of Object.entries(items)) (buckets[bucketOf(ref)] ||= {})[ref] = item;
for (const [b, obj] of Object.entries(buckets)) fs.writeFileSync(path.join(out, "items", b + ".json"), JSON.stringify(obj));
const size = f => fs.statSync(f).size;
const bucketSizes = Object.keys(buckets).map(b => size(path.join(out, "items", b + ".json")));
console.log(`web: ${list_.length} pages, ${skeleton.links.length} links, laid out in ${((Date.now() - t0) / 1000).toFixed(1)} s; ` +
  `skeleton ${Math.round(size(path.join(out, "skeleton.json")) / 1024)} KB, ${bucketSizes.length} buckets of about ${Math.round(bucketSizes.reduce((a, b) => a + b, 0) / bucketSizes.length / 1024)} KB (largest ${Math.round(Math.max(...bucketSizes) / 1024)} KB)`);
