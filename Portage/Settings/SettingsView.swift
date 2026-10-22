import SwiftUI

struct SettingsView: View {
    let monitorStore: MonitorStore
    let presetStore: PresetStore
    @AppStorage("settings.section") private var savedSection = SettingsSection.monitors.rawValue
    @State private var search = ""

    enum SettingsSection: String, CaseIterable, Identifiable {
        case general = "General"
        case monitors = "Displays"
        case shortcuts = "Inputs & Shortcuts"
        case presets = "Presets"
        case menu = "Menu Bar"
        case features = "Features"
        var id: Self { self }
        var icon: String {
            switch self {
            case .features: "switch.2"
            case .shortcuts: "keyboard"
            case .monitors: "display.2"
            case .presets: "rectangle.stack"
            case .general: "gearshape"
            case .menu: "menubar.rectangle"
            }
        }
        var keywords: String {
            switch self {
            case .general: "appearance theme dark light system login startup version about"
            case .monitors: "brightness resolution mode refresh color profile contrast volume information"
            case .shortcuts: "keyboard hotkey cycle order input hdmi displayport"
            case .presets: "multi display setup assignments brightness color contrast audio saved settings"
            case .menu: "visibility hide remember layout expand collapse quick access"
            case .features: "enable disable controls availability"
            }
        }
    }
    private var selection: Binding<SettingsSection?> {
        Binding(
            get: { SettingsSection(rawValue: savedSection) ?? .monitors },
            set: { if let value = $0 { savedSection = value.rawValue } })
    }
    private var current: SettingsSection { selection.wrappedValue ?? .monitors }

    var body: some View {
        NavigationSplitView {
            List(selection: selection) {
                navigationGroup("Settings", [.general, .monitors])
                navigationGroup("Control", [.shortcuts, .presets])
                navigationGroup("Customize", [.menu, .features])
                if !search.isEmpty,
                    !SettingsSection.allCases.contains(where: {
                        ($0.rawValue + " " + $0.keywords).localizedCaseInsensitiveContains(search)
                    })
                {
                    Text("No matching settings").foregroundStyle(.secondary)
                }
            }
            .searchable(text: $search, placement: .sidebar, prompt: "Find settings")
            .navigationTitle("Portage")
            .navigationSplitViewColumnWidth(min: 190, ideal: 200, max: 240)
        } detail: {
            Group {
                switch current {
                case .features: FeatureSettingsView()
                case .shortcuts: HotkeySettingsView(presetStore: presetStore, monitorStore: monitorStore)
                case .monitors: MonitorSettingsView(monitorStore: monitorStore)
                case .presets: PresetSettingsView(presetStore: presetStore, monitorStore: monitorStore)
                case .general: GeneralSettingsView()
                case .menu:
                    MenuSettingsView(
                        monitorStore: monitorStore, onOpenFeatures: { savedSection = SettingsSection.features.rawValue }
                    )
                }
            }
            .disclosureGroupStyle(.fullRow)
            .navigationTitle(current.rawValue)
            .toolbar {
                if current != .general && current != .features {
                    ToolbarItem {
                        Button {
                            Task { await monitorStore.discover() }
                        } label: {
                            Label(
                                monitorStore.isDiscovering ? "Refreshing…" : "Refresh Displays",
                                systemImage: "arrow.clockwise")
                        }.disabled(monitorStore.isDiscovering).help("Refresh connected displays")
                    }
                }
            }
        }
        .frame(minWidth: 820, minHeight: 580)
    }

    @ViewBuilder private func navigationGroup(_ title: String, _ sections: [SettingsSection]) -> some View {
        let matches = sections.filter {
            search.isEmpty || ($0.rawValue + " " + $0.keywords).localizedCaseInsensitiveContains(search)
        }
        if !matches.isEmpty {
            Section(title) {
                ForEach(matches) { section in
                    Label(section.rawValue, systemImage: section.icon).tag(section).padding(.vertical, 3)
                }
            }
        }
    }
}
