#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
BUILD_DIR="$ROOT_DIR/.build/input-method"
APP_DIR="$BUILD_DIR/IntelliText.app"
CONTENTS_DIR="$APP_DIR/Contents"

rm -rf "$BUILD_DIR"
mkdir -p "$CONTENTS_DIR/MacOS" "$CONTENTS_DIR/Resources"

swift build -c release --product IntelliTextInputMethod --package-path "$ROOT_DIR"
BIN_DIR="$(swift build -c release --show-bin-path --package-path "$ROOT_DIR")"
cp "$BIN_DIR/IntelliTextInputMethod" "$CONTENTS_DIR/MacOS/IntelliTextInputMethod"
cp "$ROOT_DIR/Resources/InputMethod/Info.plist" "$CONTENTS_DIR/Info.plist"

# Ad-hoc signing is enough for local installation and keeps the bundle executable.
codesign --force --deep --sign - "$APP_DIR" >/dev/null

echo "$APP_DIR"
