#!/usr/bin/env node
// Builds data/drop.json, the dish pool for Dish drop (drop.html).
//
// A dish is playable when it has a photo and comes from exactly one place we can put on
// the globe: one national or regional cuisine with a location. Dishes shared by several
// cuisines (adobo, akuri) are left out, since there's no single right answer to score
// against. Runs after build_web.mjs in scripts/update.sh, so the photos it lists are
// already on the photo route's allow-list.
//
// No dependencies; Node 18+.
import fs from "node:fs";

const read = f => JSON.parse(fs.readFileSync(new URL(`../data/${f}`, import.meta.url), "utf8"));
const food = read("food.json"), { cuisines } = read("cuisines.json");
const images = read("images.json"), summaries = read("food_summaries.json");
const countries = read("countries.geojson");

const slug = s => String(s).toLowerCase().normalize("NFD").replace(/[̀-ͯ]/g, "")
  .replace(/[^a-z0-9]+/g, "-").replace(/^-|-$/g, "");
const byId = new Map(cuisines.map(c => [c.id, c]));

// Country names and a point for each, for the "type a country" input. The national
// cuisine's own location when there is one, otherwise the middle of the country's shape.
const national = new Map(cuisines.filter(c => c.kind === "national" && c.iso3).map(c => [c.iso3, c]));
const isoOf = p => [p.ISO_A3_EH, p.ADM0_A3].find(code => national.has(code)) ?? (p.ISO_A3_EH !== "-99" ? p.ISO_A3_EH : p.ADM0_A3);
function middle(geom) {
  let best = null;
  const polys = geom.type === "Polygon" ? [geom.coordinates] : geom.coordinates;
  for (const poly of polys) if (!best || poly[0].length > best.length) best = poly[0];   // biggest piece
  const sum = best.reduce((a, [x, y]) => [a[0] + y, a[1] + x], [0, 0]);
  return [+(sum[0] / best.length).toFixed(2), +(sum[1] / best.length).toFixed(2)];
}
const places = {};
for (const f of countries.features) {
  const iso = isoOf(f.properties);
  if (iso === "ATA" || places[iso]) continue;
  places[iso] = { n: f.properties.NAME, loc: national.get(iso)?.loc ?? middle(f.geometry) };
}

// The first sentence or so of the dish's intro, for the reveal
const firstSentence = s => {
  if (!s) return "";
  // Drop pronunciation and other-language asides: "(Hungarian: [ˈlɛt͡ʃoː]; ...)"
  s = s.replace(/\s*\([^()]*[:\[][^()]*\)/g, "").replace(/\s+([,.;])/g, "$1");
  const m = s.match(/^.{40,240}?[.!?](?=\s+[A-Z]|$)/);
  return (m ? m[0] : s.slice(0, 220).replace(/\s+\S*$/, "") + "…").trim();
};

const dishes = [];
for (const d of food.dishes) {
  const homes = d.cuisines.map(id => byId.get(id)).filter(c => c && c.loc);
  if (homes.length !== 1) continue;
  const c = homes[0];
  if (c.kind !== "national" && c.kind !== "regional") continue;
  const file = images.items["dish:" + d.id], f = file && images.files[file];
  if (!f || !c.iso3 || !places[c.iso3]) continue;
  dishes.push({
    n: d.name, ref: "dish/" + slug(d.id),
    img: { p: f.p, w: f.w, h: f.h, by: f.by, lic: f.lic, page: "https://commons.wikimedia.org/wiki/File:" + encodeURIComponent(file.replace(/ /g, "_")) },
    c: c.name, cref: "cuisine/" + slug(c.id), kind: c.kind, iso: c.iso3, loc: c.loc,
    sum: firstSentence(summaries[d.id]),
  });
}

fs.writeFileSync(new URL("../data/drop.json", import.meta.url), JSON.stringify({ places, dishes }));
console.log(`Dish drop: ${dishes.length} playable dishes from ${new Set(dishes.map(d => d.iso)).size} countries.`);
