#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

CONFIGURATION="${CONFIGURATION:-Debug}"
DERIVED_DATA_PATH="${DERIVED_DATA_PATH:-.build}"
APP_PATH="$ROOT_DIR/$DERIVED_DATA_PATH/Build/Products/$CONFIGURATION/NotchShelf.app"
LABEL="com.notchshelf.NotchShelf.autostart"
LAUNCH_AGENTS_DIR="$HOME/Library/LaunchAgents"
PLIST_PATH="$LAUNCH_AGENTS_DIR/$LABEL.plist"
LOG_DIR="$HOME/Library/Logs/NotchShelf"

xml_escape() {
  local value="$1"
  value="${value//&/&amp;}"
  value="${value//</&lt;}"
  value="${value//>/&gt;}"
  printf '%s' "$value"
}

uninstall() {
  if [[ -f "$PLIST_PATH" ]]; then
    /bin/launchctl bootout "gui/$UID" "$PLIST_PATH" >/dev/null 2>&1 || true
    rm -f "$PLIST_PATH"
    echo "Removed autostart LaunchAgent: $PLIST_PATH"
  else
    echo "Autostart LaunchAgent is not installed."
  fi
}

install() {
  if [[ ! -d "$APP_PATH" ]]; then
    echo "App bundle not found at $APP_PATH; building first..."
    scripts/build.sh
  fi

  mkdir -p "$LAUNCH_AGENTS_DIR" "$LOG_DIR"

  local escaped_app_path
  local escaped_stdout_path
  local escaped_stderr_path
  escaped_app_path="$(xml_escape "$APP_PATH")"
  escaped_stdout_path="$(xml_escape "$LOG_DIR/autostart.out.log")"
  escaped_stderr_path="$(xml_escape "$LOG_DIR/autostart.err.log")"

  tee "$PLIST_PATH" >/dev/null <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>$LABEL</string>
  <key>ProgramArguments</key>
  <array>
    <string>/usr/bin/open</string>
    <string>$escaped_app_path</string>
  </array>
  <key>RunAtLoad</key>
  <true/>
  <key>StandardOutPath</key>
  <string>$escaped_stdout_path</string>
  <key>StandardErrorPath</key>
  <string>$escaped_stderr_path</string>
</dict>
</plist>
PLIST

  /bin/launchctl bootout "gui/$UID" "$PLIST_PATH" >/dev/null 2>&1 || true
  /bin/launchctl bootstrap "gui/$UID" "$PLIST_PATH"

  echo "Installed autostart LaunchAgent: $PLIST_PATH"
  echo "App will open at login: $APP_PATH"
}

case "${1:-install}" in
  install)
    install
    ;;
  uninstall|remove)
    uninstall
    ;;
  *)
    echo "usage: scripts/install-autostart.sh [install|uninstall]" >&2
    exit 2
    ;;
esac
