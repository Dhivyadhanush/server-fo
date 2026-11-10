#!/bin/bash
# Builds S-Info.app without an Xcode project: one swiftc call per arch, lipo,
# then a hand-written Info.plist and an ad-hoc signature.
set -euo pipefail
cd "$(dirname "$0")"

APP="build/S-Info.app"
VERSION="${VERSION:-1.0.2}"
BUILD="${BUILD:-1}"
# ARCHS="arm64 x86_64" produces a universal binary; default is this machine.
ARCHS="${ARCHS:-$(uname -m)}"
rm -rf build
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"

SLICES=()
# Command Line Tools on macOS 27 ship no SwiftUIMacros plugin, so @State fails
# to expand. Prefer the active toolchain's plugins, fall back to Xcode's.
DEVELOPER="$(xcode-select -p)"
PLUGIN_PATH=""
for candidate in \
  "$DEVELOPER/Toolchains/XcodeDefault.xctoolchain/usr/lib/swift/host/plugins" \
  "$DEVELOPER/Platforms/MacOSX.platform/Developer/usr/lib/swift/host/plugins" \
  /Applications/Xcode*.app/Contents/Developer/Platforms/MacOSX.platform/Developer/usr/lib/swift/host/plugins; do
  if [ -f "$candidate/libSwiftUIMacros.dylib" ]; then
    PLUGIN_PATH="$candidate"
    break
  fi
done
PLUGIN_ARGS=()
if [ -n "$PLUGIN_PATH" ]; then
  PLUGIN_ARGS=(-plugin-path "$PLUGIN_PATH")
fi

for arch in $ARCHS; do
  swiftc -O -parse-as-library \
    -target "$arch-apple-macos14.0" \
    "${PLUGIN_ARGS[@]}" \
    Sources/*.swift \
    -lsqlite3 \
    -o "build/SInfo-$arch"
  SLICES+=("build/SInfo-$arch")
done
lipo -create "${SLICES[@]}" -output "$APP/Contents/MacOS/SInfo"

cp Resources/AppIcon.icns "$APP/Contents/Resources/AppIcon.icns"
cp Resources/MenuBarIcon.png "$APP/Contents/Resources/MenuBarIcon.png"
cp Resources/MenuBarIcon@2x.png "$APP/Contents/Resources/MenuBarIcon@2x.png"

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleIdentifier</key><string>dev.dhanuz.s-info</string>
  <key>CFBundleName</key><string>S-Info</string>
  <key>CFBundleDisplayName</key><string>S-Info</string>
  <key>CFBundleExecutable</key><string>SInfo</string>
  <key>CFBundleIconFile</key><string>AppIcon</string>
  <key>CFBundlePackageType</key><string>APPL</string>
  <key>CFBundleShortVersionString</key><string>${VERSION}</string>
  <key>CFBundleVersion</key><string>${BUILD}</string>
  <key>LSMinimumSystemVersion</key><string>14.0</string>
  <key>LSApplicationCategoryType</key><string>public.app-category.developer-tools</string>
  <key>LSUIElement</key><true/>
  <key>NSHighResolutionCapable</key><true/>
  <key>NSHumanReadableCopyright</key><string>MIT licensed. S-Info shows one server's applications.</string>
</dict>
</plist>
PLIST

codesign --force --sign - "$APP" 2>/dev/null
echo "Built $APP $VERSION"
echo "Run: open $PWD/$APP"
echo "Test: $APP/Contents/MacOS/SInfo --selftest"
