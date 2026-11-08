# Cuisines for iPhone

A native SwiftUI version of the cuisine explorer, built like Henwood and Grocery Deals:
KitchenUI for type, color and shared components, XcodeGen for the project.

It doesn't depend on kylepace.net. It loads its data from this repo on GitHub
(`data/web/`, refreshed by the weekly rebuild); the address is `DataSource.base` in
`Sources/Remote.swift`. At launch it loads the skeleton (every page's name, type and
color) and `app.json` (map places, continents, photos; built by
`scripts/build_app_index.mjs`). Each page's bucket loads when you open it. Photos load
from Wikimedia Commons with each one's credit. Everything is cached, so pages you've
opened work offline.

## Build and install

Needs Xcode, XcodeGen (`brew install xcodegen`) and KitchenUI checked out next to this
repo (`../../KitchenUI` from here).

    ios/install-on-iphone.sh            # "Cuisines Dev" on every linked iPhone, then open it
    cd ios && xcodegen generate && open Cuisines.xcodeproj

## What's in it

- **Explore**: cuisines to start from, cuisines by continent, Beyond borders, Indigenous foodways, and lists of every dish, ingredient, cookbook and recipe site. Settings has KitchenUI's appearance rows and the sources.
- **Map**: every cuisine with a place, colored by continent. Regional cuisines appear as you zoom in.
- **Search**: everything by name.
- **Pages**: the same page models as the web view (`scripts/build_web.mjs`), drawn natively: links between pages, photos with credits, where ingredients are grown, sources.

## Files

- `Sources/Store.swift`: the skeleton, the app index, search and hubs; page buckets on demand.
- `Sources/Page.swift`: the page model and photo credits.
- `Sources/Remote.swift`: where the data comes from, and the cache.
- `Sources/Theme.swift`: Cuisines' palette for KitchenUI (saffron on aubergine).

For screenshots, launch arguments open a page or the map: `-open cuisine/thai-cuisine`, `-map cuisine/mexican-cuisine`.
