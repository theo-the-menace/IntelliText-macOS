#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="$ROOT_DIR/.build/IntelliText.app"
CONTENTS_DIR="$APP_DIR/Contents"

swift build -c release --product IntelliTextApp --package-path "$ROOT_DIR"
mkdir -p "$CONTENTS_DIR/MacOS"
cp "$ROOT_DIR/.build/release/IntelliTextApp" "$CONTENTS_DIR/MacOS/IntelliTextApp"
cp "$ROOT_DIR/Resources/IntelliTextApp/Info.plist" "$CONTENTS_DIR/Info.plist"
codesign --force --deep --sign - "$APP_DIR"
open "$APP_DIR"
print "Built and launched $APP_DIR"
