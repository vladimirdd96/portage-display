# Portage Display automation and agent reference

Portage Display is an MIT-licensed native macOS menu bar app for DDC/CI monitor input switching, brightness, monitor colors, and multi-display presets. Requires Apple silicon and macOS 26.5+. The current source build requires full Xcode. Downloads are not Apple-notarized.

## Interfaces

| Interface | Entry point |
| --- | --- |
| URL scheme | `portagedisplay://` |
| Apple Shortcuts / App Intents | `Portage/Intents/` |
| AppleScript dictionary and commands | `Portage/AppleScript/Portage.sdef`, `Portage/AppleScript/` |
| Keyboard shortcut configuration | Settings → Inputs & Shortcuts; preset shortcuts also appear in Settings → Presets |
| Source repository | https://github.com/vladimirdd96/portage-display |

There is no documented standalone CLI, HTTP API, or MCP server. A shell can invoke the URL scheme through macOS `open`; URLs open UI or perform actions and do not return structured query results to stdout.

## URL routes

| Route | Parameters | Effect |
| --- | --- | --- |
| `settings` | None | Open Settings and refresh monitor state |
| `panel` | None | Open floating display controls and refresh state |
| `list-monitors` | None | Open the controls UI; not a JSON response |
| `list-presets` | None | Open the controls UI; not a JSON response |
| `activate-preset` | `name` or `id` | Apply an existing preset; can change several display settings |
| `switch-input` | `monitor`, `input` | Switch a configured external monitor input |

Use existing configured names or identifiers. URL-encode parameter values. Check the source resolver in `Portage/Automation/AutomationService.swift` for matching behavior; do not assume an arbitrary monitor or input exists.

## Source map

- `Portage/URLScheme/URLRouter.swift`: route parsing.
- `Portage/AppDelegate.swift`: URL dispatch and Settings entry point.
- `Portage/Automation/`: action resolution and results.
- `Portage/Preset/`: persisted optional display settings and preset activation.
- `Portage/Monitor/MonitorStore.swift`: monitor state and feature-gated writes.
- `Portage/DDC/`: capabilities, transport, and mock service.
- `PortageTests/`: hardware-mocked tests.
- `scripts/package.sh`: local Release build, ad-hoc signing, and packaging.
- `appcast.xml`: Sparkle update feed; not an automation endpoint.

## Hardware actions and limits

Opening Settings or controls reads hardware state. Switching inputs and activating presets can immediately change a real monitor and interrupt the user's view. A preset can include brightness, RGB gain, monitor color presets, contrast, audio, and optional ICC profiles in addition to inputs. Editing a preset does not apply it.

Monitor capabilities do not establish whether a connected PC is powered on. Commands may become unavailable after switching away from the Mac. Model support depends on reported DDC capabilities and the connection; no universal compatibility is claimed. Use mocks for automated write tests. Respect managed-device policy; the repository does not provide an enterprise-policy bypass.

For installation, configuration, and limitations, start with the [README](../README.md).
