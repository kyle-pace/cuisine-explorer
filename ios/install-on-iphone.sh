#!/bin/sh
# Build "Cuisines Dev" (dev bundle ID, name and DEV icon, next to the regular app)
# and install it on every linked iPhone, plugged in or paired over Wi-Fi, unlocked and trusted.
# Usage: ios/install-on-iphone.sh              build what's checked out, install, open it
#        ios/install-on-iphone.sh --no-open    install without opening
# Uses the newest Xcode found in Applications or Downloads; set XCODE=/path/to/Xcode.app to
# choose. An iOS beta on the phone needs the matching Xcode beta. Needs KitchenUI next to this
# repo (../../KitchenUI from here).
set -e
cd "$(dirname "$0")"
OPEN=yes
[ "$1" = "--no-open" ] && OPEN=no

if [ -z "$XCODE" ]; then
  XCODE=$(for x in /Applications/Xcode*.app /Applications/Utilities/Xcode*.app "$HOME"/Downloads/Xcode*.app; do
    [ -d "$x" ] || continue
    v=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$x/Contents/Info.plist" 2>/dev/null) || continue
    printf '%s\t%s\n' "$v" "$x"
  done | sort -t "$(printf '\t')" -k1,1V | tail -1 | cut -f2)
fi
[ -n "$XCODE" ] || { echo "No Xcode found. Set XCODE=/path/to/Xcode.app"; exit 1; }
export DEVELOPER_DIR="$XCODE/Contents/Developer"

DEVICES=$(xcrun devicectl list devices 2>/dev/null | awk '!/simulated/ && /iPhone/ && (/available/ || /connected/) { for (i = 1; i <= NF; i++) if ($i ~ /^[0-9A-F]{8}-[0-9A-F]{16}$/ || $i ~ /^[0-9A-F-]{36}$/) { print $i; break } }')
[ -n "$DEVICES" ] || { echo "No iPhone found. Plug it in (or pair it over Wi-Fi in Xcode's Devices window), unlock it, and trust this Mac."; exit 1; }
command -v xcodegen >/dev/null || { echo "Install XcodeGen first: brew install xcodegen"; exit 1; }

echo "Cuisines Dev from $(git rev-parse --abbrev-ref HEAD) at $(git rev-parse --short HEAD)$( [ -n "$(git status --porcelain)" ] && echo ', with uncommitted changes'), $(basename "$XCODE")"
xcodegen generate --quiet
echo "Building..."
xcodebuild -project Cuisines.xcodeproj -scheme Cuisines -configuration Release -destination "generic/platform=iOS" \
  -derivedDataPath build -allowProvisioningUpdates -allowProvisioningDeviceRegistration \
  BUNDLE_ID_SUFFIX=.dev APP_NAME_SUFFIX=" Dev" APP_ICON_SUFFIX=Dev build > build.log 2>&1 \
  || { grep -E "error:" build.log | sort -u | head; echo "Build failed; see ios/build.log"; exit 1; }
for DEVICE in $DEVICES; do
  NAME=$(xcrun devicectl list devices 2>/dev/null | grep "$DEVICE" | awk '{print $1}')
  echo "Installing on $NAME..."
  if xcrun devicectl device install app --device "$DEVICE" build/Build/Products/Release-iphoneos/Cuisines.app > /dev/null 2>&1; then
    echo "Cuisines Dev is on $NAME."
    if [ "$OPEN" = yes ]; then
      xcrun devicectl device process launch --device "$DEVICE" net.kylepace.cuisines.dev > /dev/null 2>&1 || echo "(Unlock $NAME to open it.)"
    fi
  else
    echo "Couldn't install on $NAME. If it's new, build once from Xcode with it selected so it's added to the profile, then run this again."
  fi
done
