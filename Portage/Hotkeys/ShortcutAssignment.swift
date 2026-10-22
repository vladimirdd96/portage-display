import KeyboardShortcuts

@MainActor
enum ShortcutAssignment {
    static func names(monitors: MonitorStore, presets: PresetStore) -> [KeyboardShortcuts.Name] {
        [.togglePanel]
            + monitors.configuredMonitors.flatMap { monitor in
                [.cycleInputs(monitor.id)] + monitor.inputMappings.map { .inputSource(monitor.id, $0.ddcValue) }
            }
            + presets.presets.compactMap { $0.hotkeyName.map { KeyboardShortcuts.Name($0) } }
    }

    static func move(_ shortcut: KeyboardShortcuts.Shortcut?, to name: KeyboardShortcuts.Name, among names: [KeyboardShortcuts.Name]) {
        guard let shortcut else { return }
        for other in names where other != name {
            if KeyboardShortcuts.getShortcut(for: other) == shortcut {
                KeyboardShortcuts.setShortcut(nil, for: other)
            }
        }
    }
}
