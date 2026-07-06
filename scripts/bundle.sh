#!/usr/bin/env bash
#
# Build DefaultBrowserRouter and assemble a codesigned .app bundle that macOS can
# register as a default web browser.
#
# Usage:
#   scripts/bundle.sh [--release] [--universal] [--version X.Y.Z] \
#                     [--sign "Developer ID ..."] [--register]
#
# --universal builds a fat arm64+x86_64 binary (for distribution).
# --version stamps the marketing version into the bundle's Info.plist. If omitted, it is
#   derived from `git describe --tags` (falling back to 0.0.0-dev).
# Without --sign, an ad-hoc signature (-) is applied, which is enough to run and to
# register as a default browser.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"

APP_NAME="DefaultBrowserRouter"
CONFIG="debug"
SIGN_IDENTITY="-"          # ad-hoc by default
REGISTER=0
VERSION=""
SWIFT_FLAGS=()

while [[ $# -gt 0 ]]; do
  case "$1" in
    --release)   CONFIG="release"; shift ;;
    --universal) SWIFT_FLAGS+=(--arch arm64 --arch x86_64); shift ;;
    --version)   VERSION="$2"; shift 2 ;;
    --sign)      SIGN_IDENTITY="$2"; shift 2 ;;
    --register)  REGISTER=1; shift ;;
    *) echo "Unknown arg: $1" >&2; exit 1 ;;
  esac
done

# Resolve version: explicit flag > git describe > dev fallback. Strip leading "v".
if [[ -z "$VERSION" ]]; then
  VERSION="$(git describe --tags --always 2>/dev/null || true)"
  VERSION="${VERSION#v}"
  [[ -z "$VERSION" ]] && VERSION="0.0.0-dev"
fi
BUILD_NUMBER="$(git rev-list --count HEAD 2>/dev/null || echo 1)"

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

echo ">> Stamping version $VERSION ($BUILD_NUMBER)…"
PB=/usr/libexec/PlistBuddy
"$PB" -c "Set :CFBundleShortVersionString $VERSION" "$APP_DIR/Contents/Info.plist"
"$PB" -c "Set :CFBundleVersion $BUILD_NUMBER" "$APP_DIR/Contents/Info.plist"

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
