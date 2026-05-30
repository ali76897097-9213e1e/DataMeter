#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="DataMeter.app"
BUILD_APP="$ROOT_DIR/DerivedData/Build/Products/Release/$APP_NAME"
INSTALL_APP="/Applications/$APP_NAME"

cd "$ROOT_DIR"
xcodegen generate
xcodebuild -project DataMeter.xcodeproj -scheme DataMeter -configuration Release -derivedDataPath DerivedData build -quiet

pkill -x DataMeter 2>/dev/null || true
rm -rf "$INSTALL_APP"
ditto "$BUILD_APP" "$INSTALL_APP"
open -n "$INSTALL_APP"

echo "Installed and launched $INSTALL_APP"
echo "Enable Launch at Login in DataMeter Settings if you want it to start automatically."
