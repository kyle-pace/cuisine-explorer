// Tests for scripts/link_catalog.mjs: World cuisine ingredients linked to KitchenCatalog ids.
// Runs against a saved real sample of data/food.json's ingredients and of Recipe search's
// index, plus broken records. Run with: node --test tests/
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { load } from '../scripts/kitchen-catalog/catalog.mjs';
import { linkIngredients, recipeCounts, recipesUrl } from '../scripts/link_catalog.mjs';

const here = new URL('.', import.meta.url);
const catalog = load(new URL('../scripts/kitchen-catalog/catalog.json', here).pathname);
const sample = JSON.parse(readFileSync(new URL('samples/food-ingredients.json', here), 'utf8'));
const overrides = JSON.parse(readFileSync(new URL('../data/catalog_overrides.json', here), 'utf8')).links;

test('real ingredients link to the catalog item a shopper would buy', () => {
  const { links } = linkIngredients(catalog, sample, overrides);
  assert.equal(links['Sugar']?.id, 'sugar');
  assert.equal(links['Egg']?.id, 'eggs');
  assert.equal(links['Scallion']?.id, 'green-onion');
  assert.equal(links['Shrimp paste']?.id, 'shrimp-paste');
  assert.equal(links['Salt cod']?.id, 'salt-cod');
});

test('Wikipedia-only names are linked by hand', () => {
  const { links } = linkIngredients(catalog, sample, overrides);
  assert.equal(links['Maize']?.id, 'corn');
  assert.equal(links['Agaricus bisporus']?.id, 'mushrooms');
  assert.equal(links['Maida (flour)']?.id, 'all-purpose-flour');
  assert.equal(links['Puff pastry']?.id, 'puff-pastry');
});

test('wrong guesses, ready-made products and non-groceries are left unlinked', () => {
  const { links } = linkIngredients(catalog, sample, overrides);
  assert.equal(links['Rose water'], undefined, 'not bottled water');
  assert.equal(links['Coconut water'], undefined);
  assert.equal(links['Sponge cake'], undefined, 'a ready-made product');
  assert.equal(links['Offal'], undefined);
});

test('broken records are skipped without stopping the rest', () => {
  const broken = [null, {}, { id: '' }, { id: 42, name: 'Sugar' }, { id: 'Ghost', name: null }, { id: 'Egg', name: 'Egg' }];
  const { links, skipped } = linkIngredients(catalog, broken, { Ghost: 'not-a-real-id' });
  assert.deepEqual(Object.keys(links), ['Egg']);
  assert.ok(skipped.length >= 4);
});

test('an override pointing at a missing catalog id is reported, not linked', () => {
  const { links, skipped } = linkIngredients(catalog, [{ id: 'Egg', name: 'Egg' }], { Egg: 'no-such-item' });
  assert.equal(links['Egg'], undefined);
  assert.equal(skipped[0].reason, 'no catalog item no-such-item');
});

test('recipe counts come from the real index and ignore junk rows', () => {
  const index = JSON.parse(readFileSync(new URL('samples/recipe-index-ing.json', here), 'utf8'));
  const counts = recipeCounts(index);
  assert.ok(counts.corn > 0 && counts.mushrooms > 0);
  assert.deepEqual(recipeCounts({ ing: [null, ['x'], [5, 'n', 3], ['ok', 'Ok', 'many']] }), {});
  assert.deepEqual(recipeCounts(null), {});
  assert.deepEqual(recipeCounts('<html>error</html>'), {});
});

test('recipe links point at Recipe search with the catalog id', () => {
  assert.equal(recipesUrl('palm-sugar'), 'https://kylepace.dev/recipe-search/?with=palm-sugar');
});
