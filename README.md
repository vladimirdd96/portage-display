# Portage Display

A lightweight, native macOS menu-bar app for display inputs, keyboard shortcuts, and brightness. This is an independent MIT-licensed fork of [Portage by eve0415](https://github.com/eve0415/Portage), extended with per-display controls and a customizable interface. It is not affiliated with BetterDisplay or Apple.

## Download and install

Download **Portage-Display-1.14.zip** from [Releases](https://github.com/vladimirdd96/portage-display/releases/latest), unzip it, and drag **Portage.app** into **Applications**. Open it to configure displays and shortcuts; the menu-bar icon provides everyday controls. Right-click the icon for Settings, refresh, and Quit.

**Requires an Apple silicon Mac (M1 or newer) and macOS 26.5 or later.** Intel Macs and earlier macOS versions are not supported by this release.

The initial release is ad-hoc signed, **not notarized**. macOS may block its first launch. If you trust the download, follow [Apple’s per-app approval instructions](https://support.apple.com/en-au/102445) in System Settings → Privacy & Security after attempting to open it. Do not disable Gatekeeper globally. Building from source is also available below.

## Features

- Discover multiple displays when opening controls and after display connection changes.
- Switch external monitor inputs directly, assign shortcuts to individual inputs, or cycle an ordered selection with one shortcut.
- Adjust built-in display brightness and supported external DDC brightness, contrast, and speaker volume.
- Choose which displays and features appear in the menu. Expand entire rows and optionally remember their state.
- Use native Settings with a horizontal display selector, input presets, and separate feature and menu customization controls.
- Choose System, Light, or Dark appearance with native macOS materials.
- Group display modes by refresh rate; applying a mode includes a 15-second automatic rollback unless confirmed.
- Select compatible ColorSync profiles and identify displays.
- Run input presets through Shortcuts, AppleScript, and URL actions.
- Optional launch at login. Interfaces are created on demand and released when closed; no continuous monitor polling or web runtime.

## Monitor compatibility

External controls require DDC/CI support and a compatible connection. Enable DDC/CI in your monitor’s settings if needed. Docks, adapters, KVMs, and some monitors can prevent DDC communication. Available controls vary by display.

The input list comes from monitor capabilities and user configuration. **An advertised input does not prove a powered-on computer is sending a signal.** Automatic skipping of powered-off computers is not implemented. Configure cycle membership manually. After switching away from the Mac’s input, some monitors stop responding to the Mac; a keyboard shortcut cannot guarantee switching back in that case.

Built-in displays do not have selectable video inputs. Unsupported controls are hidden or unavailable. Private Apple display APIs are used for DDC and built-in brightness; future macOS updates may affect compatibility. This is not a full BetterDisplay replacement (for example, it does not create virtual displays or provide XDR brightness).

## Build and verify

Install Xcode with the macOS 26.5 SDK or newer, select it with `xcode-select`, and open `Portage.xcodeproj`. Swift Package Manager resolves the pinned KeyboardShortcuts dependency. No paid signing account is required for a local ad-hoc build.

```sh
git clone https://github.com/vladimirdd96/portage-display.git
cd portage-display
./scripts/package.sh
```

The script builds an arm64 Release app, ad-hoc signs it, verifies its signature, and creates a ZIP and SHA-256 checksum in `dist/`. It does not install or launch the app, or change display settings.

Run the hardware-mocked test suite:

```sh
xcodebuild -project Portage.xcodeproj -scheme Portage -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath build-test \
  CODE_SIGNING_ALLOWED=NO test
```

For Developer ID distribution, sign with your own Developer ID Application identity and notarize with Apple before publishing. No certificates or credentials are included in this repository.

## Automation

This fork uses its own bundle identifier, `com.github.vladimirdd96.PortageDisplay`, and the `portagedisplay` URL scheme to avoid conflicts with upstream Portage. Preferences are stored separately. Examples:

```sh
open 'portagedisplay://settings'
open 'portagedisplay://panel'
open 'portagedisplay://activate-preset?name=Work'
open 'portagedisplay://switch-input?monitor=Dell&input=HDMI-1'
```

Input names and monitor names must match your configuration; URL-encode spaces. Input actions can immediately move your monitor away from the Mac.

## License and credits

[MIT](LICENSE). Original Portage copyright © 2025 eve0415, preserved in this fork. Additional credits and license texts for KeyboardShortcuts and AppleSiliconDDC are in [ThirdPartyNotices.txt](Portage/ThirdPartyNotices.txt) and the app’s About section. This project contains no BetterDisplay binaries, extracted proprietary code, personal preferences, or signing credentials.

## Feedback

Please include your Mac model, macOS version, monitor model, cable/dock arrangement, and the control that fails when [opening an issue](https://github.com/vladimirdd96/portage-display/issues). Do not include monitor serial numbers, credentials, or other personal data.
