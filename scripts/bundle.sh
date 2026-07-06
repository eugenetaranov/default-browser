#!/usr/bin/env bash
#
# Build DefaultBrowserRouter and assemble a codesigned .app bundle that macOS can
# register as a default web browser.
#
# Usage:
#   scripts/bundle.sh [--release] [--universal] [--sign "Developer ID ..."] [--register]
#
# --universal builds a fat arm64+x86_64 binary (for distribution).
# Without --sign, an ad-hoc signature (-) is applied, which is enough to run and to
# register as a default browser.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_NAME="DefaultBrowserRouter"
CONFIG="debug"
SIGN_IDENTITY="-"          # ad-hoc by default
REGISTER=0
SWIFT_FLAGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --release)   CONFIG="release"; shift ;;
    --universal) SWIFT_FLAGS+=(--arch arm64 --arch x86_64); shift ;;
    --sign)      SIGN_IDENTITY="$2"; shift 2 ;;
    --register)  REGISTER=1; shift ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

echo ">> Building ($CONFIG)…"
swift build -c "$CONFIG" ${SWIFT_FLAGS[@]+"${SWIFT_FLAGS[@]}"}

BIN_PATH="$(swift build -c "$CONFIG" ${SWIFT_FLAGS[@]+"${SWIFT_FLAGS[@]}"} --show-bin-path)/$APP_NAME"
APP_DIR="$ROOT/build/$APP_NAME.app"
MACOS_DIR="$APP_DIR/Contents/MacOS"
RES_DIR="$APP_DIR/Contents/Resources"

echo ">> Assembling ${APP_DIR}…"
rm -rf "$APP_DIR"
mkdir -p "$MACOS_DIR" "$RES_DIR"
cp "$ROOT/Resources/Info.plist" "$APP_DIR/Contents/Info.plist"
cp "$BIN_PATH" "$MACOS_DIR/$APP_NAME"
chmod +x "$MACOS_DIR/$APP_NAME"
cp "$ROOT/Resources/AppIcon.icns" "$RES_DIR/AppIcon.icns"

echo ">> Codesigning with identity: $SIGN_IDENTITY"
codesign --force --sign "$SIGN_IDENTITY" --timestamp=none "$APP_DIR"
codesign --verify --verbose "$APP_DIR"

echo ">> Built: $APP_DIR"

if [[ "$REGISTER" -eq 1 ]]; then
  LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"
  echo ">> Registering with LaunchServices…"
  "$LSREGISTER" -f "$APP_DIR"
  echo ">> Registered. Now run '$MACOS_DIR/$APP_NAME --set-default' or pick it in"
  echo "   System Settings → Desktop & Dock → Default web browser."
fi
