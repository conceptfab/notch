#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

BUNDLE_ID="com.notchshelf.NotchShelf"
DEFAULT_EVENT_NAME="com.apple.notificationcenterui.banner"
MODE="${1:-notification}"
EVENT_NAME="${2:-$DEFAULT_EVENT_NAME}"
MODULE_CACHE_PATH="${SWIFT_MODULE_CACHE_PATH:-/tmp/notchshelf-swift-module-cache}"
NOTIFICATION_TITLE="${NOTIFICATION_TITLE:-NotchShelf system event test}"
NOTIFICATION_MESSAGE="${NOTIFICATION_MESSAGE:-This is a real macOS notification banner. NotchShelf should glow now.}"

usage() {
  cat <<USAGE
Usage: scripts/trigger-system-event.sh [notification|distributed] [distributed-notification-name]

Shows a visible macOS notification by default, then posts a global distributed
notification that NotchShelf listens for. This gives a visible system message and
a deterministic app reaction in one command.

Modes:
  notification  Show a real macOS notification, then post the distributed event.
  distributed   Post a synthetic DistributedNotificationCenter event.

Default distributed event:
  $DEFAULT_EVENT_NAME

Use REAL_NOTIFICATION_ONLY=1 to test only the raw macOS notification banner,
without the app-observable distributed event.

Examples:
  scripts/trigger-system-event.sh
  scripts/trigger-system-event.sh notification
  scripts/trigger-system-event.sh distributed com.apple.notificationcenterui.customalerts
  NOTIFICATION_MESSAGE="Hello from NotchShelf test" scripts/trigger-system-event.sh
  REAL_NOTIFICATION_ONLY=1 scripts/trigger-system-event.sh
  ENABLE_PREF=0 scripts/trigger-system-event.sh distributed com.apple.usernotifications.test.banner
USAGE
}

if [[ "$MODE" == "-h" || "$MODE" == "--help" ]]; then
  usage
  exit 0
fi

if [[ "$MODE" != "notification" && "$MODE" != "distributed" ]]; then
  echo "error: unknown mode '$MODE'" >&2
  usage >&2
  exit 2
fi

if [[ "${ENABLE_PREF:-1}" != "0" ]]; then
  /usr/bin/defaults write "$BUNDLE_ID" glowOnSystemEvents -bool true
fi

if ! /usr/bin/pgrep -x NotchShelf >/dev/null 2>&1; then
  echo "warning: NotchShelf does not appear to be running; start it with scripts/run.sh first." >&2
fi

mkdir -p "$MODULE_CACHE_PATH"

post_distributed_notification() {
  NOTCHSHELF_TEST_EVENT_NAME="$EVENT_NAME" \
  /usr/bin/swift -module-cache-path "$MODULE_CACHE_PATH" -e '
import Foundation

let eventName = ProcessInfo.processInfo.environment["NOTCHSHELF_TEST_EVENT_NAME"]
    ?? "com.apple.notificationcenterui.banner"

DistributedNotificationCenter.default().post(
    name: Notification.Name(eventName),
    object: nil
)

print("Posted distributed notification: \(eventName)")
'
}

if [[ "$MODE" == "notification" ]]; then
  NOTCHSHELF_TEST_NOTIFICATION_TITLE="$NOTIFICATION_TITLE" \
  NOTCHSHELF_TEST_NOTIFICATION_MESSAGE="$NOTIFICATION_MESSAGE" \
    /usr/bin/osascript <<'APPLESCRIPT'
set notificationTitle to system attribute "NOTCHSHELF_TEST_NOTIFICATION_TITLE"
set notificationMessage to system attribute "NOTCHSHELF_TEST_NOTIFICATION_MESSAGE"
display notification notificationMessage with title notificationTitle
APPLESCRIPT

  echo "Posted visible macOS notification: $NOTIFICATION_MESSAGE"

  if [[ "${REAL_NOTIFICATION_ONLY:-0}" != "1" ]]; then
    post_distributed_notification
  fi
  exit 0
fi

post_distributed_notification
