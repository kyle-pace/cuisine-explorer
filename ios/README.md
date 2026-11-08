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

- **Explore**: cuisines to start from, where you left off (recently viewed, saved), cuisines by continent, Beyond borders, Indigenous foodways, and lists of every dish, ingredient, cookbook and recipe site. Cuisine lists filter by national, regional and Indigenous. Settings has KitchenUI's appearance rows and the sources.
- **Map**: every cuisine with a place, colored by continent; a globe when zoomed out. Chips jump to a continent; regional cuisines appear as you zoom in.
- **Search**: everything by name, with scopes by type.
- **Pages**: the same page models as the web view (`scripts/build_web.mjs`), drawn natively: links between pages, photos with credits (tap for full screen), where ingredients are grown, sources. Save and share from the toolbar.
- **Connections** (walk mode, as on the web): the page in the middle, everything linked to it on a ring, the likeliest next steps (cuisines, then dishes) labeled on the outer ring. Tap a dot to move there; hold an unlabeled one for its name; the trail retraces your route. Chips focus on one type; the list button shows every link.

## Files

- `Sources/Store.swift`: the skeleton, the app index, search and hubs; page buckets on demand.
- `Sources/Page.swift`: the page model and photo credits.
- `Sources/Remote.swift`: where the data comes from, and the cache.
- `Sources/WalkView.swift`: walk mode (`RadialGraph`, also the small preview on pages).
- `Sources/Library.swift`: saved and recently viewed, in UserDefaults.
- `Sources/Theme.swift`: Cuisines' palette for KitchenUI (saffron on aubergine).

For screenshots, launch arguments open a screen: `-open cuisine/thai-cuisine`, `-walk dish/pad-thai`, `-hub "cuisines#asia"`, `-map cuisine/mexican-cuisine`, `-tab map`, and `-scrollTo "Where it's grown"` with `-open`.
