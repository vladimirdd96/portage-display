import Foundation
import Testing
@testable import Portage

@Suite("Appearance presets") @MainActor
struct AppearancePresetTests {
    private func stores() async -> (PresetStore, MonitorStore, MockDDCService, UserDefaults) {
        let defaults = UserDefaults(suiteName: "test-appearance-\(UUID())")!
        let mock = MockDDCService()
        await mock.configure(displays: [DDCDisplayInfo(edidUUID: "test-display", productName: "Test Display", manufacturer: "DEL", alphanumericSerial: "", supportedVCP: [0x12, 0x62, 0x8D])])
        await mock.setVCPValue(0x10, display: "test-display", current: 50, max: 200)
        await mock.setVCPValue(0x12, display: "test-display", current: 40, max: 80)
        await mock.setVCPValue(0x62, display: "test-display", current: 20, max: 100)
        await mock.setVCPValue(0x8D, display: "test-display", current: 2, max: 2)
        await mock.setVCPValue(0x60, display: "test-display", current: 17, max: 18)
        let monitors = MonitorStore(ddcService: mock, defaults: defaults, features: FeaturePreferences(defaults: defaults))
        await monitors.discover()
        return (PresetStore(monitorStore: monitors, defaults: defaults), monitors, mock, defaults)
    }

    @Test func oldPresetDataRemainsReadable() throws {
        let json = """
        {"id":"00000000-0000-0000-0000-000000000001","name":"Work","assignments":[{"id":"00000000-0000-0000-0000-000000000002","monitorEdidUUID":"test-display","targetInputValue":18,"targetInputLabel":"HDMI 2"}]}
        """
        let preset = try JSONDecoder().decode(Preset.self, from: Data(json.utf8))
        #expect(preset.displaySettings == nil)
        #expect(preset.assignments.first?.targetInputValue == 18)
        #expect(preset.displayCount == 1)
    }

    @Test func appearanceWritesAreAwaitedAndInputIsLast() async {
        let (store, monitors, mock, _) = await stores()
        var preset = Preset(name: "Evening", assignments: [PresetAssignment(monitorEdidUUID: "test-display", targetInputValue: 18, targetInputLabel: "HDMI 2")])
        preset.displaySettings = [PresetDisplaySettings(monitorEdidUUID: "test-display", displayName: "Test", brightness: 0.4, contrast: 0.75, volume: 0.3, muted: true)]
        await store.activate(preset: preset)
        let writes = await mock.writeLog
        #expect(writes.map(\.vcp) == [0x10, 0x12, 0x62, 0x8D, 0x60])
        #expect(writes.map(\.value) == [80, 60, 30, 1, 18])
        #expect(monitors.monitors.first?.brightnessValue == 0.4)
        #expect(store.lastActivationError == nil)
        #expect(preset.displayCount == 1)
    }

    @Test func brightnessOnlyDoesNotSwitchInputs() async {
        let (store, _, mock, _) = await stores()
        var preset = Preset(name: "Dim")
        preset.displaySettings = [PresetDisplaySettings(monitorEdidUUID: "test-display", displayName: "Test", brightness: 0.2)]
        await store.activate(preset: preset)
        #expect(await mock.writeLog.map(\.vcp) == [0x10])
        #expect(store.lastActivationError == nil)
    }

    @Test func failedAppearanceWriteReportsError() async {
        let (store, _, mock, _) = await stores()
        await mock.setShouldFailWrite(true)
        var preset = Preset(name: "Dim")
        preset.displaySettings = [PresetDisplaySettings(monitorEdidUUID: "test-display", displayName: "Test", brightness: 0.2)]
        await store.activate(preset: preset)
        #expect(store.lastActivationError?.contains("Brightness") == true)
    }

    @Test func disabledBrightnessIsNotWritten() async {
        let (store, monitors, mock, _) = await stores()
        monitors.features.setEnabled(false, .brightness)
        var preset = Preset(name: "Dim")
        preset.displaySettings = [PresetDisplaySettings(monitorEdidUUID: "test-display", displayName: "Test", brightness: 0.2)]
        await store.activate(preset: preset)
        #expect(await mock.writeLog.isEmpty)
        #expect(store.lastActivationError?.contains("disabled") == true)
    }

    @Test func snapshotIsReadOnlyAndPersists() async {
        let (store, monitors, mock, defaults) = await stores()
        let preset = store.saveCurrentAppearance()
        #expect(preset.assignments.isEmpty)
        #expect(preset.displaySettings?.first?.brightness == 0.25)
        #expect(preset.displaySettings?.first?.contrast == 0.5)
        #expect(await mock.writeLog.isEmpty)
        let restored = PresetStore(monitorStore: monitors, defaults: defaults)
        #expect(restored.presets.first?.displaySettings?.first?.brightness == 0.25)
    }

    @Test func missingProfileDoesNotPreventOtherControlsOrReportSuccess() async {
        let (store, _, mock, _) = await stores()
        var preset = Preset(name: "Color")
        preset.displaySettings = [PresetDisplaySettings(monitorEdidUUID: "test-display", displayName: "Test", brightness: 0.4, colorProfilePath: "/nonexistent/profile.icc", colorProfileName: "Missing")]
        await store.activate(preset: preset)
        #expect(await mock.writeLog.count == 1)
        #expect(store.lastActivationError?.contains("Color profile") == true)
    }

    @Test func emptyPresetIsNotAnnouncedAsApplied() async {
        let (store, _, _, _) = await stores()
        await store.activate(preset: Preset(name: "Empty"))
        #expect(store.lastActivationError != nil)
    }
}
