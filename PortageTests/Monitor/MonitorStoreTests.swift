import Testing

@testable import Portage

@Suite("MonitorStore")
@MainActor
struct MonitorStoreTests {
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

    private func makeStore() async -> (MonitorStore, MockDDCService) {
        let mock = MockDDCService()
        let displays = makeTestDisplays()
        await mock.configure(displays: displays)
        await mock.setVCPValue(0x60, display: "uuid-1", current: 8, max: 18)
        await mock.setVCPValue(0x60, display: "uuid-2", current: 19, max: 19)
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let store = MonitorStore(ddcService: mock, defaults: defaults)
        return (store, mock)
    }

    @Test("Brightness uses monitor maximum and coalesces rapid slider changes")
    func brightnessScalingAndDebounce() async throws {
        let (store, mock) = await makeStore()
        await mock.setVCPValue(0x10, display: "uuid-1", current: 100, max: 200)
        await store.discover()
        #expect(store.monitors[0].brightnessValue == 0.5)
        store.setBrightness(monitorID: "uuid-1", value: 0.3)
        store.setBrightness(monitorID: "uuid-1", value: 0.75)
        try await Task.sleep(for: .milliseconds(250))
        let writes = await mock.writeLog
        #expect(writes.count == 1)
        #expect(writes.first?.value == 150)
        #expect(writes.first?.vcp == 0x10)
    }

    @Test("Unavailable brightness cannot issue writes")
    func unavailableBrightness() async throws {
        let (store, mock) = await makeStore()
        await store.discover()
        #expect(store.monitors[0].brightnessValue == nil)
        store.setBrightness(monitorID: "uuid-1", value: 0.5)
        try await Task.sleep(for: .milliseconds(150))
        #expect(await mock.writeLog.isEmpty)
    }

    @Test("Built-in displays have brightness but no input mappings")
    func builtInDisplay() async {
        let mock = MockDDCService()
        await mock.configure(displays: [DDCDisplayInfo(edidUUID: "native-1", productName: "Built-in Display", manufacturer: "Apple", alphanumericSerial: "", advertisedInputs: [])])
        await mock.setVCPValue(0x10, display: "native-1", current: 600, max: 1000)
        let store = MonitorStore(ddcService: mock, defaults: UserDefaults(suiteName: "test-\(UUID().uuidString)")!)
        await store.discover()
        #expect(store.monitors.first?.isBuiltIn == true)
        #expect(store.monitors.first?.inputMappings.isEmpty == true)
        #expect(store.monitors.first?.brightnessValue == 0.6)
    }

    @Test("Disconnect and reconnect preserves custom monitor labels")
    func reconnectPreservesConfiguration() async {
        let (store, mock) = await makeStore()
        await store.discover()
        store.updateDisplayName(monitorID: "uuid-1", name: "Desk screen")
        await mock.configure(displays: [])
        await store.discover()
        #expect(store.monitors.isEmpty)
        await mock.configure(displays: makeTestDisplays())
        await store.discover()
        #expect(store.monitors.first?.displayName == "Desk screen")
    }

    @Test("Discovery populates monitors with correct info")
    func discoverPopulates() async {
        let (store, _) = await makeStore()
        await store.discover()
        #expect(store.monitors.count == 2)
        #expect(store.monitors[0].displayName == "MSI MPG 274U")
        #expect(store.monitors[1].displayName == "BenQ MA270U")
    }

    @Test("Discovery reads current input values")
    func discoverReadsInput() async {
        let (store, _) = await makeStore()
        await store.discover()
        #expect(store.monitors[0].currentInputValue == 8)
        #expect(store.monitors[1].currentInputValue == 19)
    }

    @Test("Concurrent discovery calls share one in-flight refresh")
    func concurrentDiscoveryCoalesces() async {
        let (store, mock) = await makeStore()
        await mock.setDiscoveryDelay(.milliseconds(100))

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<3 {
                group.addTask {
                    await store.discover()
                }
            }
        }

