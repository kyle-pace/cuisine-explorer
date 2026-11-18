// Refreshes the vendored copy of KitchenCatalog (scripts/kitchen-catalog/) from a clone of
// kyle-pace/kitchen-catalog next to this repo (or the path given). The catalog repo is
// private, so builds in the cloud use this copy instead of fetching it.
//
//   node scripts/sync-catalog.mjs [path-to-kitchen-catalog] [--allow-drop]
//
// It stops, copying nothing, when an ingredient id in the copy here is missing from the clone
// (ids never change in KitchenCatalog; a merged one moves into the survivor's `also`): that
// means the clone is behind or on another branch, and every link to that id would break.
// --allow-drop goes ahead anyway.
import { copyFileSync, writeFileSync, existsSync, readFileSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');

/** Ingredient ids `current` has that `incoming` no longer answers to, by id or by `also`. */
export function lostItems(current, incoming) {
  const known = new Set(Object.keys(incoming?.items ?? {}));
  for (const item of Object.values(incoming?.items ?? {})) for (const id of item.also ?? []) known.add(id);
  return Object.keys(current?.items ?? {}).filter((id) => !known.has(id));
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const args = process.argv.slice(2);
  const src = resolve(args.find((a) => !a.startsWith('--')) || join(root, '..', 'kitchen-catalog'));
  if (!existsSync(join(src, 'js/catalog.mjs'))) {
    console.error(`No KitchenCatalog clone at ${src}. Clone kyle-pace/kitchen-catalog there or pass its path.`);
    process.exit(2);
  }
  const dest = join(root, 'scripts/kitchen-catalog');
  const here = join(dest, 'catalog.json');
  const incoming = JSON.parse(readFileSync(join(src, 'Sources/KitchenCatalog/Resources/catalog.json'), 'utf8'));
  const lost = existsSync(here) ? lostItems(JSON.parse(readFileSync(here, 'utf8')), incoming) : [];
  if (!Object.keys(incoming.items ?? {}).length || (lost.length && !args.includes('--allow-drop'))) {
    console.error(lost.length
      ? `Not syncing: ${lost.length} ingredient id(s) here would disappear (${lost.slice(0, 10).join(', ')}). Is the clone behind (git pull there)? Nothing was copied. If this is meant, run it again with --allow-drop.`
      : 'Not syncing: the incoming catalog has no items. Nothing was copied.');
    process.exit(1);
  }
  copyFileSync(join(src, 'js/catalog.mjs'), join(dest, 'catalog.mjs'));
  copyFileSync(join(src, 'Sources/KitchenCatalog/Resources/catalog.json'), join(dest, 'catalog.json'));
  const sha = execFileSync('git', ['-C', src, 'rev-parse', 'HEAD']).toString().trim();
  writeFileSync(join(dest, 'VERSION'), sha + '\n');
  console.log(`KitchenCatalog ${sha.slice(0, 7)} copied to scripts/kitchen-catalog/. Run node scripts/link_catalog.mjs to relink (and commit both).`);
}
