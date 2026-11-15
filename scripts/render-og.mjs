#!/usr/bin/env node
// Renders the share card (og.png) from scripts/og-card.html: fills in the cuisine and
// country data, opens it in a headless browser at 1200x630 and saves a screenshot.
// Run after changing the card's text or when the map changes a lot. Needs Playwright
// (npx playwright install chromium).
import { readFileSync, writeFileSync, rmSync } from 'node:fs';
import { chromium } from 'playwright';

const root = new URL('../', import.meta.url);

// `node scripts/render-og.mjs ingredients` renders the Every ingredient page's card from the
// real shelves (scripts/og-ingredients.html + data/ingredient_groups.json)
if (process.argv[2] === 'ingredients') {
  const data = JSON.parse(readFileSync(new URL('data/ingredient_groups.json', root), 'utf8'));
  const esc = (t) => String(t).replace(/&/g, '&amp;').replace(/</g, '&lt;');
  const pick = ['Southeast Asia', 'Southern Europe', 'South Asia'];
  const shelves = pick.map((name) => data.groups.find((g) => g.name === name) ?? data.groups[0]).map((g) =>
    `<div class="shelf"><h2>${esc(g.name)}</h2><p class="lead">${g.lead.map((i) => `<span>${esc(i.name)}</span>`).join(' ')}</p>` +
    `<p class="rest">${g.rest.slice(0, 14).map((i) => `<span>${esc(i.name)}</span>`).join(' ')}</p></div>`).join('');
  const html = readFileSync(new URL('scripts/og-ingredients.html', root), 'utf8')
    .replace('<div class="shelves">{{SHELVES}}</div>', () => '<div class="shelves">' + shelves + '</div>')
    .replace('{{COUNT}}', data.ingredients.toLocaleString('en-US'))
    .replace('{{HOODS}}', String(data.groups.filter((g) => g.continent).length));
  const tmp = new URL('scripts/.og-ingredients.html', root);
  writeFileSync(tmp, html);
  const browser = await chromium.launch();
  const page = await browser.newPage({ viewport: { width: 1200, height: 630 } });
  await page.goto(tmp.href);
  await page.evaluate(() => document.fonts.ready);
  await page.screenshot({ path: new URL('ingredients-share.png', root).pathname });
  await browser.close();
  rmSync(tmp);
  console.log('Rendered ingredients-share.png');
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
