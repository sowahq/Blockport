#!/bin/sh
set -eu

product="${1:-BlockportRuntime}"
configuration="${2:-release}"
export DEVELOPER_DIR="${DEVELOPER_DIR:-/Applications/Xcode.app/Contents/Developer}"
triple="arm64-apple-ios18.0-macabi"
ios_support="$(xcrun --sdk macosx --show-sdk-path)/System/iOSSupport"

cd "$(dirname "$0")/.."
swift build \
    --configuration "$configuration" \
    --product "$product" \
    --triple "$triple" \
    -Xswiftc -Fsystem -Xswiftc "$ios_support/System/Library/Frameworks" \
    -Xswiftc -I -Xswiftc "$ios_support/usr/lib/swift" \
    -Xlinker -F -Xlinker "$ios_support/System/Library/Frameworks" \
    -Xlinker -L -Xlinker "$ios_support/usr/lib/swift"

swift build --configuration "$configuration" --triple "$triple" --show-bin-path
