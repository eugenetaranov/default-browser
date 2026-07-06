#!/usr/bin/env bash
#
# Generate Resources/AppIcon.icns from the SF Symbol "link" glyph.
# Requires macOS (swift, sips, iconutil). Re-run only when changing the icon.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TMP="$(mktemp -d)"
trap 'rm -rf "$TMP"' EXIT

ICONSET="$TMP/AppIcon.iconset"
MASTER="$TMP/icon_1024.png"
mkdir -p "$ICONSET"

echo ">> Rendering master icon…"
swift "$ROOT/scripts/make-app-icon.swift" "$MASTER"

# iconset filename -> pixel size
declare -a variants=(
  "icon_16x16.png 16"
  "icon_16x16@2x.png 32"
  "icon_32x32.png 32"
  "icon_32x32@2x.png 64"
  "icon_128x128.png 128"
  "icon_128x128@2x.png 256"
  "icon_256x256.png 256"
  "icon_256x256@2x.png 512"
  "icon_512x512.png 512"
  "icon_512x512@2x.png 1024"
)
echo ">> Scaling variants…"
for v in "${variants[@]}"; do
  name="${v% *}"; px="${v##* }"
  sips -z "$px" "$px" "$MASTER" --out "$ICONSET/$name" >/dev/null
done

echo ">> Building icns…"
iconutil -c icns "$ICONSET" -o "$ROOT/Resources/AppIcon.icns"
echo ">> Wrote Resources/AppIcon.icns"
