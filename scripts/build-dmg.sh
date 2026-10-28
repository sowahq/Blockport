#!/bin/sh
set -eu

cd "$(dirname "$0")/.."
version="${BLOCKPORT_VERSION:-0.1.0}"
app="$(BLOCKPORT_VERSION="$version" scripts/build-app.sh | tail -1)"

staging="$(mktemp -d)"
trap 'rm -rf "$staging"' EXIT
cp -R "$app" "$staging/"
ln -s /Applications "$staging/Applications"

dmg="dist/Blockport-$version.dmg"
rm -f "$dmg"
hdiutil create -volname "Blockport" -srcfolder "$staging" -format UDZO -ov "$dmg" >/dev/null
(cd dist && shasum -a 256 "Blockport-$version.dmg" > SHA256SUMS)
echo "$PWD/$dmg"
