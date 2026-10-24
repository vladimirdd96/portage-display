# Portage Display — macOS Monitor Input Switching & Brightness Control

**Portage Display is a free, open-source Mac menu bar app for switching external monitor inputs, controlling display brightness, and applying display presets with keyboard shortcuts.** Switch a shared monitor between HDMI, DisplayPort, or USB-C inputs reported by the display, without reaching for its on-screen menu.

Built in Swift with native AppKit and SwiftUI controls, Portage Display supports multiple monitors on **Apple silicon Macs running macOS 26.5 or later**. External monitor controls use **DDC/CI** and depend on the monitor and connection.

[Download the latest release](https://github.com/vladimirdd96/portage-display/releases/latest) · [Report a compatibility issue](https://github.com/vladimirdd96/portage-display/issues) · [Automation and agent reference](docs/AUTOMATION.md) · [MIT license](LICENSE)

## What can I do with Portage Display?

| Task | Available controls |
| --- | --- |
| Switch monitor inputs from a Mac | Select an external display input from the menu bar; assign a shortcut to an individual input |
| Cycle HDMI and DisplayPort inputs | Use one keyboard shortcut to cycle an ordered selection of configured inputs |
| Adjust monitor brightness | Drag a slider directly beneath each display name, even with its other controls collapsed |
| Save work, gaming, or evening setups | Apply optional input, brightness, monitor color, contrast, and audio settings to one or more displays |
| Control monitor colors | Use reported monitor color presets and RGB gain controls where DDC supports them |
| Configure resolution and refresh rate | Browse modes grouped by Hz; changes revert after 15 seconds unless confirmed |
| Customize the menu bar | Choose visible displays and features, remember expanded sections, and select System, Light, or Dark appearance |
| Automate display changes | Use keyboard shortcuts, Apple Shortcuts/App Intents, AppleScript, or `portagedisplay://` URLs |

Contrast, speaker volume, mute, and color controls appear only where supported. macOS ColorSync/ICC profiles remain an optional advanced control. Portage uses no web runtime or continuous monitor polling; interfaces are created on demand and released when closed.

## Download and install on macOS

1. Download the **`Portage-Display-<version>.zip`** asset from [GitHub Releases](https://github.com/vladimirdd96/portage-display/releases/latest). Choose the app archive, not GitHub’s source-code archive.
2. Unzip it and move **Portage.app** into **Applications**, or into your user’s **`~/Applications`** folder if appropriate for your Mac.
3. Open Portage and configure displays in Settings. Click its menu bar icon for everyday controls; right-click for Settings, refresh, and Quit.

**Requirements:** Apple silicon (M1 or newer), macOS **26.5+**. Intel Macs, older macOS versions, Windows, and Linux are not supported by this app.

**Signing status:** release downloads are ad-hoc signed and **not Apple-notarized**. macOS may block the first launch. If you trust the source, follow [Apple’s per-app approval instructions](https://support.apple.com/en-au/102445). Managed work Macs may require IT approval. Do not disable Gatekeeper or device-management protections. A local source build is another option where policy permits it.

Release assets include a SHA-256 checksum file. To check the downloaded ZIP against it, place both files in the same folder and run:

```sh
shasum -a 256 -c SHA256SUMS.txt
```

### Update an installed copy

In **Settings → General → Updates**, choose **Check for Updates…** or enable optional automatic checks. Automatic checks are off by default, and installation remains your choice. Sparkle verifies signed update archives before installation; this is separate from Apple notarization.

Versions before 1.17 need one manual installation of a current release to get the updater.

## Monitor compatibility: DDC/CI, HDMI, DisplayPort, and USB-C

Portage discovers available controls from the connected monitor’s DDC/MCCS capabilities and successful reads. It does not require a large brand-specific database. This approach can support compatible monitors from different manufacturers, but **a brand name alone does not guarantee compatibility**.

| Display or connection | What to expect |
| --- | --- |
| MacBook built-in Retina display | Brightness and supported macOS display settings; no selectable video inputs |
| External monitor with DDC/CI enabled | Input switching, brightness, and other controls reported by that monitor |
| HDMI, DisplayPort, or USB-C display connection | Depends on the monitor, Mac, adapter, and whether the path passes DDC commands |
| Dock, adapter, or hardware KVM | May block or alter DDC communication; test the actual connection |
| Alienware AW3225QF | Capability discovery checked during development; this is not a blanket certification of every setting or connection |
| Other monitor brands and models | Capability-based support; real-device reports are welcome |

Enable **DDC/CI** in your monitor’s own on-screen settings. Compatible built-in HDMI paths using Apple’s MCDP29xx bridge are detected automatically. Private Apple display APIs are used for DDC and built-in brightness, so future macOS updates may affect compatibility.

**Important limitations:**

- An advertised input does not prove a powered-on computer is sending video. Automatic skipping of powered-off computers is not implemented; configure cycle membership manually.
- Some monitors stop accepting commands from the Mac after switching away from its input. Switching back with a Mac keyboard shortcut is therefore not guaranteed.
- Missing readback produces an unconfirmed-switch warning rather than a false success message. A monitor that disconnects DDC after switching can cause that warning even when the input changed.
- Proprietary manufacturer picture modes are not guessed or written. RGB controls may require a User/Custom mode on the monitor.
- Portage does not switch USB peripherals like a hardware KVM, create virtual displays, or unlock XDR brightness.

## Configure keyboard shortcuts and display presets

Open **Settings → Inputs & Shortcuts**:

- **One input:** always select a specific input on one external display.
- **Cycle inputs:** step through the inputs you selected, in order, using one shortcut.
- **Preset:** apply named settings to one or more displays together.

Choose combinations that do not conflict with macOS or other apps. Assigning an existing Portage shortcut to another Portage action moves that combination to the new action.

In **Settings → Presets**, create a preset and expand a display under **Appearance & Audio**. Enable only the settings it should change. The preset actions menu’s **Save Current Display Settings** captures current brightness and supported monitor color, contrast, and audio values without changing the display or adding an input switch.

Editing a preset only saves its configuration. Activate it from the menu, a shortcut, or automation to apply it. Appearance settings apply before input switches, since switching away may end DDC communication. A preset can partially apply if one control fails; errors are reported. Existing input-only presets remain compatible.

### Keep frequent controls within reach

Under **Settings → Menu Bar → Quick Access**:

- Keep brightness visible when displays are collapsed, or choose a compact menu.
- Turn off **Keep input buttons visible** to make Input Source collapsible.
- Show or hide Presets and advanced macOS color profiles.
- Enable **Show Display Info in the menu** when needed; it is off by default. Display information remains available under **Displays → Info**.

Choose **Remember My Layout** or **Start Collapsed** under the menu’s Layout settings. Display sections are directly accessible without an additional More Options layer, and clicking outside closes the menu.

## Monitor-native color controls and memory use

**Monitor Colors** uses standard MCCS color presets (`0x14`) and RGB gain (`0x16`, `0x18`, `0x1A`). Only reported preset values are offered, with standard names from [MCCS as documented by ddcutil](https://www.ddcutil.com/vcpinfo_output/). Color preset writes require monitor readback confirmation before reporting success.

macOS ICC profiles affect the Mac’s output rather than the monitor’s own picture settings. Custom profiles must also be installed on any other Mac using a preset that references them.

Disabling Monitor Color Controls skips those hardware reads and blocks writes. Disabled feature controls are not created in the menu or display settings. Advanced ICC lists load when their controls are opened. Saved preferences and compiled code still occupy some memory; disabled features cannot literally use zero RAM. No fixed memory or CPU limit is promised.

## Automation for scripts, Shortcuts, and AI agents

Portage exposes Apple Shortcuts/App Intents, AppleScript, and a URL scheme. It is a native desktop app, not an MCP server or an HTTP service. See the [automation reference](docs/AUTOMATION.md) for routes, source entry points, and hardware-action boundaries. A compact documentation index is available in [llms.txt](llms.txt).

Open Settings or the floating controls without changing monitor settings:

```sh
open 'portagedisplay://settings'
open 'portagedisplay://panel'
```

Apply an existing preset or switch an input **only when you intend to change the display**:

```sh
open 'portagedisplay://activate-preset?name=Work'
open 'portagedisplay://switch-input?monitor=Dell&input=HDMI-1'
```

Names must match your configuration; URL-encode spaces and special characters. Input actions can immediately move the monitor away from the Mac. Bundle identifier: `com.github.vladimirdd96.PortageDisplay`.

## Build Portage Display from source

The supported build workflow requires **full Xcode** with a macOS SDK/toolchain compatible with this project’s macOS 26.5 deployment target. Command Line Tools alone cannot run the current Xcode project build. Swift Package Manager resolves pinned KeyboardShortcuts and Sparkle dependencies. A paid Apple Developer account is not required for a local ad-hoc build.

```sh
git clone https://github.com/vladimirdd96/portage-display.git
cd portage-display
./scripts/package.sh
```

The script builds an arm64 Release app at `build/Build/Products/Release/Portage.app`, ad-hoc signs it, verifies the signature, and creates the app ZIP and checksum in `dist/`. It does not install or launch the app or change display settings.

If multiple developer tool installations exist, select an already configured Xcode for this invocation without changing the global developer directory:

```sh
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer ./scripts/package.sh
```

Xcode installation, initial setup, license acceptance, and enterprise policies may still require IT assistance. A local build does not bypass company restrictions.

Run the hardware-mocked test suite:

```sh
xcodebuild -project Portage.xcodeproj -scheme Portage -configuration Debug \
  -destination 'platform=macOS' -derivedDataPath build-test \
  CODE_SIGNING_ALLOWED=NO test
```

For update signing, versioning, and distribution, see [Publishing updates](docs/RELEASING.md). No signing credentials are included in this repository.

## Frequently asked questions

### Is Portage Display a free BetterDisplay alternative?

It is an independent, MIT-licensed option for the overlapping tasks of monitor input switching, brightness, shortcuts, and display presets. It is **not a full BetterDisplay replacement** and is not affiliated with BetterDisplay or Apple. It contains no BetterDisplay binaries or extracted proprietary code.

### Can I switch HDMI inputs on a Mac with a keyboard shortcut?

Yes, when the external monitor and connection accept DDC/CI input commands. Assign a shortcut to a specific input or configure a cycle shortcut. This changes the monitor’s selected source; it does not create an additional HDMI output on the Mac.

### Why is Input Source not collapsible?

**Keep input buttons visible** is enabled by default. Turn it off in **Settings → Menu Bar → Quick Access** to use the collapsible section.

### Does it automatically detect whether another PC is on?

No. Monitor capability reports describe supported inputs, not reliable live signal status. Choose which inputs participate in cycling manually.

### Why does macOS say it cannot verify the app is free of malware?

The distributed app is not Apple-notarized. That warning alone is not a malware detection. Follow Apple’s approval guidance where permitted, build from source where supported, or ask your organization’s IT team to review it.

## Contribute monitor compatibility reports

[Open an issue](https://github.com/vladimirdd96/portage-display/issues) with your Mac model, macOS version, app version, monitor brand/model, cable or dock arrangement, and the control that fails. State whether DDC/CI is enabled. Do not include monitor serial numbers, credentials, or other personal data.

Compatibility reports, documentation improvements, and focused fixes are welcome. Test hardware writes with mocks unless you deliberately intend to alter a real display.

## License and acknowledgements

[MIT license](LICENSE). Portage Display is an independent fork of [Portage by eve0415](https://github.com/eve0415/Portage); original copyright © 2025 eve0415 is preserved. Credits and license texts for KeyboardShortcuts, AppleSiliconDDC, Sparkle, and the m1ddc HDMI routing reference are in [ThirdPartyNotices.txt](Portage/ThirdPartyNotices.txt) and the app’s About section.
