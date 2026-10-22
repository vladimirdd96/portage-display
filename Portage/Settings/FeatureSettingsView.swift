import SwiftUI

struct FeatureSettingsView: View {
    private let preferences = FeaturePreferences.shared
    var body: some View {
        Form {
            Section {
                Grid(horizontalSpacing: 20, verticalSpacing: 16) {
                    GridRow {
                        Text("Control").frame(maxWidth: .infinity, alignment: .leading)
                        Text("Enabled").frame(width: 70)
                        Text("In Menu").frame(width: 80)
                    }.font(.caption).foregroundStyle(.secondary)
                    Divider().gridCellUnsizedAxes(.horizontal)
                    ForEach(AppFeature.allCases) { feature in
                        GridRow {
                            Text(feature.title).frame(maxWidth: .infinity, alignment: .leading)
                            Toggle(
                                "Enabled",
                                isOn: Binding(
                                    get: { preferences.enabled(feature) }, set: { preferences.setEnabled($0, feature) })
                            )
                            .labelsHidden().frame(width: 70).accessibilityLabel("Enable \(feature.title)")
                            Toggle(
                                "In Menu",
                                isOn: Binding(
                                    get: { !preferences.hidden.contains(feature.rawValue) },
                                    set: { preferences.setShown($0, feature) })
                            )
                            .labelsHidden().frame(width: 80).disabled(!preferences.enabled(feature))
                            .accessibilityLabel("Show \(feature.title) in menu")
                        }
                    }
                }.padding(.vertical, 4)
            } header: {
                Text("Available Controls")
            } footer: {
                Text(
                    "Enabled controls work throughout Portage. Turn off In Menu to keep a control available only in Settings, shortcuts, and automation."
                )
            }
            Section {
                Label(
                    "Your display settings and saved shortcuts are preserved when a control is disabled.",
                    systemImage: "info.circle"
                )
                .font(.callout).foregroundStyle(.secondary)
            }
        }.formStyle(.grouped)
    }
}
