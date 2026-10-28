#!/bin/sh
# Build a universal Release copy of Matchbox and zip it for a GitHub release.
#
#   scripts/release.sh 0.1.0            # writes build/Matchbox-0.1.0.zip
#   scripts/release.sh 0.1.0 --publish  # ...and creates GitHub release v0.1.0
#
# The version comes from the argument (or the v* tag the workflow is running
# for). The app is ad-hoc signed with the hardened runtime, which is what the
# project already does; there is no Developer ID or notarization yet, so the
# README tells people how to get past Gatekeeper.
set -eu

VERSION="${1:?usage: scripts/release.sh <version> [--publish]}"
VERSION="${VERSION#v}"
PUBLISH="${2:-}"

cd "$(dirname "$0")/.."
OUT=build
PRODUCTS="$OUT/DerivedData/Build/Products/Release"
APP="$PRODUCTS/Matchbox.app"
ZIP="$OUT/Matchbox-$VERSION.zip"
BUILD_NUMBER="$(git rev-list --count HEAD)"

rm -rf "$PRODUCTS" "$ZIP"
xcodebuild \
  -project Matchbox.xcodeproj \
  -scheme Matchbox \
  -configuration Release \
  -derivedDataPath "$OUT/DerivedData" \
  -destination 'generic/platform=macOS' \
  ARCHS="arm64 x86_64" ONLY_ACTIVE_ARCH=NO \
  MARKETING_VERSION="$VERSION" CURRENT_PROJECT_VERSION="$BUILD_NUMBER" \
  CODE_SIGN_IDENTITY="-" \
  build | tail -3

# Sanity checks before anything leaves this machine.
lipo -info "$APP/Contents/MacOS/Matchbox" | grep -q "x86_64 arm64\|arm64 x86_64"
codesign --verify --deep --strict "$APP"
test "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist")" = "$VERSION"

# ditto keeps the bundle layout, resource forks and permissions intact; plain
# zip does not, and Finder may refuse to open the result.
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"
echo "Wrote $ZIP ($(du -h "$ZIP" | cut -f1))"

if [ "$PUBLISH" = "--publish" ]; then
  gh release create "v$VERSION" "$ZIP" \
    --title "Matchbox $VERSION" \
    --generate-notes
fi
