#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
ARTIFACT_DIR="$ROOT_DIR/artifacts/smoke"
APP_PATH="$ROOT_DIR/DerivedData/Build/Products/Debug/DataMeter.app"

mkdir -p "$ARTIFACT_DIR"
cd "$ROOT_DIR"

xcodegen generate
xcodebuild -project DataMeter.xcodeproj -scheme DataMeter -configuration Debug -derivedDataPath DerivedData build -quiet

pkill -x DataMeter 2>/dev/null || true
sleep 1
open -n "$APP_PATH"
sleep 8
osascript -e 'tell application "DataMeter" to activate' >/dev/null 2>&1 || true

AGENT_DEVICE_SESSION="datameter-macos-smoke"
agent-device open --session "$AGENT_DEVICE_SESSION" --platform macos --target desktop --surface frontmost-app >/dev/null
SNAPSHOT="$ARTIFACT_DIR/snapshot.txt"
agent-device snapshot --session "$AGENT_DEVICE_SESSION" --platform macos --target desktop > "$SNAPSHOT"

grep -q '"DataMeter"' "$SNAPSHOT"
grep -q 'Tracking' "$SNAPSHOT"
grep -q '"Today"' "$SNAPSHOT"
grep -q '"All Networks"' "$SNAPSHOT"

osascript -e 'tell application "System Events" to key code 53' >/dev/null 2>&1 || true
sleep 1
osascript -e 'tell application "DataMeter" to activate' >/dev/null 2>&1 || true
agent-device screenshot "$ARTIFACT_DIR/datameter-app.png" --session "$AGENT_DEVICE_SESSION" --platform macos --target desktop --no-stabilize >/dev/null
agent-device close --session "$AGENT_DEVICE_SESSION" --platform macos --target desktop >/dev/null || true
pkill -x DataMeter 2>/dev/null || true

echo "Smoke passed. Artifacts: $ARTIFACT_DIR"
