#!/bin/bash
# Run after package.sh. The private signing key stays in the login Keychain.
set -euo pipefail
cd "$(dirname "$0")/.."
version=$(sed -n 's/.*MARKETING_VERSION = \([^;]*\);/\1/p' Portage.xcodeproj/project.pbxproj | head -1)
tools=build/SourcePackages/artifacts/sparkle/Sparkle/bin
archive="Portage-Display-${version}.zip"
test -f "dist/$archive"
staging=$(mktemp -d)
trap 'rm -rf "$staging"' EXIT
cp "dist/$archive" "$staging/"
"$tools/generate_appcast" --account portage-display --maximum-deltas 0 \
  --download-url-prefix "https://github.com/vladimirdd96/portage-display/releases/download/v${version}/" \
  --link https://github.com/vladimirdd96/portage-display "$staging"
cp "$staging/appcast.xml" appcast.xml
"$tools/sign_update" --account portage-display --verify "dist/$archive" \
  "$(python3 -c 'import xml.etree.ElementTree as E; print(E.parse("appcast.xml").find(".//enclosure").get("{http://www.andymatuschak.org/xml-namespaces/sparkle}edSignature"))')"
echo 'Signed update and generated appcast.xml. Publish the exact archive, then commit the feed.'
