#!/bin/sh
set -eu

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
cd "$(dirname "$0")/.."

runtime_dir="$(scripts/build-catalyst.sh BlockportRuntime release | tail -1)"
swift build --configuration release --product BlockportLauncher
launcher_dir="$(swift build --configuration release --show-bin-path)"

app="dist/Blockport.app"
rm -rf "$app"
mkdir -p "$app/Contents/MacOS" "$app/Contents/Resources"
cp "$launcher_dir/BlockportLauncher" "$app/Contents/MacOS/Blockport"
cp "$runtime_dir/libBlockportRuntime.dylib" "$app/Contents/Resources/"
cp -R Localization/*.lproj "$app/Contents/Resources/"
cp Resources/AppIcon.icns "$app/Contents/Resources/"

cat > "$app/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleDevelopmentRegion</key><string>en</string>
    <key>CFBundleLocalizations</key><array><string>en</string><string>fr</string><string>de</string><string>es</string></array>
    <key>CFBundleExecutable</key><string>Blockport</string>
    <key>CFBundleIconFile</key><string>AppIcon</string>
    <key>CFBundleIdentifier</key><string>dev.blockport.launcher</string>
    <key>CFBundleName</key><string>Blockport</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.1.0</string>
    <key>CFBundleVersion</key><string>1</string>
    <key>LSMinimumSystemVersion</key><string>15.0</string>
    <key>LSApplicationCategoryType</key><string>public.app-category.games</string>
    <key>NSHighResolutionCapable</key><true/>
</dict>
</plist>
PLIST

codesign --force --sign - --timestamp=none "$app/Contents/Resources/libBlockportRuntime.dylib"
codesign --force --sign - --timestamp=none "$app"
codesign --verify --deep "$app"
echo "$PWD/$app"
