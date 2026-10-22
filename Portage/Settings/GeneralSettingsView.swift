import ServiceManagement
import SwiftUI

struct GeneralSettingsView: View {
    @Bindable private var appearance = AppAppearance.shared
    @State private var startupError: String?
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled

    var body: some View {
        Form {
            Section {
                Picker("Appearance", selection: $appearance.mode) {
                    ForEach(AppAppearance.Mode.allCases) { Text($0.title).tag($0) }
                }.pickerStyle(.segmented)
            } header: {
                Text("Appearance")
            } footer: {
                Text("System follows macOS automatically. Light and Dark apply only to Portage and are remembered when you reopen it.")
            }
            Section("Startup") {
                Toggle("Launch at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, newValue in
                        do {
                            if newValue {
                                try SMAppService.mainApp.register()
                            } else {
                                try SMAppService.mainApp.unregister()
                            }
                            startupError = nil
                        } catch {
                            startupError = error.localizedDescription
                            launchAtLogin = SMAppService.mainApp.status == .enabled
                        }
                    }
                if let startupError { Text(startupError).font(.caption).foregroundStyle(.red) }
            }

            Section("About") {
                Text("Portage").font(.headline)
                Text("Display controls for your Mac.")
                    .font(.caption).foregroundStyle(.secondary)
                if let url = Bundle.main.url(forResource: "ThirdPartyNotices", withExtension: "txt") {
                    Link("Open-source acknowledgements", destination: url)
                }
                LabeledContent("Version") {
                    Text(
                        Bundle.main.infoDictionary?["CFBundleShortVersionString"]
                            as? String ?? "—"
                    )
                }
                LabeledContent("Build") {
                    Text(
                        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
                    )
                }
            }
        }
        .formStyle(.grouped)
    }
}
