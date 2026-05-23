#!/usr/bin/env bash
# Packages dist/NotchShelf.app into dist/NotchShelf-<version>.dmg with:
#   - /Applications symlink (drag-install)
#   - INSTALL.md (Gatekeeper workaround for end users)
#   - LICENSE (MIT)
# Layout mirrors the sibling Clank app for visual and structural consistency.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

RELEASE_DIR="${RELEASE_DIR:-dist}"
APP_PATH="$RELEASE_DIR/NotchShelf.app"
INFO_PLIST="$APP_PATH/Contents/Info.plist"

if [[ ! -d "$APP_PATH" ]]; then
  echo "error: $APP_PATH not found. Run scripts/release.sh first." >&2
  exit 1
fi

for required in INSTALL.md LICENSE; do
  if [[ ! -f "$required" ]]; then
    echo "error: $required missing; documentation setup must complete first." >&2
    exit 1
  fi
done

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$INFO_PLIST")"
DMG_NAME="NotchShelf-$VERSION.dmg"
DMG_PATH="$RELEASE_DIR/$DMG_NAME"
STAGING_DIR="$(mktemp -d -t notchshelf-dmg.XXXXXX)"
trap 'rm -rf "$STAGING_DIR"' EXIT

echo "==> Staging DMG contents in $STAGING_DIR..."
ditto "$APP_PATH" "$STAGING_DIR/NotchShelf.app"
cp INSTALL.md "$STAGING_DIR/INSTALL.md"
cp LICENSE "$STAGING_DIR/LICENSE"
ln -s /Applications "$STAGING_DIR/Applications"

rm -f "$DMG_PATH"

echo "==> Creating compressed DMG: $DMG_PATH"
hdiutil create \
  -volname "NotchShelf $VERSION" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

echo "==> Verifying DMG..."
hdiutil verify "$DMG_PATH"

echo
echo "Packaged: $DMG_PATH"
ls -lh "$DMG_PATH"
echo "Next: scripts/distribute.sh (full pipeline) or shasum manually."
