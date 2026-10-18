#!/bin/bash
# Builds MainMic.app (Apple Silicon) into ./build. Pass --install to copy it to /Applications.
set -euo pipefail
cd "$(dirname "$0")"

swift build -c release --arch arm64
BIN="$(swift build -c release --arch arm64 --show-bin-path)/MainMic"

APP=build/MainMic.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/MainMic"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - --timestamp=none "$APP"
echo "Built $APP"

if [[ "${1:-}" == "--install" ]]; then
    pkill -x MainMic 2>/dev/null || true
    rm -rf /Applications/MainMic.app
    cp -R "$APP" /Applications/
    open /Applications/MainMic.app
    echo "Installed and launched /Applications/MainMic.app"
fi
