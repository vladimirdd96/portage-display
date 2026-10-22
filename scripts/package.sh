#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
# Match the app target's version without requiring a built Info.plist.
version=$(sed -n 's/.*MARKETING_VERSION = \([^;]*\);/\1/p' Portage.xcodeproj/project.pbxproj | head -1)
mkdir -p dist
xcodebuild -project Portage.xcodeproj -scheme Portage -configuration Release \
  -destination 'generic/platform=macOS' -derivedDataPath build \
  ARCHS=arm64 CODE_SIGNING_ALLOWED=NO build
app="build/Build/Products/Release/Portage.app"
codesign --force --deep --sign - "$app"
codesign --verify --deep --strict "$app"
archive="Portage-Display-${version}.zip"
/usr/bin/ditto -c -k --sequesterRsrc --keepParent "$app" "dist/$archive"
(cd dist && shasum -a 256 "$archive" > SHA256SUMS.txt)
printf 'Created dist/%s and dist/SHA256SUMS.txt\n' "$archive"
