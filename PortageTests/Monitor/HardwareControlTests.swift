import Foundation
import Testing
@testable import Portage

@Suite("Hardware controls")
@MainActor
struct HardwareControlTests {
    private func setup(features: Set<UInt8>) async -> (MonitorStore, MockDDCService) {
        let mock = MockDDCService()
        await mock.configure(displays: [DDCDisplayInfo(edidUUID: "hardware-test", productName: "Test Display", manufacturer: "DEL", alphanumericSerial: "", supportedVCP: features)])
        await mock.setVCPValue(0x12, display: "hardware-test", current: 50, max: 200)
        await mock.setVCPValue(0x62, display: "hardware-test", current: 30, max: 100)
        await mock.setVCPValue(0x8D, display: "hardware-test", current: 2, max: 2)
        let store = MonitorStore(ddcService: mock, defaults: UserDefaults(suiteName: "test-\(UUID())")!)
        await store.discover()
        return (store, mock)
    }

    @Test func onlyAdvertisedControlsAppear() async {
        let (store, _) = await setup(features: [0x12])
        #expect(store.monitors.first?.hardwareLevels?[HardwareFeature.contrast.key] == 0.25)
        #expect(store.monitors.first?.hardwareLevels?[HardwareFeature.volume.key] == nil)
        #expect(store.monitors.first?.isMuted == nil)
    }

    @Test func scalesDebouncesAndClamps() async throws {
        let (store, mock) = await setup(features: [0x12])
        store.setHardwareLevel(monitorID: "hardware-test", feature: .contrast, value: 0.5)
        store.setHardwareLevel(monitorID: "hardware-test", feature: .contrast, value: 4)
        try await Task.sleep(for: .milliseconds(300))
        let writes = await mock.writeLog
        #expect(writes.count == 1)
        #expect(writes.first?.vcp == 0x12)
        #expect(writes.first?.value == 200)
    }

    @Test func cannotWriteUnadvertisedControl() async throws {
        let (store, mock) = await setup(features: [])
        store.setHardwareLevel(monitorID: "hardware-test", feature: .volume, value: 0.5)
        try await Task.sleep(for: .milliseconds(180))
        #expect(await mock.writeLog.isEmpty)
    }

    @Test func muteUsesCorrectDDCValues() async throws {
        let (store, mock) = await setup(features: [0x8D])
        try await store.setMute(monitorID: "hardware-test", muted: true)
        try await store.setMute(monitorID: "hardware-test", muted: false)
        let writes = await mock.writeLog
        #expect(writes.map(\.value) == [1, 2])
        #expect(store.monitors.first?.isMuted == false)
    }
}
