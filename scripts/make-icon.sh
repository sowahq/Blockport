#!/bin/sh
set -eu

export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
cd "$(dirname "$0")/.."

work="$(mktemp -d)"
trap 'rm -rf "$work"' EXIT
iconset="$work/AppIcon.iconset"
mkdir -p "$iconset" Resources

swift scripts/render-icon.swift "$work/icon-1024.png"
for size in 16 32 128 256 512; do
    sips -z "$size" "$size" "$work/icon-1024.png" --out "$iconset/icon_${size}x${size}.png" >/dev/null
    double=$((size * 2))
    sips -z "$double" "$double" "$work/icon-1024.png" --out "$iconset/icon_${size}x${size}@2x.png" >/dev/null
done
iconutil -c icns "$iconset" -o Resources/AppIcon.icns
cp "$work/icon-1024.png" Resources/AppIcon-1024.png
echo "$PWD/Resources/AppIcon.icns"
