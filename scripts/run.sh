#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

CONFIGURATION="${CONFIGURATION:-Debug}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-.build}"
APP_PATH="$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/NotchShelf.app"

if [[ ! -d "$APP_PATH" ]]; then
  echo "App bundle not found at $APP_PATH; building first..."
  scripts/build.sh
fi

echo "Opening: $APP_PATH"
open "$APP_PATH"
