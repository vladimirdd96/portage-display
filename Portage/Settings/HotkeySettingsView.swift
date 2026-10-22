import KeyboardShortcuts
import SwiftUI

struct HotkeySettingsView: View {
    let presetStore: PresetStore
    let monitorStore: MonitorStore

    var body: some View {
        Form {
            Section {
                Text("**One input:** Always switch one display to a specific input, such as HDMI 2.")
                Text("**Cycle inputs:** Use one shortcut to step through your chosen inputs in order.")
                Text("**Preset:** Apply saved inputs, brightness, and color settings to one or more displays together.")
            } header: {
                Text("Ways to Switch")
            } footer: {
                Text("Click a shortcut field, then press your key combination. Shortcuts work in other apps. Reusing a combination moves it to the new action.")
            }
            if monitorStore.monitors.filter({ !$0.isBuiltIn }).isEmpty {
                Section {
                    Text("Connect an external monitor to configure input shortcuts.")
                        .foregroundStyle(.secondary)
                }
            }
            if FeaturePreferences.shared.enabled(.inputs) {
                ForEach(monitorStore.monitors.filter { !$0.isBuiltIn }) { monitor in
                    Section(monitor.displayName) {
                        CycleInputSettings(monitor: monitor, monitorStore: monitorStore, presetStore: presetStore)
                        DisclosureGroup("Switch to One Input") {
                            Text("Each shortcut always selects the input shown below on this display.")
                                .font(.caption).foregroundStyle(.secondary)
                            ForEach(monitor.inputMappings) { input in
                                HStack {
                                    Label(input.label, systemImage: "arrow.right.to.line")
                                    Spacer()
                                    ShortcutRecorder(for: .inputSource(monitor.edidUUID, input.ddcValue)) {
                                        shortcut in
                                        ShortcutAssignment.move(
                                            shortcut, to: .inputSource(monitor.edidUUID, input.ddcValue),
                                            among: ShortcutAssignment.names(
                                                monitors: monitorStore, presets: presetStore))
                                    }
                                }
                            }
                        }
                    }
                }
            }
            Section("Floating Controls") {
                HStack {
                    Text("Show or Hide Controls")
                    Spacer()
                    ShortcutRecorder(for: .togglePanel) { shortcut in
                        ShortcutAssignment.move(
                            shortcut, to: .togglePanel,
                            among: ShortcutAssignment.names(monitors: monitorStore, presets: presetStore))
                    }
                }
            }

            Section("Preset Shortcuts") {
                if monitorStore.monitors.filter({ !$0.isBuiltIn }).count == 1 {
                    Text("With one display, a preset containing one input performs the same switch as an individual input shortcut. Presets can also include brightness, color profiles, and more displays.")
                        .font(.callout).foregroundStyle(.secondary)
                } else {
                    Text("Each shortcut applies all display input choices saved in that preset. Choose those inputs in Presets settings.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                if presetStore.presets.isEmpty {
                    Text("No presets configured")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(presetStore.presets) { preset in
                        if let hotkeyName = preset.hotkeyName {
                            HStack {
                                Text(preset.name)
                                Spacer()
                                ShortcutRecorder(for: KeyboardShortcuts.Name(hotkeyName)) { shortcut in
                                    ShortcutAssignment.move(
                                        shortcut, to: KeyboardShortcuts.Name(hotkeyName),
                                        among: ShortcutAssignment.names(monitors: monitorStore, presets: presetStore))
                                }
                            }
                        } else {
                            HStack {
                                Text(preset.name)
                                Spacer()
                                Button("Record Shortcut…") {
                                    var updated = preset
                                    updated.hotkeyName = "preset-\(preset.id.uuidString)"
                                    presetStore.updatePreset(updated)
                                }
                            }
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }
}
