A copy of [KitchenCatalog](https://github.com/kyle-pace/kitchen-catalog) (private): the shared grocery list that Henwood, Grocery Deals and Recipe search use, and its matcher. World cuisine links its ingredients to it (`scripts/link_catalog.mjs`), so an ingredient page can send you to recipes for it. `VERSION` is the commit it came from. Don't edit these files; change the catalog there, then run `npm run sync-catalog`.

It lives under `scripts/` on purpose: `scripts/stage-app.mjs` publishes all of `vendor/` with the site, and this is only needed at build time.
