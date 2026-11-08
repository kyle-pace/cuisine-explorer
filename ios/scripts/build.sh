#!/bin/bash
# Builds the app and, with --install, puts it on the first paired iPhone.
#   ios/scripts/build.sh              build for the simulator
#   ios/scripts/build.sh --install    build for a phone and install it
set -euo pipefail
cd "$(dirname "$0")/.."
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
[ -d /Applications/Xcode.app ] || export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer

# Atkinson Hyperlegible Next (SIL OFL), from a local copy
mkdir -p CuisineExplorer/Fonts
for dir in "${FONTS_DIR:-}" ~/Developer/crow-build/KitchenUI/Sources/KitchenUI/Resources/Fonts ~/Developer/KitchenUI/Sources/KitchenUI/Resources/Fonts; do
  [ -n "$dir" ] && [ -f "$dir/AtkinsonHyperlegibleNext-Regular.ttf" ] && cp "$dir"/AtkinsonHyperlegibleNext-{Regular,Italic,Medium,SemiBold,Bold,ExtraBold}.ttf CuisineExplorer/Fonts/ && break
done

xcodegen --quiet

if [ "${1:-}" = "--install" ]; then
  DEVICE=${DEVICE:-$(xcrun devicectl list devices 2>/dev/null | awk '/iPhone/ && /available/ && /physical/ {for(i=1;i<=NF;i++) if ($i ~ /^[0-9A-F]{8}-/) {print $i; exit}}')}
  [ -n "$DEVICE" ] || { echo "No paired iPhone found"; exit 1; }
  xcodebuild -project CuisineExplorer.xcodeproj -scheme CuisineExplorer -configuration Release \
    -destination "generic/platform=iOS" -derivedDataPath build -allowProvisioningUpdates -quiet build
  xcrun devicectl device install app --device "$DEVICE" build/Build/Products/Release-iphoneos/CuisineExplorer.app
  xcrun devicectl device process launch --device "$DEVICE" net.kylepace.cuisines || true
else
  xcodebuild -project CuisineExplorer.xcodeproj -scheme CuisineExplorer \
    -destination "generic/platform=iOS Simulator" -derivedDataPath build -quiet build
fi
