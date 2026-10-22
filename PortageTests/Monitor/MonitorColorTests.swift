import Foundation
import Testing
@testable import Portage

@Suite("Monitor native colors") @MainActor
struct MonitorColorTests {
    private func setup(enabled: Bool = true, manufacturer: String = "DEL") async -> (MonitorStore, MockDDCService, UserDefaults) {
        let defaults = UserDefaults(suiteName: "test-monitor-colors-\(UUID())")!
        let features = FeaturePreferences(defaults: defaults)
        features.setEnabled(enabled, .monitorColors)
        let mock = MockDDCService()
        await mock.configure(displays: [DDCDisplayInfo(edidUUID: "color-display", productName: "Test", manufacturer: manufacturer, alphanumericSerial: "", supportedVCP: [0x14, 0x16, 0x18, 0x1A], colorPresetValues: [1, 5, 11])])
        await mock.setVCPValue(0x14, display: "color-display", current: 5, max: 0)
        await mock.setVCPValue(0x16, display: "color-display", current: 100, max: 200)
        await mock.setVCPValue(0x18, display: "color-display", current: 80, max: 100)
        await mock.setVCPValue(0x1A, display: "color-display", current: 25, max: 100)
        let store = MonitorStore(ddcService: mock, defaults: defaults, features: features)
        await store.discover()
        return (store, mock, defaults)
    }

    @Test func worksFromCapabilitiesAcrossUnknownBrands() async {
        let (store, _, _) = await setup(manufacturer: "XYZ")
        #expect(store.monitors.first?.colorPresetValues == [1, 5, 11])
        #expect(store.monitors.first?.currentColorPreset == 5)
        #expect(store.monitors.first?.hardwareLevels?[HardwareFeature.redGain.key] == 0.5)
    }

    @Test func disabledColorControlsDoNotReadOrWriteVCPs() async {
        let (store, mock, _) = await setup(enabled: false)
        let operations = await mock.operations
        for code: UInt8 in [0x14, 0x16, 0x18, 0x1A] {
            #expect(!operations.contains(.read("color-display", code)))
        }
        await #expect(throws: FeaturePreferences.DisabledFeature.self) {
            try await store.applyColorPreset(monitorID: "color-display", value: 1)
        }
        #expect(await mock.writeLog.isEmpty)
        #expect(store.monitors.first?.hasMonitorColorControls == false)
    }

    @Test func refusesUnadvertisedPresetValue() async {
        let (store, mock, _) = await setup()
        await #expect(throws: DDCError.self) { try await store.applyColorPreset(monitorID: "color-display", value: 9) }
        #expect(await mock.writeLog.isEmpty)
    }

    @Test func ignoredColorPresetDoesNotReportSuccess() async {
        let (store, mock, _) = await setup()
        await mock.setShouldRejectWriteSilently(true)
        await #expect(throws: DDCError.self) { try await store.applyColorPreset(monitorID: "color-display", value: 11) }
        #expect(store.monitors.first?.currentColorPreset == 5)
    }

    @Test func colorPresetPrecedesRGBAndSnapshotExcludesMacProfiles() async {
        let (monitors, mock, defaults) = await setup()
        let store = PresetStore(monitorStore: monitors, defaults: defaults)
        var preset = Preset(name: "Warm")
        preset.displaySettings = [PresetDisplaySettings(monitorEdidUUID: "color-display", displayName: "Test", colorPreset: 11, rgbGains: [HardwareFeature.redGain.key: 0.75, HardwareFeature.blueGain.key: 0.2])]
        await store.activate(preset: preset)
        let log = await mock.writeLog
        #expect(log.map(\.vcp) == [0x14, 0x16, 0x1A])
        #expect(log.map(\.value) == [11, 150, 20])
        #expect(store.lastActivationError == nil)
        let captured = store.saveCurrentAppearance()
        #expect(captured.displaySettings?.first?.colorPreset == 11)
        #expect(captured.displaySettings?.first?.rgbGains?[HardwareFeature.redGain.key] == 0.75)
        #expect(captured.displaySettings?.first?.colorProfilePath == nil)
    }
}
