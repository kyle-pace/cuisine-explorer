// A small index for the iOS app (ios/), next to the web view's skeleton:
//   data/web/app.json  { places: [[ref, lat, lng]], cont: {ref: continent}, photos: {ref: photo path},
//                        national: {iso3: ref}, regions: [[ref]] (one entry per regions.geojson feature),
//                        routes: [[ref, fromIso3, toIso3]] (diaspora cuisines) }
//   (photos include a cuisine's fallback dish photo; the page model's img.of says when)
// The app loads skeleton.json and app.json at launch and page buckets as you open pages.
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { slug } from "../render_item.js";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const { cuisines } = JSON.parse(fs.readFileSync(path.join(ROOT, "data/cuisines.json"), "utf8"));
const places = cuisines.filter(c => c.loc).map(c => ["cuisine/" + slug(c.id), +c.loc[0].toFixed(3), +c.loc[1].toFixed(3)]);
// Which national cuisine a country shape (data/countries.geojson, ISO 3166 alpha-3) opens
const national = Object.fromEntries(cuisines.filter(c => c.kind === "national" && c.iso3).map(c => [c.iso3, "cuisine/" + slug(c.id)]));
// Diaspora routes: [cuisine ref, from iso3, to iso3], drawn as arcs on the map
const routes = cuisines.filter(c => c.arc).map(c => ["cuisine/" + slug(c.id), c.arc.from, c.arc.to]);
// Which cuisines each regional shape (data/regions.geojson) stands for, by its feature index
const regions = JSON.parse(fs.readFileSync(path.join(ROOT, "data/regions.geojson"), "utf8")).features
  .map(f => f.properties.ids.map(id => "cuisine/" + slug(id)));

const cont = {}, photos = {};
const dir = path.join(ROOT, "data/web/items");
for (const f of fs.readdirSync(dir).sort()) {
  for (const [ref, m] of Object.entries(JSON.parse(fs.readFileSync(path.join(dir, f), "utf8")))) {
    if (m.cont) cont[ref] = m.cont;
    // Cuisines without a photo of their own show one of their dishes (m.img.of says which)
    // Stored without the image route's prefix; the pages add it back (photoUrl). The old
    // /labs/cuisines/ prefix is still stripped in case an older page model is read.
    if (m.img) photos[ref] = m.img.src.replace(/^\/(world-cuisine|labs\/cuisines)\/img\//, "");
  }
}
fs.writeFileSync(path.join(ROOT, "data/web/app.json"), JSON.stringify({ places, cont, photos, national, regions, routes }));
console.log(`app index: ${places.length} places, ${Object.keys(photos).length} photos, ${Object.keys(national).length} countries, ${regions.length} region shapes`);
