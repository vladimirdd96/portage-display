import KeyboardShortcuts
import Testing

@testable import Portage

@Suite("HotkeyManager")
@MainActor
struct HotkeyManagerTests {
    private func makeStores() async -> (PresetStore, MonitorStore, MockDDCService) {
        let mock = MockDDCService()
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let monitorStore = MonitorStore(ddcService: mock, defaults: defaults)
        let presetStore = PresetStore(monitorStore: monitorStore, defaults: defaults)
        return (presetStore, monitorStore, mock)
    }

    @Test("Re-registers hotkeys when a preset gains a hotkeyName")
    func reregistersOnPresetChange() async throws {
        let (presetStore, _, _) = await makeStores()
        let panel = PanelController()
        let _ = HotkeyManager(panelController: panel, presetStore: presetStore)

        var preset = Preset(name: "Test Preset")
        presetStore.addPreset(preset)

        preset.hotkeyName = "preset-\(preset.id.uuidString)"
        presetStore.updatePreset(preset)

        await Task.yield()

        let name = KeyboardShortcuts.Name(preset.hotkeyName!)
        #expect(name.rawValue == preset.hotkeyName!)
    }
}
