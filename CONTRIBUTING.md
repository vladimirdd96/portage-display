# Contributing

Open an issue describing the problem or a pull request with a focused change. Keep the native macOS interface accessible and lightweight. Prefer standard AppKit/SwiftUI controls and semantic colors; avoid continuous polling.

Build using `scripts/package.sh` and run the hardware-mocked test command in README.md. Tests must not change real monitor inputs or display settings. Hardware validation should be opt-in and record the Mac, monitor, connection, and macOS version without serial numbers.

Preserve the MIT license and third-party notices. Do not submit proprietary app code, extracted binaries, signing credentials, or personal preferences. Compatibility claims should distinguish advertised monitor inputs from confirmed live signals.
