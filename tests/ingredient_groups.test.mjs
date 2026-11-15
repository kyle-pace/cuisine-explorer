// Tests for scripts/build_ingredient_groups.mjs: placing every World cuisine ingredient under
// the part of the world where it's most at home. Runs against the real data (data/food.json,
// data/cuisines.json) and broken records.
// Run with: node --test tests/*.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { buildGroups, cuisineParts, ALL_OVER, BEYOND, NO_DISH } from '../scripts/build_ingredient_groups.mjs';
import { slug } from '../render_item.js';

const food = JSON.parse(readFileSync(new URL('../data/food.json', import.meta.url), 'utf8'));
const cuisines = JSON.parse(readFileSync(new URL('../data/cuisines.json', import.meta.url), 'utf8')).cuisines;
const all = (g) => [...g.lead, ...g.rest];
const partOf = (out, id) => out.groups.find((g) => all(g).some((x) => x.id === id))?.name;

test('every ingredient page is listed exactly once', () => {
  const out = buildGroups(food, cuisines);
  const ids = out.groups.flatMap(all).map((x) => x.id);
  assert.equal(ids.length, new Set(food.ingredients.map((i) => slug(i.id))).size);
  assert.equal(new Set(ids).size, ids.length);
  const slugs = out.groups.flatMap(all).map((x) => x.slug);
  assert.equal(new Set(slugs).size, slugs.length, 'slugs are used as ids on the page, so they must be unique');
  assert.equal(out.ingredients, ids.length);
  assert.equal(new Set(out.groups.map((g) => g.id)).size, out.groups.length);
});

test('ingredients land where they are most at home', () => {
  const out = buildGroups(food, cuisines);
  assert.equal(partOf(out, 'Lemongrass'), 'Southeast Asia');
  assert.equal(partOf(out, 'Ghee'), 'South Asia');
  assert.equal(partOf(out, 'Suet'), 'The British Isles');
  assert.equal(partOf(out, 'Pasta'), 'Southern Europe');
  assert.equal(partOf(out, 'Garlic'), ALL_OVER);
  assert.equal(out.groups[0].name, ALL_OVER);
  // Each part lists its most-used first, then the rest A to Z
  for (const g of out.groups) {
    const names = g.rest.map((x) => x.name);
    assert.deepEqual(names, [...names].sort((a, b) => a.localeCompare(b, 'en', { sensitivity: 'base' })), `${g.name} A to Z`);
  }
});

test('cuisines get a part of the world, fixing the gaps in Wikipedia’s list', () => {
  const parts = cuisineParts(cuisines);
  assert.equal(parts.get('Indonesian cuisine').part, 'Southeast Asia'); // listed with only "Asian cuisine"
  assert.equal(parts.get('German cuisine').part, 'Central Europe'); // listed with only "European cuisine"
  assert.equal(parts.get('New Zealand cuisine').part, 'Oceania'); // listed under Asian cuisine
  assert.equal(parts.get('Pakistani cuisine').part, 'South Asia');
  assert.equal(parts.get('Jewish cuisine').part, BEYOND);
});

test('the placing is the same every run', () => {
  assert.deepEqual(buildGroups(food, cuisines), buildGroups(food, cuisines));
});

test('broken records are skipped without stopping the rest', () => {
  const cs = [
    null, { name: 'no id' },
    { id: 'Thai cuisine', region: ['Asian cuisine', 'Mainland Southeast Asian cuisine'] },
    { id: 'Odd cuisine', region: ['Not a continent'] },
  ];
  const dishes = [
    null, {}, { ingredients: 'not a list' }, { ingredients: [null, 42, ''] },
    { cuisines: ['Thai cuisine', 'Missing cuisine'], ingredients: ['Lemongrass', 'Lime'] },
    { cuisines: 'Thai cuisine', ingredients: ['Lime'] },
    { cuisines: ['Odd cuisine'], ingredients: ['Salt'] },
  ];
  const ingredients = [null, { name: 'no id' }, { id: 'Lemongrass' }, { id: 'Lime' }, { id: 'Salt' }, { id: 'Unused' }];
  const out = buildGroups({ dishes, ingredients }, cs);
  assert.equal(out.ingredients, 4);
  assert.equal(partOf(out, 'Lemongrass'), 'Southeast Asia');
  assert.equal(partOf(out, 'Salt'), BEYOND);
  assert.equal(partOf(out, 'Unused'), NO_DISH);
  assert.deepEqual(buildGroups(undefined, undefined).groups, []);
});
