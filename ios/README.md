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
- **Browse** is the first tab, **Map** second, **Wander** (walk mode from a random cuisine, with Somewhere new) third, then Search.
- **Map**: countries filled in their continent's color, regional cuisines drawn as their states and provinces when you zoom in (`data/countries.geojson`, `data/regions.geojson`, loaded on first use), diaspora routes as arcs that light up for the selected cuisine, dots for cuisines that are a place but not an area. Tap any shape for its card; chips jump to a continent; a list button offers every cuisine on the map by continent, for VoiceOver and for reading.
- **Search**: everything by name, with scopes by type.
- **Pages**: the same page models as the web view (`scripts/build_web.mjs`), drawn natively: links between pages, photos with credits (tap to zoom in), cookbooks as a shelf of covers, where ingredients are grown as a Swift Charts bar chart, sources. Save and share from the toolbar; long-press any row for a preview with Save, Share, map and connections.
- **The web** is food: cuisines, dishes and ingredients. Recipe sites and cookbooks stay on pages and in search but aren't dots (`Store.graphKinds`; the web view does the same).
- **Browse**: the most-used ingredients as photo tiles (the ingredients list sorts by use; a Sort menu switches to A to Z), today's dish (`Daily.swift`, the same pick as the widget), cuisines to start from, where you left off, a way into walk mode, cuisines by continent, Beyond borders, Indigenous foodways; every list filters by continent and groups A to Z.
- **Accessibility**: walk-mode dots are VoiceOver buttons with a "Show its name" action, 44-point targets, edges hidden; grids drop columns and the ring labels fewer dots at the accessibility text sizes; Reduce Motion turns the interface motion off (`Theme.motion`); colors never carry meaning alone.
- **iOS**: Spotlight indexes every page (`Spotlight.swift`); Siri and Shortcuts have "Surprise me", "Today's dish" and "Search" (`Intents.swift`); a Today's dish Home Screen widget (`Widget/`); Handoff to the web page; `cuisines://open?r=<ref>`, `cuisines://walk?r=`, `cuisines://map?r=`, `cuisines://search?q=`; Liquid Glass on the map chips; a TipKit tip in walk mode.
- **Connections** (walk mode, as on the web): the page in the middle, everything linked to it on a ring, the likeliest next steps (cuisines, then dishes) labeled on the outer ring. Tap a dot to move there; hold an unlabeled one for its name; the trail retraces your route. Chips focus on one type; the list button shows every link.

## Files

- `Sources/Store.swift`: the skeleton, the app index, search and hubs; page buckets on demand.
- `Sources/Page.swift`: the page model and photo credits.
- `Sources/Remote.swift`: where the data comes from, and the cache.
- `Sources/WalkView.swift`: walk mode (`RadialGraph`, also the small preview on pages).
- `Sources/Library.swift`: saved and recently viewed, in UserDefaults.
- `Sources/Theme.swift`: Cuisines' palette for KitchenUI (saffron on aubergine).

For screenshots, launch arguments open a screen: `-open cuisine/thai-cuisine`, `-walk dish/pad-thai`, `-hub "cuisines#asia"`, `-map cuisine/mexican-cuisine`, `-tab map`, and `-scrollTo "Where it's grown"` with `-open`.
