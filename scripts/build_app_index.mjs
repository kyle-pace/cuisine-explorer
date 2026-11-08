// A small index for the iOS app (ios/), next to the web view's skeleton:
//   data/web/app.json  { places: [[ref, lat, lng]], cont: {ref: continent}, photos: {ref: photo path} }
//   (photos include a cuisine's fallback dish photo; the page model's img.of says when)
// The app loads skeleton.json and app.json at launch and page buckets as you open pages.
import fs from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";
import { slug } from "../render_item.js";

const ROOT = path.resolve(path.dirname(fileURLToPath(import.meta.url)), "..");
const { cuisines } = JSON.parse(fs.readFileSync(path.join(ROOT, "data/cuisines.json"), "utf8"));
const places = cuisines.filter(c => c.loc).map(c => ["cuisine/" + slug(c.id), +c.loc[0].toFixed(3), +c.loc[1].toFixed(3)]);

const cont = {}, photos = {};
const dir = path.join(ROOT, "data/web/items");
for (const f of fs.readdirSync(dir).sort()) {
  for (const [ref, m] of Object.entries(JSON.parse(fs.readFileSync(path.join(dir, f), "utf8")))) {
    if (m.cont) cont[ref] = m.cont;
    // Cuisines without a photo of their own show one of their dishes (m.img.of says which)
    if (m.img) photos[ref] = m.img.src.replace(/^\/labs\/cuisines\/img\//, "");
  }
}
fs.writeFileSync(path.join(ROOT, "data/web/app.json"), JSON.stringify({ places, cont, photos }));
console.log(`app index: ${places.length} places, ${Object.keys(photos).length} photos`);
