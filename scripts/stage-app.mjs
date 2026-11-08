#!/usr/bin/env node
// Copies the globe and page browser into public/world-cuisine/app/ before every build,
// so the Worker serves them at kylepace.dev/world-cuisine/app/. The files at the repo
// root (index.html, web.html, render_item.js, vendor/, data/) stay the source; the
// staged copy is gitignored. Also stages the share card as /world-cuisine/share.png.
//
// No dependencies; Node 18+.
import { cpSync, rmSync, mkdirSync } from 'node:fs';

const root = new URL('../', import.meta.url);
const app = new URL('public/world-cuisine/app/', root);

rmSync(app, { recursive: true, force: true });
mkdirSync(app, { recursive: true });
for (const f of ['index.html', 'web.html', 'render_item.js']) cpSync(new URL(f, root), new URL(f, app));
for (const d of ['vendor', 'data']) cpSync(new URL(`${d}/`, root), new URL(`${d}/`, app), { recursive: true });
cpSync(new URL('og.png', root), new URL('public/world-cuisine/share.png', root));
console.log('Staged the globe and page browser in public/world-cuisine/app/.');
