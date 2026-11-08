// @ts-check
import { defineConfig } from 'astro/config';
import cloudflare from '@astrojs/cloudflare';

// World cuisine lives at kylepace.dev/world-cuisine/. It's its own Worker, mounted on
// that path by the routes in wrangler.jsonc; the hub (kyle-pace/kylepace.dev) serves
// everything else on the domain.
// Everything this site serves sits under /world-cuisine/: pages in
// src/pages/world-cuisine/, the staged globe in public/world-cuisine/app/, and built
// assets in /world-cuisine/_astro/. (Astro's `base` option isn't used: with the
// Cloudflare adapter it serves the files from the wrong folder.)
// Static by default; the item pages and the photo route render on request.
export default defineConfig({
  site: 'https://kylepace.dev',
  build: { assets: 'world-cuisine/_astro' },
  session: false,
  adapter: cloudflare({ imageService: 'compile' }),
});
