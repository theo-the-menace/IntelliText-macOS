#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build/input-method"
APP_DIR="$BUILD_DIR/IntelliText.app"
CONTENTS_DIR="$APP_DIR/Contents"
INSTALL_DIR="$HOME/Library/Input Methods"

rm -rf "$BUILD_DIR"
mkdir -p "$CONTENTS_DIR/MacOS" "$CONTENTS_DIR/Resources"
swift build -c release --product IntelliTextInputMethod --package-path "$ROOT_DIR"
BIN_DIR="$(swift build -c release --show-bin-path --package-path "$ROOT_DIR")"
cp "$BIN_DIR/IntelliTextInputMethod" "$CONTENTS_DIR/MacOS/IntelliTextInputMethod"
cp "$ROOT_DIR/Resources/InputMethod/Info.plist" "$CONTENTS_DIR/Info.plist"
codesign --force --deep --sign - "$APP_DIR" >/dev/null

mkdir -p "$INSTALL_DIR"
rm -rf "$INSTALL_DIR/IntelliText.app"
cp -R "$APP_DIR" "$INSTALL_DIR/IntelliText.app"

echo "Built and installed IntelliText.app to $INSTALL_DIR"
echo "Open System Settings > Keyboard > Text Input > Edit and add IntelliText."
