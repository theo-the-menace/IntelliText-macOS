#!/bin/zsh
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
APP_DIR="${1:-$ROOT_DIR/.build/input-method/IntelliText.app}"
INSTALL_DIR="$HOME/Library/Input Methods"

if [[ ! -d "$APP_DIR" ]]; then
  "$ROOT_DIR/Scripts/build-input-method.sh" >/dev/null
fi

mkdir -p "$INSTALL_DIR"
rm -rf "$INSTALL_DIR/IntelliText.app"
cp -R "$APP_DIR" "$INSTALL_DIR/IntelliText.app"

echo "Installed IntelliText.app to $INSTALL_DIR"
echo "Open System Settings > Keyboard > Text Input > Edit and add IntelliText."
