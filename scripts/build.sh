#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")/.."
xcodegen generate
xcodebuild -project NotchShelf.xcodeproj -scheme NotchShelf \
  -configuration Debug -derivedDataPath .build build
echo "Built: .build/Build/Products/Debug/NotchShelf.app"
echo "Run with: open .build/Build/Products/Debug/NotchShelf.app"
