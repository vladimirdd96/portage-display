import SwiftUI

struct MonitorSettingsView: View {
    @Bindable var monitorStore: MonitorStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("settings.selectedMonitorID") private var selectedMonitorID = ""

    var body: some View {
        VStack(spacing: 0) {
            if monitorStore.monitors.isEmpty {
                ContentUnavailableView(
                    "No Displays Detected", systemImage: "display",
                    description: Text("Connect a display or refresh to try again."))
            } else {
                ScrollViewReader { proxy in
                    ScrollView(.horizontal) {
                        HStack(spacing: 12) {
                            ForEach(monitorStore.monitors) { monitor in
                                displayButton(monitor).id(monitor.id)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical, 16)
                        .frame(minWidth: 0)
                    }
                    .scrollIndicators(.automatic)
                    .onAppear { proxy.scrollTo(selectedMonitorID, anchor: .center) }
                    .onChange(of: selectedMonitorID) {
                        withAnimation(reduceMotion ? nil : .easeInOut(duration: 0.18)) {
                            proxy.scrollTo(selectedMonitorID, anchor: .center)
                        }
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .background(.bar)
                Divider()
                if let monitor = monitorStore.monitors.first(where: { $0.id == selectedMonitorID }) {
                    MonitorDetailView(monitor: monitor, monitorStore: monitorStore)
                        .id(monitor.id)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
        }
        .onChange(of: monitorStore.monitors.map(\.id), initial: true) {
            if !monitorStore.monitors.contains(where: { $0.id == selectedMonitorID }) {
                selectedMonitorID =
                    monitorStore.monitors.first(where: \.isBuiltIn)?.id ?? monitorStore.monitors.first?.id ?? ""
            }
        }
    }

    private func displayButton(_ monitor: MonitorConfig) -> some View {
        let selected = selectedMonitorID == monitor.id
        return Button {
            selectedMonitorID = monitor.id
        } label: {
            VStack(spacing: 8) {
                Image(systemName: monitor.isBuiltIn ? "laptopcomputer" : "display")
                    .font(.system(size: 38, weight: .light))
                    .foregroundStyle(selected ? Color.accentColor : Color.secondary)
                    .frame(height: 44)
                Text(monitor.displayName)
                    .font(.callout.weight(selected ? .semibold : .regular))
                    .lineLimit(1).truncationMode(.middle)
            }
            .frame(width: 148, height: 88)
            .padding(8)
            .background(selected ? Color.accentColor.opacity(0.08) : Color.clear, in: .rect(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12).strokeBorder(
                    selected ? Color.accentColor : Color.secondary.opacity(0.2), lineWidth: selected ? 2 : 1)
            }
            .contentShape(.rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .help(monitor.displayName)
        .accessibilityLabel("Select \(monitor.displayName)")
        .accessibilityValue(selected ? "Selected" : "")
    }
}

private struct MonitorDetailView: View {
    let monitor: MonitorConfig
    @Bindable var monitorStore: MonitorStore
    @State private var editedName = ""
    @FocusState private var nameFocused: Bool
    @State private var pane = Pane.picture
    private enum Pane: String, CaseIterable, Identifiable {
        case picture = "Picture"
        case inputs = "Inputs"
        case info = "Info"
        var id: Self { self }
    }
    private var preferences: FeaturePreferences { .shared }

    var body: some View {
        VStack(spacing: 0) {
            Picker("Display settings", selection: $pane) {
                ForEach(Pane.allCases.filter { !monitor.isBuiltIn || $0 != .inputs }) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented).labelsHidden().padding(.horizontal, 24).padding(.vertical, 12)
            Form {
                switch pane {
                case .picture: picture
                case .inputs:
                    if preferences.enabled(.inputs) {
                        Section("Switch Input") {
                            InputSourceControls(monitor: monitor, monitorStore: monitorStore)
                        }
                        Section {
                            Text("Set cycling order and keyboard shortcuts in Inputs & Shortcuts.").foregroundStyle(
                                .secondary)
                        }
                    } else {
                        Text("Input switching is turned off in Features.").foregroundStyle(.secondary)
                    }
                case .info: information
                }
            }.formStyle(.grouped)
        }
        .onAppear { editedName = monitor.displayName }
        .onChange(of: nameFocused) { if !nameFocused { saveName() } }
        .onDisappear { saveName() }
    }

    @ViewBuilder private var picture: some View {
        if preferences.enabled(.brightness) {
            Section("Brightness") { BrightnessControl(monitor: monitor, monitorStore: monitorStore) }
        }
        if preferences.enabled(.hardware), !(monitor.hardwareLevels ?? [:]).isEmpty || monitor.isMuted != nil {
            Section("Contrast & Audio") { HardwareControls(monitor: monitor, monitorStore: monitorStore) }
        }
        if let displayID = monitor.systemDisplayID {
            if preferences.enabled(.modes) {
                Section("Resolution & Refresh Rate") { DisplayModeControl(displayID: displayID) }
            }
            if preferences.enabled(.profiles) { Section("Color Profile") { ColorProfileControl(displayID: displayID) } }
        }
        if ![AppFeature.brightness, .hardware, .modes, .profiles].contains(where: { preferences.enabled($0) }) {
            Text("Picture controls are turned off in Features.").foregroundStyle(.secondary)
        }
    }

    @ViewBuilder private var information: some View {
        Section("Display") {
            TextField("Name", text: $editedName).focused($nameFocused).onSubmit(saveName)
            LabeledContent("Connection", value: monitor.isBuiltIn ? "Built-in" : "External")
            LabeledContent("Manufacturer", value: monitor.manufacturer)
            if let id = monitor.systemDisplayID {
                Button("Identify Display") { DisplayIdentifier.shared.show(displayID: id, name: monitor.displayName) }
            }
        }
        Section {
            DisclosureGroup("Technical Details") {
                if !monitor.alphanumericSerial.isEmpty {
                    LabeledContent("Serial Number", value: monitor.alphanumericSerial)
                }
                if let current = monitor.currentInputValue {
                    LabeledContent("Input Value", value: "\(current)")
                }
                ForEach(monitor.inputMappings) { mapping in
                    LabeledContent(mapping.label, value: "DDC \(mapping.ddcValue)")
                }
                if monitor.isBuiltIn {
                    Text("Input switching is not available for the built-in display.").foregroundStyle(.secondary)
                }
            }
        }
    }

    private func saveName() {
        let name = editedName.trimmingCharacters(in: .whitespacesAndNewlines)
        if !name.isEmpty, name != monitor.displayName {
            monitorStore.updateDisplayName(monitorID: monitor.id, name: name)
        }
    }
}
