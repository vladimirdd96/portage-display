import KeyboardShortcuts
import SwiftUI

struct PresetSettingsView: View {
    let presetStore: PresetStore
    let monitorStore: MonitorStore
    @AppStorage("settings.selectedPresetID") private var savedID = ""
    @State private var confirmDelete = false
    private var selected: Preset? { presetStore.presets.first { $0.id.uuidString == savedID } }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Picker("Preset", selection: $savedID) {
                    if presetStore.presets.isEmpty { Text("No Presets").tag("") }
                    ForEach(presetStore.presets) { Text($0.name).tag($0.id.uuidString) }
                }.disabled(presetStore.presets.isEmpty)
                Button {
                    let preset = Preset(name: "New Preset")
                    presetStore.addPreset(preset)
                    savedID = preset.id.uuidString
                } label: {
                    Label("New Preset", systemImage: "plus")
                }
                Menu {
                    Button("Delete Preset…", role: .destructive) { confirmDelete = true }.disabled(selected == nil)
                } label: {
                    Image(systemName: "ellipsis.circle")
                }
                .menuStyle(.borderlessButton).fixedSize().accessibilityLabel("Preset actions")
            }.padding(.horizontal, 24).padding(.vertical, 16)
            Divider()
            if let preset = selected {
                PresetDetailView(preset: preset, presetStore: presetStore, monitorStore: monitorStore)
                    .id(preset.id)
            } else {
                ContentUnavailableView(
                    "No Presets Yet", systemImage: "rectangle.stack",
                    description: Text("Create a preset to switch several displays together.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .onChange(of: presetStore.presets.map(\.id), initial: true) {
            if selected == nil { savedID = presetStore.presets.first?.id.uuidString ?? "" }
        }
        .alert("Delete this preset?", isPresented: $confirmDelete) {
            Button("Cancel", role: .cancel) {}
            Button("Delete Preset", role: .destructive) {
                if let preset = selected { presetStore.deletePreset(id: preset.id) }
            }
        } message: {
            Text("Its input assignments and shortcut will be removed.")
        }
    }
}

private struct PresetDetailView: View {
    let preset: Preset
    let presetStore: PresetStore
    let monitorStore: MonitorStore
    @State private var editedName: String = ""
    @FocusState private var nameFocused: Bool

    var body: some View {
        Form {
            Section("Preset") {
                TextField("Name", text: $editedName)
                    .focused($nameFocused)
                    .onAppear { editedName = preset.name }
                    .onSubmit(saveName)
                    .onChange(of: nameFocused) { if !nameFocused { saveName() } }
                    .onDisappear { saveName() }
            }

            Section("Keyboard Shortcut") {
                if let name = preset.hotkeyName {
                    HStack {
                        Text("Activate this preset")
                        Spacer()
                        ShortcutRecorder(for: KeyboardShortcuts.Name(name)) { shortcut in
                            ShortcutAssignment.move(
                                shortcut, to: KeyboardShortcuts.Name(name),
                                among: ShortcutAssignment.names(monitors: monitorStore, presets: presetStore))
                        }
                    }
                } else {
                    Button("Record a Shortcut…") {
                        var updated = preset
                        updated.hotkeyName = "preset-\(preset.id.uuidString)"
                        presetStore.updatePreset(updated)
                    }
                }
            }
            Section("Display Inputs") {
                if monitorStore.monitors.filter({ !$0.isBuiltIn }).isEmpty {
                    Text("Connect an external display to choose its input.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(monitorStore.monitors.filter { !$0.isBuiltIn }) { monitor in
                        let currentAssignment = preset.assignments.first(where: {
                            $0.monitorEdidUUID == monitor.edidUUID
                        })
                        LabeledContent(monitor.displayName) {
                            Picker(
                                "Input for \(monitor.displayName)",
                                selection: Binding(
                                    get: { currentAssignment?.targetInputValue ?? 0 },
                                    set: { newValue in
                                        var updated = preset
                                        updated.assignments.removeAll {
                                            $0.monitorEdidUUID == monitor.edidUUID
                                        }
                                        if newValue != 0,
                                            let mapping = monitor.inputMappings.first(where: {
                                                $0.ddcValue == newValue
                                            })
                                        {
                                            updated.assignments.append(
                                                PresetAssignment(
                                                    monitorEdidUUID: monitor.edidUUID,
                                                    targetInputValue: newValue,
                                                    targetInputLabel: mapping.label
                                                )
                                            )
                                        }
                                        presetStore.updatePreset(updated)
                                    }
                                )
                            ) {
                                Text("Leave Unchanged").tag(UInt16(0))
                                ForEach(monitor.inputMappings) { mapping in
                                    Text(mapping.label).tag(mapping.ddcValue)
                                }
                            }
                            .labelsHidden()
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
    }

    private func saveName() {
        let name = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !name.isEmpty, name != preset.name else { return }
        var updated = preset
        updated.name = name
        presetStore.updatePreset(updated)
    }
}
