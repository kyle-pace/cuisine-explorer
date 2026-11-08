#!/usr/bin/env node
// Renders the share card (og.png) from scripts/og-card.html: fills in the cuisine and
// country data, opens it in a headless browser at 1200x630 and saves a screenshot.
// Run after changing the card's text or when the map changes a lot. Needs Playwright
// (npx playwright install chromium).
import { readFileSync, writeFileSync, rmSync } from 'node:fs';
import { chromium } from 'playwright';

const root = new URL('../', import.meta.url);
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
