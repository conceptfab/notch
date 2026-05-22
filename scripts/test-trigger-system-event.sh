#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
SCRIPT="$ROOT_DIR/scripts/trigger-system-event.sh"

bash -n "$SCRIPT"

if ! grep -Fq 'MODE="${1:-distributed}"' "$SCRIPT"; then
  echo "error: trigger-system-event.sh must default to the non-visible distributed mode." >&2
  exit 1
fi

HELP_OUTPUT="$("$SCRIPT" --help)"

if ! grep -Fq "Posts a synthetic DistributedNotificationCenter event by default." <<<"$HELP_OUTPUT"; then
  echo "error: help output must describe the quiet default behavior." >&2
  exit 1
fi

if ! grep -Fq "notification  Show a visible macOS notification, then post the distributed event." <<<"$HELP_OUTPUT"; then
  echo "error: help output must make visible notifications opt-in." >&2
  exit 1
fi

if grep -Fq "Shows a visible macOS notification by default" <<<"$HELP_OUTPUT"; then
  echo "error: help output must not advertise notification spam as the default." >&2
  exit 1
fi

echo "trigger-system-event.sh CLI contract ok"
