// A catalog sync must not take away an ingredient id that links here point at
// (scripts/sync-catalog.mjs), and the copy has to hold together.
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { test } from 'node:test';
import { fileURLToPath } from 'node:url';
import { lostItems } from '../scripts/sync-catalog.mjs';

const root = join(dirname(fileURLToPath(import.meta.url)), '..');
const catalog = (ids, also = {}) => ({ items: Object.fromEntries(ids.map((id) => [id, { name: id, aliases: [], ...(also[id] ? { also: also[id] } : {}) }])) });

test('adding items loses nothing, and a first sync is fine', () => {
  assert.deepEqual(lostItems(catalog(['tofu']), catalog(['tofu', 'basil'])), []);
  assert.deepEqual(lostItems(null, catalog(['tofu'])), []);
});

test('an id may move into another item’s also, but not disappear', () => {
  assert.deepEqual(lostItems(catalog(['scallion', 'tofu']), catalog(['green-onion', 'tofu'], { 'green-onion': ['scallion'] })), []);
  assert.deepEqual(lostItems(catalog(['scallion', 'tofu']), catalog(['green-onion', 'tofu'])), ['scallion']);
});

test('every hand-set link and every saved link points at an item the catalog has', () => {
  const { items } = JSON.parse(readFileSync(join(root, 'scripts/kitchen-catalog/catalog.json'), 'utf8'));
  const known = new Set(Object.keys(items));
  for (const item of Object.values(items)) for (const id of item.also ?? []) known.add(id);
  const overrides = JSON.parse(readFileSync(join(root, 'data/catalog_overrides.json'), 'utf8')).links;
  for (const [name, id] of Object.entries(overrides)) if (id !== null) assert.ok(known.has(id), `override ${name} points at ${id}, which the catalog doesn't have`);
  const links = JSON.parse(readFileSync(join(root, 'data/catalog_links.json'), 'utf8')).links;
  for (const [name, link] of Object.entries(links)) assert.ok(known.has(link.id), `${name} links to ${link.id}, which the catalog doesn't have`);
});
