import AppIntents

struct PortageShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ActivatePresetIntent(),
            phrases: [
                "Switch monitors to \(\.$preset) in \(.applicationName)",
                "Activate \(\.$preset) in \(.applicationName)",
            ],
            shortTitle: "Activate Preset",
            systemImageName: "rectangle.connected.to.line.below"
        )
    }
}
