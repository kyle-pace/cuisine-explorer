// Tests for scripts/build_ingredient_groups.mjs: putting every World cuisine ingredient on a
// shelf of what it's cooked with. Runs against the real dish data (data/food.json) and broken records.
// Run with: node --test tests/*.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { linksFrom, louvain, tidyGroups, buildGroups } from '../scripts/build_ingredient_groups.mjs';
import { slug } from '../render_item.js';

const food = JSON.parse(readFileSync(new URL('../data/food.json', import.meta.url), 'utf8'));
const all = (g) => [...g.lead, ...g.rest];

test('every ingredient page is listed exactly once', () => {
  const out = buildGroups(food);
  const ids = out.groups.flatMap(all).map((x) => x.id);
  assert.equal(ids.length, new Set(food.ingredients.map((i) => slug(i.id))).size);
  assert.equal(new Set(ids).size, ids.length);
  const slugs = out.groups.flatMap(all).map((x) => x.slug);
  assert.equal(new Set(slugs).size, slugs.length, 'slugs are used as ids on the page, so they must be unique');
  for (const s of slugs) assert.match(s, /^[a-z0-9-]+$/);
  assert.equal(out.ingredients, ids.length);
});

test('real dishes give real shelves', () => {
  const out = buildGroups(food);
  const named = out.groups.filter((g) => g.id !== 'on-their-own');
  assert.ok(named.length >= 5 && named.length <= 30, `${named.length} shelves`);
  const shelfOf = (id) => out.groups.find((g) => all(g).some((x) => x.id === id))?.id;
  // Things cooked together end up together...
  assert.equal(shelfOf('Lemongrass'), shelfOf('Galangal'));
  assert.equal(shelfOf('Wheat flour'), shelfOf('Butter'));
  // ...and things that aren't, don't
  assert.notEqual(shelfOf('Lemongrass'), shelfOf('Butter'));
  for (const g of named) assert.ok(g.size >= 4 && g.name && g.cuisines.length && g.lead.length, `shelf ${g.id}`);
  // The rest of each shelf is A to Z, and the most-used come first
  for (const g of out.groups) {
    const names = g.rest.map((x) => x.name);
    assert.deepEqual(names, [...names].sort((a, b) => a.localeCompare(b, 'en', { sensitivity: 'base' })), `${g.name} A to Z`);
    for (let i = 1; i < g.lead.length; i++) assert.ok(g.lead[i - 1].dishes >= g.lead[i].dishes);
  }
});

test('the shelves are the same every run', () => {
  assert.deepEqual(buildGroups(food), buildGroups(food));
});

test('an ingredient in no shared dish goes on the last shelf, not nowhere', () => {
  const dishes = [
    ...Array.from({ length: 5 }, () => ({ ingredients: ['a1', 'a2', 'a3', 'a4'] })),
    { ingredients: ['a1', 'rare'] },
    { ingredients: ['loner'] },
  ];
  const ingredients = ['a1', 'a2', 'a3', 'a4', 'rare', 'loner', 'unused'].map((id) => ({ id, name: id }));
  const out = buildGroups({ dishes, ingredients });
  const shelfOf = (id) => out.groups.find((g) => all(g).some((x) => x.id === id))?.id;
  assert.equal(shelfOf('rare'), shelfOf('a1'));
  assert.equal(shelfOf('loner'), 'on-their-own');
  assert.equal(shelfOf('unused'), 'on-their-own');
  assert.equal(out.groups.at(-1).id, 'on-their-own');
});

test('broken records are skipped without stopping the rest', () => {
  const dishes = [
    null, {}, { ingredients: 'not a list' }, { ingredients: [null, 42, ''] },
    ...Array.from({ length: 4 }, () => ({ ingredients: ['A', 'B', 'C'] })),
  ];
  const { nodes, links } = linksFrom(dishes);
  assert.deepEqual(nodes, ['A', 'B', 'C']);
  assert.equal(links.length, 3);
  assert.deepEqual(linksFrom(undefined).nodes, []);
  const out = buildGroups({ dishes, ingredients: [null, { name: 'no id' }, { id: 'A' }, { id: 'B' }, { id: 'C' }, { id: 'D' }] });
  assert.equal(out.ingredients, 4);
  assert.deepEqual(buildGroups(undefined).groups, []);
});

test('two separate clusters come out as two groups', () => {
  const dishes = [
    ...Array.from({ length: 5 }, () => ({ ingredients: ['a1', 'a2', 'a3', 'a4'] })),
    ...Array.from({ length: 5 }, () => ({ ingredients: ['b1', 'b2', 'b3', 'b4'] })),
  ];
  const { nodes, links } = linksFrom(dishes);
  const g = tidyGroups(louvain(nodes, links), links);
  assert.equal(g.get('a1'), g.get('a4'));
  assert.equal(g.get('b1'), g.get('b4'));
  assert.notEqual(g.get('a1'), g.get('b1'));
});
