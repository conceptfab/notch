#!/usr/bin/env bash
# Contract tests for scripts/release.sh, scripts/package-dmg.sh, and
# scripts/distribute.sh. These check pipeline invariants without running a build.
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

failures=0

assert_exec() {
  local path="$1"
  if [[ ! -x "$path" ]]; then
    echo "FAIL: $path is not executable"
    failures=$((failures + 1))
  fi
}

assert_contains() {
  local path="$1" needle="$2" label="$3"
  if [[ ! -f "$path" ]] || ! grep -qF -- "$needle" "$path"; then
    echo "FAIL: $label - '$path' must contain: $needle"
    failures=$((failures + 1))
  fi
}

# release.sh contract
assert_exec scripts/release.sh
assert_contains scripts/release.sh 'CODE_SIGN_IDENTITY="-"' 'release.sh signs ad-hoc'
assert_contains scripts/release.sh 'CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO' 'release.sh excludes debugger entitlement'
assert_contains scripts/release.sh '-configuration "$CONFIGURATION"' 'release.sh passes configuration'
assert_contains scripts/release.sh 'codesign --verify' 'release.sh verifies the signature'
assert_contains scripts/release.sh 'com.apple.security.get-task-allow' 'release.sh rejects debugger entitlement'

# package-dmg.sh contract
assert_exec scripts/package-dmg.sh
assert_contains scripts/package-dmg.sh 'hdiutil create' 'package-dmg.sh creates a DMG'
assert_contains scripts/package-dmg.sh 'ln -s /Applications' 'package-dmg.sh adds /Applications symlink'
assert_contains scripts/package-dmg.sh 'CFBundleShortVersionString' 'package-dmg.sh reads the app version'

# distribute.sh contract
assert_exec scripts/distribute.sh
assert_contains scripts/distribute.sh 'scripts/test.sh' 'distribute.sh runs tests'
assert_contains scripts/distribute.sh 'scripts/release.sh' 'distribute.sh builds Release'
assert_contains scripts/distribute.sh 'scripts/package-dmg.sh' 'distribute.sh packages a DMG'
assert_contains scripts/distribute.sh 'shasum -a 256' 'distribute.sh writes SHA-256 checksum'

if (( failures > 0 )); then
  echo
  echo "scripts/test-release-scripts.sh: $failures failure(s)"
  exit 1
fi

echo "scripts/test-release-scripts.sh: OK"