        let discoveryCount = await mock.discoveryCount
        #expect(discoveryCount == 1)
        #expect(!store.isDiscovering)
    }

    @Test("Discovery assigns manufacturer-specific input mappings")
    func discoverAssignsMappings() async {
        let (store, _) = await makeStore()
        await store.discover()
        let msiMappings = store.monitors[0].inputMappings
        #expect(msiMappings.count == 4)
        let msiHasUSBC = msiMappings.contains { $0.label == "USB-C" && $0.ddcValue == 8 }
        #expect(msiHasUSBC)
        let benqMappings = store.monitors[1].inputMappings
        #expect(benqMappings.count == 3)
        let benqHasUSBC = benqMappings.contains { $0.label == "USB-C" && $0.ddcValue == 19 }
        #expect(benqHasUSBC)
    }

    @Test("SwitchInput writes VCP, verifies readback, and updates stored value")
    func switchInput() async throws {
        let (store, mock) = await makeStore()
        await store.discover()
        try await store.switchInput(monitorID: "uuid-1", to: 5)
        #expect(store.monitors[0].currentInputValue == 5)
        let log = await mock.writeLog
        #expect(log.count == 1)
        #expect(log[0].vcp == 0x60)
        #expect(log[0].value == 5)
    }

    @Test("SwitchInput reverts on silent rejection by monitor")
    func switchInputRevertsOnSilentRejection() async throws {
        let (store, mock) = await makeStore()
        await store.discover()
        #expect(store.monitors[0].currentInputValue == 8)
        await mock.setShouldRejectWriteSilently(true)
        await #expect(throws: DDCError.self) {
            try await store.switchInput(monitorID: "uuid-1", to: 5)
        }
        #expect(store.monitors[0].currentInputValue == 8)
    }

    @Test("SwitchInput keeps optimistic value when readback fails")
    func switchInputKeepsOptimisticOnReadFailure() async throws {
        let (store, mock) = await makeStore()
        await store.discover()
        await mock.setShouldFailRead(true)
        try await store.switchInput(monitorID: "uuid-1", to: 5)
        #expect(store.monitors[0].currentInputValue == 5)
    }

    @Test("SwitchInput skips when fresh state matches requested input")
    func switchInputSkipsNoOp() async throws {
        let (store, mock) = await makeStore()
        await store.discover()
        #expect(store.monitors[0].currentInputValue == 8)
        try await store.switchInput(monitorID: "uuid-1", to: 8)
        let log = await mock.writeLog
        #expect(log.isEmpty)
    }

    @Test("SwitchInput writes when cached state is stale")
    func switchInputRefreshesStaleCache() async throws {
        let (store, mock) = await makeStore()
        await store.discover()
        #expect(store.monitors[0].currentInputValue == 8)

        await mock.setVCPValue(0x60, display: "uuid-1", current: 5, max: 18)
        try await store.switchInput(monitorID: "uuid-1", to: 8)

        let log = await mock.writeLog
        #expect(log.count == 1)
        #expect(log[0].value == 8)
        #expect(store.monitors[0].currentInputValue == 8)
    }

    @Test("SwitchInput writes when discovery fails instead of trusting cache")
    func switchInputWritesAfterDiscoveryFailure() async throws {
        let (store, mock) = await makeStore()
        await store.discover()
        #expect(store.monitors[0].currentInputValue == 8)

        await mock.setShouldFailDiscovery(true)
        try await store.switchInput(monitorID: "uuid-1", to: 8)

        let log = await mock.writeLog
        #expect(log.count == 1)
        #expect(log[0].value == 8)
    }

    @Test("SwitchInput writes when input refresh fails instead of trusting cache")
    func switchInputWritesAfterInputReadFailure() async throws {
        let (store, mock) = await makeStore()
        await store.discover()
        #expect(store.monitors[0].currentInputValue == 8)

        await mock.setShouldFailRead(true)
        try await store.switchInput(monitorID: "uuid-1", to: 8)

        let log = await mock.writeLog
        #expect(log.count == 1)
        #expect(log[0].value == 8)
    }

    @Test("Discovery preserves user config for known monitors")
    func discoveryPreservesConfig() async {
        let (store, _) = await makeStore()
        await store.discover()
        store.updateDisplayName(monitorID: "uuid-1", name: "My Left Monitor")
        await store.discover()
        #expect(store.monitors.first(where: { $0.edidUUID == "uuid-1" })?.displayName == "My Left Monitor")
    }

    @Test("CurrentInputLabel resolves label from mappings")
    func currentInputLabel() async {
        let (store, _) = await makeStore()
        await store.discover()
        let label = store.currentInputLabel(for: store.monitors[0])
        #expect(label == "USB-C")
    }

    @Test("Persistence round-trips monitors via UserDefaults")
    func persistence() async {
        let suiteName = "test-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let mock = MockDDCService()
        await mock.configure(displays: makeTestDisplays())
        await mock.setVCPValue(0x60, display: "uuid-1", current: 8, max: 18)
        await mock.setVCPValue(0x60, display: "uuid-2", current: 19, max: 19)

        let store1 = MonitorStore(ddcService: mock, defaults: defaults)
        await store1.discover()
        #expect(store1.monitors.count == 2)

        let store2 = MonitorStore(ddcService: mock, defaults: defaults)
        #expect(store2.monitors.count == 2)
        #expect(store2.monitors[0].edidUUID == "uuid-1")
    }

    @Test("Discovery continues when readVCP fails for one monitor")
    func discoverContinuesOnPartialReadFailure() async {
        let mock = MockDDCService()
        let displays = makeTestDisplays()
        await mock.configure(displays: displays)
        await mock.setVCPValue(0x60, display: "uuid-1", current: 8, max: 18)
        await mock.setVCPValue(0x60, display: "uuid-2", current: 19, max: 19)
        await mock.setReadFailForDisplay("uuid-1")

        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let store = MonitorStore(ddcService: mock, defaults: defaults)
        await store.discover()

        #expect(store.monitors.count == 2)
        #expect(store.monitors[0].currentInputValue == nil)
        #expect(store.monitors[1].currentInputValue == 19)
    }

    @Test("Discovery clears cached inputs when display refresh fails")
    func discoveryClearsInputsOnFailure() async {
        let (store, mock) = await makeStore()
        await store.discover()
        #expect(store.monitors.allSatisfy { $0.currentInputValue != nil })

        await mock.setShouldFailDiscovery(true)
        await store.discover()

        #expect(store.monitors.allSatisfy { $0.currentInputValue == nil })
    }
}
