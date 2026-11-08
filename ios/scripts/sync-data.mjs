// Copies the explorer's data into the app bundle, so the app is self-contained:
//   Data/web/skeleton.json   every page's name, type, color and links
//   Data/web/items/xx.json   page models in 256 buckets (see render_item.js bucketOf)
//   Data/places.json         [ref, lat, lng] for cuisines with a place, for the map
//   Data/extras.json         { cont: {ref: continent}, photos: {ref: thumbnail path} }
// Run from anywhere: node ios/scripts/sync-data.mjs
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { slug } from "../../render_item.js";

const IOS = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const ROOT = path.resolve(IOS, "..");
const OUT = path.join(IOS, "CuisineExplorer", "Data");

fs.rmSync(OUT, { recursive: true, force: true });
fs.mkdirSync(path.join(OUT, "web"), { recursive: true });
fs.cpSync(path.join(ROOT, "data/web/skeleton.json"), path.join(OUT, "web/skeleton.json"));
fs.cpSync(path.join(ROOT, "data/web/items"), path.join(OUT, "web/items"), { recursive: true });

const { cuisines } = JSON.parse(fs.readFileSync(path.join(ROOT, "data/cuisines.json"), "utf8"));
const places = cuisines.filter(c => c.loc).map(c => ["cuisine/" + slug(c.id), +c.loc[0].toFixed(3), +c.loc[1].toFixed(3)]);
fs.writeFileSync(path.join(OUT, "places.json"), JSON.stringify(places));

const cont = {}, photos = {};
for (const f of fs.readdirSync(path.join(ROOT, "data/web/items"))) {
  const bucket = JSON.parse(fs.readFileSync(path.join(ROOT, "data/web/items", f), "utf8"));
  for (const [ref, m] of Object.entries(bucket)) {
    if (m.cont) cont[ref] = m.cont;
    if (m.img && !m.img.of) photos[ref] = m.img.src.replace(/^\/labs\/cuisines\/img\//, "");
  }
}
fs.writeFileSync(path.join(OUT, "extras.json"), JSON.stringify({ cont, photos }));
console.log(`app data: ${places.length} places, ${Object.keys(photos).length} photos`);
