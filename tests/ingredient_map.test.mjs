// Tests for scripts/build_ingredient_map.mjs: grouping World cuisine's ingredients by what
// they're cooked with. Runs against the real dish data (data/food.json) and broken records.
// Run with: node --test tests/*.test.mjs
import { test } from 'node:test';
import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';
import { linksFrom, louvain, tidyGroups, buildMap } from '../scripts/build_ingredient_map.mjs';
import { mapSvg } from '../scripts/ingredient_map_svg.mjs';

const food = JSON.parse(readFileSync(new URL('../data/food.json', import.meta.url), 'utf8'));

test('real dishes give real neighborhoods', () => {
  const map = buildMap(food);
  assert.ok(map.nodes.length > 150, `only ${map.nodes.length} ingredients`);
  assert.ok(map.groups.length >= 5 && map.groups.length <= 30, `${map.groups.length} neighborhoods`);
  const groupOf = (id) => map.nodes.find((n) => n.id === id)?.group;
  // Things cooked together end up together...
  assert.equal(groupOf('Lemongrass'), groupOf('Galangal'));
  assert.equal(groupOf('Wheat flour'), groupOf('Butter'));
  // ...and things that aren't, don't
  assert.notEqual(groupOf('Lemongrass'), groupOf('Butter'));
  for (const g of map.groups) assert.ok(g.members.length >= 4 && g.name && g.cuisines.length, `neighborhood ${g.id}`);
});

test('every ingredient is placed inside the drawing, with a page slug', () => {
  const map = buildMap(food);
  for (const n of map.nodes) {
    assert.ok(n.x >= 0 && n.x <= map.width && n.y >= 0 && n.y <= map.height, `${n.id} at ${n.x},${n.y}`);
    assert.match(n.slug, /^[a-z0-9-]+$/);
  }
});

test('the layout is the same every run', () => {
  assert.deepEqual(buildMap(food).nodes.slice(0, 20), buildMap(food).nodes.slice(0, 20));
});

test('broken dish records are skipped without stopping the rest', () => {
  const dishes = [
    null, {}, { ingredients: 'not a list' }, { ingredients: [null, 42, ''] },
    ...Array.from({ length: 4 }, () => ({ ingredients: ['A', 'B', 'C'] })),
  ];
  const { nodes, links } = linksFrom(dishes);
  assert.deepEqual(nodes, ['A', 'B', 'C']);
  assert.equal(links.length, 3);
  assert.deepEqual(linksFrom(undefined).nodes, []);
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

test('the drawing has one link per ingredient, each with a description', () => {
  const map = buildMap(food);
  const svg = mapSvg(map);
  assert.equal((svg.match(/<a class="ing"/g) ?? []).length, map.nodes.length);
  assert.match(svg, /aria-label="Lemongrass: in \d+ dishes, cooked most with [^"]+\."/);
  assert.equal((svg.match(/class="hood"/g) ?? []).length, map.groups.length);
});
