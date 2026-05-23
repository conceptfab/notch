#!/usr/bin/env bash
# Builds NotchShelf in Release configuration with explicit ad-hoc signing.
# Output: $RELEASE_DIR/NotchShelf.app (default: dist/NotchShelf.app)
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

CONFIGURATION="Release"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-.build-release}"
RELEASE_DIR="${RELEASE_DIR:-dist}"
PROJECT_PATH="NotchShelf.xcodeproj"
SCHEME="NotchShelf"
BUILT_APP="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/NotchShelf.app"
OUTPUT_APP="$RELEASE_DIR/NotchShelf.app"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "error: xcodegen is required. Install with: brew install xcodegen" >&2
  exit 1
fi

echo "==> Regenerating Xcode project..."
xcodegen generate

echo "==> Cleaning previous Release output..."
rm -rf "$DERIVED_DATA_PATH" "$OUTPUT_APP"
mkdir -p "$RELEASE_DIR"

echo "==> Building Release configuration..."
xcodebuild \
  -project "$PROJECT_PATH" \
  -scheme "$SCHEME" \
  -configuration "$CONFIGURATION" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  CODE_SIGN_IDENTITY="-" \
  CODE_SIGNING_REQUIRED=YES \
  CODE_SIGNING_ALLOWED=YES \
  CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
  build

if [[ ! -d "$BUILT_APP" ]]; then
  echo "error: expected built app at $BUILT_APP, but it is missing" >&2
  exit 1
fi

echo "==> Copying built app to $OUTPUT_APP..."
ditto "$BUILT_APP" "$OUTPUT_APP"

echo "==> Verifying ad-hoc signature..."
codesign --verify --deep --strict --verbose=2 "$OUTPUT_APP"
codesign -dvv "$OUTPUT_APP" 2>&1 | grep -E '^(Identifier|Authority|Signature|TeamIdentifier)='

echo "==> Verifying embedded entitlements..."
ENTITLEMENTS="$(codesign -d --entitlements - "$OUTPUT_APP" 2>&1)"
printf '%s\n' "$ENTITLEMENTS"
if grep -qF 'com.apple.security.get-task-allow' <<<"$ENTITLEMENTS"; then
  echo "error: Release app contains com.apple.security.get-task-allow" >&2
  exit 1
fi

echo
echo "Release build complete: $OUTPUT_APP"
echo "Next: scripts/package-dmg.sh"
