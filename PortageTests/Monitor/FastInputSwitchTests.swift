import Foundation
import Testing
@testable import Portage

@Suite("Immediate input commands")
@MainActor
struct FastInputSwitchTests {
    private func setup() async -> (MonitorStore, MockDDCService) {
        let mock = MockDDCService()
        await mock.configure(displays: [DDCDisplayInfo(
            edidUUID: "fast", productName: "Test", manufacturer: "DEL", alphanumericSerial: "",
            advertisedInputs: [InputMapping(ddcValue: 17, label: "HDMI 1"), InputMapping(ddcValue: 15, label: "DisplayPort")])])
        await mock.setVCPValue(0x60, display: "fast", current: 17, max: 255)
        await mock.setVCPValue(0x10, display: "fast", current: 50, max: 100)
        let store = MonitorStore(ddcService: mock, defaults: UserDefaults(suiteName: "test-fast-\(UUID())")!)
        await store.discover()
        return (store, mock)
    }

    @Test("Direct switching writes first without discovery or unrelated reads")
    func directWriteFirst() async throws {
        let (store, mock) = await setup()
        let start = await mock.operations.count
        try await store.switchInput(monitorID: "fast", to: 15)
        #expect(Array(await mock.operations.dropFirst(start)) == [.write("fast", 0x60, 15), .read("fast", 0x60)])
        #expect(await mock.discoveryCount == 1)
    }

    @Test("Cycling writes first using the last known input")
    func cycleWriteFirst() async throws {
        let (store, mock) = await setup()
        let start = await mock.operations.count
        try await store.cycleInput(monitorID: "fast")
        #expect(Array(await mock.operations.dropFirst(start)) == [.write("fast", 0x60, 15), .read("fast", 0x60)])
        #expect(await mock.discoveryCount == 1)
    }

    @Test("A missing service reconnects only after the first write attempt")
    func reconnectOnlyWhenNecessary() async throws {
        let (store, mock) = await setup()
        await mock.setNextWriteUnavailable()
        let start = await mock.operations.count
        try await store.switchInput(monitorID: "fast", to: 15)
        #expect(Array(await mock.operations.dropFirst(start)) == [
            .write("fast", 0x60, 15), .discover, .write("fast", 0x60, 15), .read("fast", 0x60)
        ])
    }

    @Test("Cycling does not wait for a pending refresh or lose its new input state")
    func pendingRefreshDoesNotBlockOrOverwrite() async throws {
        let (store, mock) = await setup()
        await mock.pauseRead(0x10)
        let refresh = Task { await store.discover() }
        while !(await mock.isReadPaused) { await Task.yield() }
        let start = await mock.operations.count
        do {
            try await store.cycleInput(monitorID: "fast")
        } catch {
            await mock.resumeRead()
            await refresh.value
            throw error
        }
        #expect(store.isDiscovering)
        #expect(Array(await mock.operations.dropFirst(start)) == [.write("fast", 0x60, 15), .read("fast", 0x60)])
        #expect(store.monitors.first?.currentInputValue == 15)
        await mock.resumeRead()
        await refresh.value
        #expect(store.monitors.first?.currentInputValue == 15)
        #expect(store.monitors.first?.lastSelectedInputValue == 15)
    }
}
