#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACT_DIR="$ROOT_DIR/artifacts/smoke"
APP_PATH="/Applications/DataMeter.app"
APP_EXEC="$APP_PATH/Contents/MacOS/DataMeter"

mkdir -p "$ARTIFACT_DIR"
cd "$ROOT_DIR"

# Smoke the same app bundle used locally, not the DerivedData debug product.
# This validates installed resources, LaunchServices behavior, and prevents
# accidentally running two DataMeter copies during release/soak checks.
scripts/install-local.sh >/dev/null

pkill -x DataMeter 2>/dev/null || true
sleep 1
open -n "$APP_PATH"
sleep 8

PID="$(pgrep -nx DataMeter || true)"
if [ -z "$PID" ]; then
  echo "DataMeter did not launch" >&2
  exit 1
fi

COMMAND_PATH="$(ps -p "$PID" -o comm= | tr -d '\n')"
if [ "$COMMAND_PATH" != "$APP_EXEC" ]; then
  echo "Unexpected DataMeter executable: $COMMAND_PATH" >&2
  echo "Expected: $APP_EXEC" >&2
  exit 1
fi

osascript -e 'tell application "DataMeter" to activate' >/dev/null 2>&1 || true
sleep 1

AGENT_DEVICE_SESSION="datameter-macos-smoke"
agent-device close --session "$AGENT_DEVICE_SESSION" >/dev/null 2>&1 || true
agent-device open --session "$AGENT_DEVICE_SESSION" --platform macos --target desktop --surface frontmost-app >/dev/null
SNAPSHOT="$ARTIFACT_DIR/snapshot.txt"
agent-device snapshot --session "$AGENT_DEVICE_SESSION" > "$SNAPSHOT"

grep -q '"DataMeter"' "$SNAPSHOT"
grep -q 'Tracking' "$SNAPSHOT"
grep -q '"Today"' "$SNAPSHOT"
grep -q '"All Networks"' "$SNAPSHOT"

agent-device screenshot "$ARTIFACT_DIR/datameter-app.png" --session "$AGENT_DEVICE_SESSION" --no-stabilize >/dev/null
agent-device close --session "$AGENT_DEVICE_SESSION" >/dev/null || true

pkill -x DataMeter 2>/dev/null || true
open -n "$APP_PATH"
sleep 1

echo "Smoke passed for $APP_PATH. Artifacts: $ARTIFACT_DIR"
