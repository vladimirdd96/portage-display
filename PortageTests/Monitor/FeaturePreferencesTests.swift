import Foundation
import Testing
@testable import Portage

@Suite("Feature preferences") @MainActor
struct FeaturePreferencesTests {
    private func preferences() -> (FeaturePreferences, UserDefaults) {
        let defaults = UserDefaults(suiteName: "test-features-\(UUID())")!
        return (FeaturePreferences(defaults: defaults), defaults)
    }

    @Test func hidingPreservesEnabledStateAcrossLaunch() {
        let (preferences, defaults) = preferences()
        preferences.setShown(false, .inputs)
        let restored = FeaturePreferences(defaults: defaults)
        #expect(restored.enabled(.inputs))
        #expect(!restored.shown(.inputs))
        #expect(restored.shown(.brightness))
    }

    @Test func enablingRestoresPreviousMenuChoice() {
        let (preferences, defaults) = preferences()
        preferences.setShown(false, .profiles)
        preferences.setEnabled(false, .profiles)
        let restored = FeaturePreferences(defaults: defaults)
        #expect(!restored.enabled(.profiles))
        restored.setEnabled(true, .profiles)
        #expect(!restored.shown(.profiles))
    }

    @Test func disabledInputsBlockDirectAndCycleActions() async {
        let (preferences, defaults) = preferences()
        preferences.setEnabled(false, .inputs)
        let mock = MockDDCService()
        let store = MonitorStore(ddcService: mock, defaults: defaults, features: preferences)
        await #expect(throws: FeaturePreferences.DisabledFeature.self) { try await store.switchInput(monitorID: "test", to: 17) }
        await #expect(throws: FeaturePreferences.DisabledFeature.self) { try await store.cycleInput(monitorID: "test") }
        #expect(await mock.writeLog.isEmpty)
        #expect(await mock.discoveryCount == 0)
    }

    @Test func disablingBrightnessCancelsPendingWrite() async throws {
        let (preferences, defaults) = preferences()
        let mock = MockDDCService()
        await mock.configure(displays: [DDCDisplayInfo(edidUUID: "feature-test", productName: "Test", manufacturer: "DEL", alphanumericSerial: "")])
        await mock.setVCPValue(0x10, display: "feature-test", current: 50, max: 100)
        let store = MonitorStore(ddcService: mock, defaults: defaults, features: preferences)
        await store.discover()
        store.setBrightness(monitorID: "feature-test", value: 0.8)
        preferences.setEnabled(false, .brightness)
        try await Task.sleep(for: .milliseconds(250))
        #expect(await mock.writeLog.isEmpty)
    }
}
