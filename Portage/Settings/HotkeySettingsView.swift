import KeyboardShortcuts
import SwiftUI

struct HotkeySettingsView: View {
    let presetStore: PresetStore
    let monitorStore: MonitorStore

    var body: some View {
        Form {
            Section {
                Text(
                    "Record a key combination beside an action. Shortcuts work while you use other apps; reusing one moves it to the new action."
                )
                .font(.callout).foregroundStyle(.secondary)
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
                        DisclosureGroup("Individual Input Shortcuts") {
                            ForEach(monitor.inputMappings) { input in
                                HStack {
                                    Label(input.label, systemImage: "arrow.right.to.line")
                                    Spacer()
                                    KeyboardShortcuts.Recorder(for: .inputSource(monitor.edidUUID, input.ddcValue)) {
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
                    KeyboardShortcuts.Recorder(for: .togglePanel) { shortcut in
                        ShortcutAssignment.move(
                            shortcut, to: .togglePanel,
                            among: ShortcutAssignment.names(monitors: monitorStore, presets: presetStore))
                    }
                }
            }

            Section("Presets") {
                if presetStore.presets.isEmpty {
                    Text("No presets configured")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(presetStore.presets) { preset in
                        if let hotkeyName = preset.hotkeyName {
                            HStack {
                                Text(preset.name)
                                Spacer()
                                KeyboardShortcuts.Recorder(for: KeyboardShortcuts.Name(hotkeyName)) { shortcut in
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
