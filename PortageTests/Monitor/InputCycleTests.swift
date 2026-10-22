import Foundation
import Testing
@testable import Portage

@Suite("Input cycling")
@MainActor
struct InputCycleTests {
    private func setup(current: UInt16 = 17) async -> (MonitorStore, MockDDCService, UserDefaults) {
        let mock = MockDDCService()
        await mock.configure(displays: [DDCDisplayInfo(edidUUID: "cycle-test", productName: "Test", manufacturer: "DEL", alphanumericSerial: "", advertisedInputs: [
            InputMapping(ddcValue: 17, label: "HDMI 1"), InputMapping(ddcValue: 18, label: "HDMI 2"), InputMapping(ddcValue: 15, label: "DP")
        ])])
        await mock.setVCPValue(0x60, display: "cycle-test", current: current, max: 255)
        let defaults = UserDefaults(suiteName: "test-cycle-\(UUID())")!
        let store = MonitorStore(ddcService: mock, defaults: defaults)
        await store.discover()
        return (store, mock, defaults)
    }

    @Test func cyclesAllInputsAndWraps() async throws {
        let (store, mock, _) = await setup()
        for _ in 0..<3 { try await store.cycleInput(monitorID: "cycle-test") }
        #expect(await mock.writeLog.map(\.value) == [18, 15, 17])
    }

    @Test func subsetUsesCustomOrderAndPersists() async throws {
        let (store, mock, defaults) = await setup()
        store.updateCycleInputs(monitorID: "cycle-test", values: [15, 17])
        let restored = MonitorStore(ddcService: mock, defaults: defaults)
        #expect(restored.monitors.first?.orderedCycleInputs.map(\.ddcValue) == [15, 17])
        try await restored.cycleInput(monitorID: "cycle-test")
        try await restored.cycleInput(monitorID: "cycle-test")
        #expect(await mock.writeLog.map(\.value) == [15, 17])
    }

    @Test func outsideCycleStartsAtFirstInput() async throws {
        let (store, mock, _) = await setup(current: 18)
        store.updateCycleInputs(monitorID: "cycle-test", values: [15, 17])
        try await store.cycleInput(monitorID: "cycle-test")
        #expect(await mock.writeLog.map(\.value) == [15])
    }

    @Test func failedReadUsesLastSelectedInput() async throws {
        let (store, mock, _) = await setup()
        await mock.setShouldFailRead(true)
        await #expect(throws: DDCError.self) { try await store.cycleInput(monitorID: "cycle-test") }
        await #expect(throws: DDCError.self) { try await store.cycleInput(monitorID: "cycle-test") }
        #expect(await mock.writeLog.map(\.value) == [18, 15])
    }

    @Test func duplicateAndRemovedInputsAreSkipped() async throws {
        let (store, mock, _) = await setup()
        store.updateCycleInputs(monitorID: "cycle-test", values: [17, 17, 99, 15])
        #expect(store.monitors.first?.orderedCycleInputs.map(\.ddcValue) == [17, 15])
        try await store.cycleInput(monitorID: "cycle-test")
        #expect(await mock.writeLog.map(\.value) == [15])
    }

    @Test func fewerThanTwoInputsDoesNotWrite() async throws {
        let (store, mock, _) = await setup()
        for values: [UInt16] in [[], [17]] {
            store.updateCycleInputs(monitorID: "cycle-test", values: values)
            await #expect(throws: MonitorStore.CycleError.self) { try await store.cycleInput(monitorID: "cycle-test") }
        }
        #expect(await mock.writeLog.isEmpty)
    }

    @Test func repeatedPressDuringSwitchDoesNotOverlap() async throws {
        let (store, mock, _) = await setup()
        async let first: Void = store.cycleInput(monitorID: "cycle-test")
        async let second: Void = store.cycleInput(monitorID: "cycle-test")
        _ = try await (first, second)
        #expect(await mock.writeLog.count == 1)
    }

    @Test func rejectedSwitchDoesNotAdvanceFallback() async throws {
        let (store, mock, _) = await setup()
        await mock.setShouldRejectWriteSilently(true)
        await #expect(throws: DDCError.self) { try await store.cycleInput(monitorID: "cycle-test") }
        #expect(store.monitors.first?.lastSelectedInputValue == 17)
        await mock.setShouldRejectWriteSilently(false)
        try await store.cycleInput(monitorID: "cycle-test")
        #expect(await mock.writeLog.map(\.value) == [18, 18])
    }
}
