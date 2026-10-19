#!/bin/bash
# Builds MainMic.app (Apple Silicon) into ./build.
#   --dmg      also package build/MainMic.dmg (drag-to-Applications disk image)
#   --install  copy the app to /Applications and launch it
set -euo pipefail
cd "$(dirname "$0")"

MAKE_DMG=0
INSTALL=0
for arg in "$@"; do
    case "$arg" in
        --dmg) MAKE_DMG=1 ;;
        --install) INSTALL=1 ;;
        *) echo "Unknown option: $arg" >&2; exit 1 ;;
    esac
done

swift build -c release --arch arm64
BIN="$(swift build -c release --arch arm64 --show-bin-path)/MainMic"

APP=build/MainMic.app
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/MainMic"
cp Resources/Info.plist "$APP/Contents/Info.plist"
cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
codesign --force --sign - --timestamp=none "$APP"
echo "Built $APP ($(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Contents/Info.plist"))"

if [[ $MAKE_DMG == 1 ]]; then
    DMG=build/MainMic.dmg
    STAGE="$(mktemp -d)"
    cp -R "$APP" "$STAGE/"
    ln -s /Applications "$STAGE/Applications"
    rm -f "$DMG"
    hdiutil create -volname MainMic -srcfolder "$STAGE" -fs HFS+ -format UDZO -ov "$DMG" >/dev/null
    rm -rf "$STAGE"
    echo "Built $DMG"
fi

if [[ $INSTALL == 1 ]]; then
    pkill -x MainMic 2>/dev/null || true
    rm -rf /Applications/MainMic.app
    cp -R "$APP" /Applications/
    open /Applications/MainMic.app
    echo "Installed and launched /Applications/MainMic.app"
fi
