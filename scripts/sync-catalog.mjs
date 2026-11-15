// Refreshes the vendored copy of KitchenCatalog (scripts/kitchen-catalog/) from a clone of
// kyle-pace/kitchen-catalog next to this repo (or the path given). The catalog repo is
// private, so builds in the cloud use this copy instead of fetching it.
//
//   node scripts/sync-catalog.mjs [path-to-kitchen-catalog]
import { copyFileSync, writeFileSync, existsSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const src = resolve(process.argv[2] || join(root, '..', 'kitchen-catalog'));
if (!existsSync(join(src, 'js/catalog.mjs'))) {
  console.error(`No KitchenCatalog clone at ${src}. Clone kyle-pace/kitchen-catalog there or pass its path.`);
  process.exit(2);
}
const dest = join(root, 'scripts/kitchen-catalog');
copyFileSync(join(src, 'js/catalog.mjs'), join(dest, 'catalog.mjs'));
copyFileSync(join(src, 'Sources/KitchenCatalog/Resources/catalog.json'), join(dest, 'catalog.json'));
const sha = execFileSync('git', ['-C', src, 'rev-parse', 'HEAD']).toString().trim();
writeFileSync(join(dest, 'VERSION'), sha + '\n');
console.log(`KitchenCatalog ${sha.slice(0, 7)} copied to scripts/kitchen-catalog/. Run node scripts/link_catalog.mjs to relink (and commit both).`);
