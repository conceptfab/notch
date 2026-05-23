#!/usr/bin/env bash
# End-to-end release pipeline:
#   1. Run the full test suite.
#   2. Build the Release-configuration app bundle.
#   3. Package it as a DMG.
#   4. Write a SHA-256 checksum file next to the DMG.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

RELEASE_DIR="${RELEASE_DIR:-dist}"

echo "==> Cleaning prior release artifacts..."
rm -rf "$RELEASE_DIR" .build-release

echo "==> [1/4] Running tests..."
scripts/test.sh

echo "==> [2/4] Building Release..."
scripts/release.sh

echo "==> [3/4] Packaging DMG..."
scripts/package-dmg.sh

VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$RELEASE_DIR/NotchShelf.app/Contents/Info.plist")"
DMG_PATH="$RELEASE_DIR/NotchShelf-$VERSION.dmg"
if [[ ! -f "$DMG_PATH" ]]; then
  echo "error: no DMG produced at $DMG_PATH" >&2
  exit 1
fi

CHECKSUM_PATH="$DMG_PATH.sha256"
echo "==> [4/4] Computing SHA-256 -> $CHECKSUM_PATH"
(cd "$RELEASE_DIR" && shasum -a 256 "$(basename "$DMG_PATH")" > "$(basename "$CHECKSUM_PATH")")

echo
echo "Release artifacts:"
ls -la "$DMG_PATH" "$CHECKSUM_PATH"
echo
echo "Verify from the dist directory with:"
echo "  (cd $RELEASE_DIR && shasum -a 256 -c $(basename "$CHECKSUM_PATH"))"
