import SwiftUI

struct MenuSettingsView: View {
    private let preferences = FeaturePreferences.shared
    let monitorStore: MonitorStore
    var onOpenFeatures: () -> Void = {}
    @State private var category = Category.displays
    private enum Category: String, CaseIterable, Identifiable {
        case displays = "Displays"
        case layout = "Layout"
        case quickAccess = "Quick Access"
        var id: Self { self }
    }
    @AppStorage("menu.displayScope") private var displayScope = MenuDisplayScope.all.rawValue
    @AppStorage("menu.hiddenDisplayIDs") private var hiddenDisplayData = Data()

    private var scope: MenuDisplayScope { MenuDisplayScope(rawValue: displayScope) ?? .all }
    private var hiddenIDs: Set<String> {
        Set((try? JSONDecoder().decode([String].self, from: hiddenDisplayData)) ?? [])
    }
    private var knownMonitors: [MonitorConfig] {
        monitorStore.configuredMonitors.sorted {
            if $0.isBuiltIn != $1.isBuiltIn { return $0.isBuiltIn }
            return $0.displayName.localizedStandardCompare($1.displayName) == .orderedAscending
        }
    }

    private func visibility(for monitor: MonitorConfig) -> Binding<Bool> {
        Binding(
            get: { !hiddenIDs.contains(monitor.id) },
            set: { visible in
                var ids = hiddenIDs
                if visible { ids.remove(monitor.id) } else { ids.insert(monitor.id) }
                hiddenDisplayData = (try? JSONEncoder().encode(Array(ids).sorted())) ?? Data()
            })
    }

    @AppStorage("menu.singleExpandedDisplay") private var singleExpanded = true
    @AppStorage("menu.rememberLayout") private var rememberLayout = true
    @AppStorage("menu.expandedDisplayIDs") private var expandedData = Data()
    @AppStorage("menu.sectionStates") private var sectionData = Data()
    @AppStorage("menu.presetsExpanded") private var presetsExpanded = false
    @AppStorage("menu.singleExpandedFeature") private var singleFeature = false
    @AppStorage("menu.showDisplayInfo") private var showDisplayInfo = false
    @AppStorage("menu.brightnessAlwaysVisible") private var brightnessAlwaysVisible = true
    @AppStorage("menu.inputsAlwaysVisible") private var inputsAlwaysVisible = true

    var body: some View {
        VStack(spacing: 0) {
            Picker("Menu settings", selection: $category) {
                ForEach(Category.allCases) { Text($0.rawValue).tag($0) }
            }.pickerStyle(.segmented).labelsHidden().padding(.horizontal, 24).padding(.vertical, 16)
            Form {
                if category == .displays {
                    Section("Displays in the Menu") {
                        Picker("Show", selection: $displayScope) {
                            ForEach(MenuDisplayScope.allCases) { scope in Text(scope.title).tag(scope.rawValue) }
                        }.pickerStyle(.segmented).labelsHidden()
                        if scope == .custom {
                            if knownMonitors.isEmpty {
                                Text("Connect a display to customize this list.").foregroundStyle(.secondary)
                            }
                            ForEach(knownMonitors) { monitor in
                                Toggle(isOn: visibility(for: monitor)) {
                                    Label {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(monitor.displayName)
                                            Text(
                                                monitorStore.monitors.contains { $0.id == monitor.id }
                                                    ? (monitor.isBuiltIn ? "Built-in display" : "External display")
                                                    : "Disconnected · choice remembered"
                                            )
                                            .font(.caption).foregroundStyle(.secondary)
                                        }
                                    } icon: {
                                        Image(systemName: monitor.isBuiltIn ? "laptopcomputer" : "display")
                                    }
                                }.accessibilityLabel("Show \(monitor.displayName) in menu")
                            }
                            Button("Show All in Custom Selection") { hiddenDisplayData = Data() }.buttonStyle(
                                .borderless)
                            Text("Choices are remembered across reconnects. New displays are shown automatically.")
                                .font(.caption).foregroundStyle(.secondary)
                        } else {
                            let count = monitorStore.monitors.filter { scope.includes($0, hiddenIDs: []) }.count
                            Text(
                                "\(count) of \(monitorStore.monitors.count) displays shown. Choose Custom to select individual displays."
                            )
                            .font(.caption).foregroundStyle(.secondary)
                        }
                        Text("Hidden displays stay available in Settings, shortcuts, and presets.")
                            .font(.caption).foregroundStyle(.secondary)
                    }

                }
                if category == .layout {
                    Section("Reopening the Menu") {
                        Picker("When reopening the menu", selection: $rememberLayout) {
                            Text("Remember My Layout").tag(true)
                            Text("Start Collapsed").tag(false)
                        }
                    }
                    Section("Expansion Behavior") {
                        Toggle("One display at a time", isOn: $singleExpanded)
                        Toggle("One feature section at a time", isOn: $singleFeature)
                        Button("Reset Saved Layout") {
                            expandedData = Data()
                            sectionData = Data()
                            presetsExpanded = false
                        }.buttonStyle(.borderless)
                        Text(
                            "Remember My Layout restores your expanded displays and sections. Start Collapsed reopens a compact menu."
                        )
                        .font(.caption).foregroundStyle(.secondary)
                    }
                }
                if category == .quickAccess {
                    Section("Presets") {
                        Toggle("Show Presets in Menu", isOn: Binding(
                            get: { preferences.shown(.presets) },
                            set: { preferences.setShown($0, .presets) }
                        ))
                        .disabled(!preferences.enabled(.presets))
                        Text(preferences.enabled(.presets)
                             ? "Hide the Presets section while keeping your saved presets and shortcuts."
                             : "Presets are disabled in Features. Enable them there to show this section.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Section("Frequently Used Controls") {
                        Toggle("Keep brightness visible when displays are collapsed", isOn: $brightnessAlwaysVisible)
                        Text("Adjust brightness as soon as you open the menu, without expanding a display.")
                            .font(.caption).foregroundStyle(.secondary)
                        Toggle("Keep input buttons visible", isOn: $inputsAlwaysVisible)
                        Toggle("Show advanced macOS color profiles", isOn: Binding(
                            get: { preferences.shown(.profiles) },
                            set: { preferences.setShown($0, .profiles) }))
                            .disabled(!preferences.enabled(.profiles))
                    }
                    Section("Display Information") {
                        Toggle("Show Display Info in the menu", isOn: $showDisplayInfo)
                        Text("Connection, manufacturer, size, and identification controls. Off by default; display information stays available in Settings → Displays → Info.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Section("Menu Controls") {
                        Button("Choose Which Controls Appear…", action: onOpenFeatures)
                        Text("Choose feature availability and menu visibility in Features.")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Section("Tips") {
                        Text(
                            "Right-click the menu-bar icon for quick actions. Option-click it for Settings; Option-click a display name to identify that screen."
                        )
                        .font(.caption).foregroundStyle(.secondary)
                    }
                }
            }.formStyle(.grouped)
        }
    }
}
