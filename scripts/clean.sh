#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-.build}"

echo "Removing: $DERIVED_DATA_PATH"
rm -rf "$DERIVED_DATA_PATH"
