import Testing

@testable import Portage

@Suite("PresetStore")
@MainActor
struct PresetStoreTests {
    private func makeTestDisplays() -> [DDCDisplayInfo] {
        [
            DDCDisplayInfo(
                edidUUID: "uuid-1",
                productName: "MSI MPG 274U",
                manufacturer: "MSI",
                alphanumericSerial: "SN001"
            ),
            DDCDisplayInfo(
                edidUUID: "uuid-2",
                productName: "BenQ MA270U",
                manufacturer: "BNQ",
                alphanumericSerial: "SN002"
            ),
        ]
    }

    private func makeStores() async -> (PresetStore, MonitorStore, MockDDCService) {
        let mock = MockDDCService()
        await mock.configure(displays: makeTestDisplays())
        await mock.setVCPValue(0x60, display: "uuid-1", current: 8, max: 18)
        await mock.setVCPValue(0x60, display: "uuid-2", current: 19, max: 19)
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let monitorStore = MonitorStore(ddcService: mock, defaults: defaults)
        await monitorStore.discover()
        let presetStore = PresetStore(monitorStore: monitorStore, defaults: defaults)
        return (presetStore, monitorStore, mock)
    }

    @Test("Add and retrieve presets")
    func addPreset() async {
        let (store, _, _) = await makeStores()
        let preset = Preset(name: "Work Mode")
        store.addPreset(preset)
        #expect(store.presets.count == 1)
        #expect(store.presets[0].name == "Work Mode")
    }

    @Test("Delete preset by ID")
    func deletePreset() async {
        let (store, _, _) = await makeStores()
        let preset = Preset(name: "Work Mode")
        store.addPreset(preset)
        store.deletePreset(id: preset.id)
        #expect(store.presets.isEmpty)
    }

    @Test("Update preset")
    func updatePreset() async {
        let (store, _, _) = await makeStores()
        var preset = Preset(name: "Work Mode")
        store.addPreset(preset)
        preset.name = "Gaming Mode"
        store.updatePreset(preset)
        #expect(store.presets[0].name == "Gaming Mode")
    }

    @Test("Activate preset sends correct DDC writes")
    func activatePreset() async {
        let (store, _, mock) = await makeStores()
        let preset = Preset(
            name: "Work Mode",
            assignments: [
                PresetAssignment(monitorEdidUUID: "uuid-1", targetInputValue: 5, targetInputLabel: "HDMI-1"),
                PresetAssignment(monitorEdidUUID: "uuid-2", targetInputValue: 17, targetInputLabel: "HDMI-1"),
            ]
        )
        store.addPreset(preset)
        await store.activate(preset: preset)
        let log = await mock.writeLog
        #expect(log.count == 2)
        let values = Set(log.map(\.value))
        #expect(values.contains(5))
        #expect(values.contains(17))
        #expect(store.lastActivationError == nil)
    }

    @Test("Activate preset refreshes stale inputs with one discovery")
    func activatePresetRefreshesStaleInputs() async {
        let (store, _, mock) = await makeStores()
        let preset = Preset(
            name: "Current Inputs",
            assignments: [
                PresetAssignment(monitorEdidUUID: "uuid-1", targetInputValue: 8, targetInputLabel: "USB-C"),
                PresetAssignment(monitorEdidUUID: "uuid-2", targetInputValue: 19, targetInputLabel: "USB-C"),
            ]
        )
        await mock.setVCPValue(0x60, display: "uuid-1", current: 5, max: 18)
        await mock.setVCPValue(0x60, display: "uuid-2", current: 17, max: 19)
        await mock.setDiscoveryDelay(.milliseconds(100))

        await store.activate(preset: preset)

        let log = await mock.writeLog
        let discoveryCount = await mock.discoveryCount
        #expect(log.count == 2)
        #expect(Set(log.map(\.value)) == [8, 19])
        #expect(discoveryCount == 2)
        #expect(store.lastActivationError == nil)
    }

    @Test("Activate preset collects errors")
    func activateWithErrors() async {
        let (store, _, mock) = await makeStores()
        await mock.setShouldFailWrite(true)
        let preset = Preset(
            name: "Broken",
            assignments: [
                PresetAssignment(monitorEdidUUID: "uuid-1", targetInputValue: 5, targetInputLabel: "HDMI-1"),
            ]
        )
        await store.activate(preset: preset)
        #expect(store.lastActivationError != nil)
    }

    @Test("Persistence round-trips presets via UserDefaults")
    func persistence() async {
        let suiteName = "test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let mock = MockDDCService()
        await mock.configure(displays: makeTestDisplays())
        let monitorStore = MonitorStore(ddcService: mock, defaults: defaults)

        let store1 = PresetStore(monitorStore: monitorStore, defaults: defaults)
        store1.addPreset(Preset(name: "Preset A"))
        store1.addPreset(Preset(name: "Preset B"))

        let store2 = PresetStore(monitorStore: monitorStore, defaults: defaults)
        #expect(store2.presets.count == 2)
        #expect(store2.presets[0].name == "Preset A")
    }
}
