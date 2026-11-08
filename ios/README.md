# Cuisines for iOS

A native SwiftUI version of the cuisine explorer. It doesn't depend on kylepace.net: it
loads its data from this repo on GitHub (`data/web/`, refreshed by the weekly rebuild),
set in one place, `DataSource.base` in `Remote.swift`. At launch it loads the skeleton
(every page's name, type and color) and `app.json` (map places, continents, photos; built
by `scripts/build_app_index.mjs`); each page's bucket loads when you open it. Photos load
from Wikimedia Commons. Everything is cached on the phone, so pages you've seen open offline.

## Build

On a Mac with Xcode, [XcodeGen](https://github.com/yonaskolb/XcodeGen) and Node:

    ios/scripts/build.sh --install   # build and install on a paired iPhone
    ios/scripts/build.sh             # just build for the simulator

The script copies Atkinson Hyperlegible Next
from a local folder (set `FONTS_DIR` if yours is elsewhere), generates the Xcode project
from `project.yml` and builds. Signing uses team 9BF66MY8TQ. A free-account install
expires after 7 days; a paid account's after a year.

## What's in it

- **Explore**: cuisines to start from, cuisines by continent, Beyond borders, Indigenous foodways, and lists of every dish, ingredient, cookbook and recipe site.
- **Map**: every cuisine with a place, colored by continent. Regional cuisines appear as you zoom in.
- **Search**: everything by name.
- **Pages**: the same page models as the web view (`scripts/build_web.mjs`), drawn natively, with links between pages, photos with their credits, where ingredients are grown, and sources.
