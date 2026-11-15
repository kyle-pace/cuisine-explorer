#!/usr/bin/env node
// Renders the share card (og.png) from scripts/og-card.html: fills in the cuisine and
// country data, opens it in a headless browser at 1200x630 and saves a screenshot.
// Run after changing the card's text or when the map changes a lot. Needs Playwright
// (npx playwright install chromium).
import { readFileSync, writeFileSync, rmSync } from 'node:fs';
import { chromium } from 'playwright';

const root = new URL('../', import.meta.url);

// `node scripts/render-og.mjs ingredient-map` renders the ingredient map's card from the real
// map (scripts/og-ingredient-map.html + scripts/ingredient_map_svg.mjs), with lemongrass lit
if (process.argv[2] === 'ingredient-map') {
  const { mapSvg } = await import('./ingredient_map_svg.mjs');
  const map = JSON.parse(readFileSync(new URL('data/ingredient_map.json', root), 'utf8'));
  const html = readFileSync(new URL('scripts/og-ingredient-map.html', root), 'utf8')
    .replace('<div class="map">{{SVG}}</div>', () => '<div class="map">' + mapSvg(map, { interactive: true }) + '</div>')
    .replace('{{COUNT}}', String(map.nodes.length))
    .replace('{{HOODS}}', String(map.groups.length));
  const tmp = new URL('scripts/.og-ingredient-map.html', root);
  writeFileSync(tmp, html);
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1200, height: 630 } });
  await page.goto(tmp.href);
  await page.evaluate(() => {
    const svg = document.querySelector('svg');
    const me = svg.querySelector('a.ing[data-slug="lemongrass"]');
    const near = me.dataset.near.split(' ');
    svg.classList.add('active');
    me.classList.add('on', 'me');
    for (const s of near) svg.querySelector(`a.ing[data-slug="${s}"]`)?.classList.add('on');
    svg.querySelectorAll('.links line').forEach((l) => {
      if ((l.dataset.a === 'lemongrass' && near.includes(l.dataset.b)) || (l.dataset.b === 'lemongrass' && near.includes(l.dataset.a))) l.classList.add('on');
    });
  });
  await page.evaluate(() => document.fonts.ready);
  // Names that would peek out from behind the title read as fragments; leave them off the card
  await page.evaluate(() => document.querySelectorAll('.hoods text, .lab').forEach((t) => { if (t.getBoundingClientRect().left < 600) t.style.display = 'none'; }));
  await page.screenshot({ path: new URL('ingredient-map-share.png', root).pathname });
  await browser.close();
  rmSync(tmp);
  console.log('Rendered ingredient-map-share.png');
  process.exit(0);
}

// `node scripts/render-og.mjs drop` renders Dish drop's card (scripts/og-drop.html) instead
if (process.argv[2] === 'drop') {
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1200, height: 630 } });
  await page.goto(new URL('scripts/og-drop.html', root).href);
  await page.waitForTimeout(1000);
  await page.screenshot({ path: new URL('drop-share.png', root).pathname });
  await browser.close();
  console.log('Rendered drop-share.png');
  process.exit(0);
}
const tag = (id, file) =>
  `<script type="application/json" id="${id}">${readFileSync(new URL(file, root), 'utf8').replace(/</g, '\\u003c')}</script>`;
const html = readFileSync(new URL('scripts/og-card.html', root), 'utf8').replace(
  '<!--INLINE_DATA-->',
  tag('data-cuisines', 'data/cuisines.json') + tag('data-countries', 'data/countries.geojson'),
);
const tmp = new URL('scripts/.og-render.html', root);
writeFileSync(tmp, html);
const browser = await chromium.launch({ args: ['--use-gl=angle', '--use-angle=swiftshader', '--enable-unsafe-swiftshader'] });
const page = await browser.newPage({ viewport: { width: 1200, height: 630 } });
await page.goto(tmp.href);
await page.waitForTimeout(4000);
await page.screenshot({ path: new URL('og.png', root).pathname });
await browser.close();
rmSync(tmp);
console.log('Rendered og.png');
