# Publishing Portage Display updates

Increment both the app version and build number, then run `scripts/package.sh` and `scripts/sign-update.sh` on the release Mac. The signing script uses the `portage-display` key in the login Keychain and creates `appcast.xml` for the versioned GitHub release asset. Publish the exact ZIP and checksum under that tag, then publish the feed on `main`. Never replace a released archive with different bytes. The signing key must remain private and available for future releases; never commit or log it. Fork maintainers must generate their own key with Sparkle's `generate_keys --account <account>`, replace `SUPublicEDKey` and `SUFeedURL`, and change the signing script's account and download URL.


The public download is currently ad-hoc signed and not Apple-notarized. Sparkle archive signing verifies update integrity; it does not provide Developer ID identity or Apple notarization. Do not describe an archive as notarized unless it has actually passed Apple’s notarization process.
