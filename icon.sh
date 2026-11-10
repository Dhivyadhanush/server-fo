#!/bin/bash
# Regenerates Resources/AppIcon.icns, the menu bar glyphs and docs/icon.png.
# Run after changing Resources/AppIcon-source.png or the glyph drawing code.
set -euo pipefail
cd "$(dirname "$0")"

rm -rf build/AppIcon.iconset
swift Resources/icon.swift build/AppIcon.iconset
iconutil -c icns build/AppIcon.iconset -o Resources/AppIcon.icns
echo "Wrote Resources/AppIcon.icns, MenuBarIcon pngs and docs/icon.png"
