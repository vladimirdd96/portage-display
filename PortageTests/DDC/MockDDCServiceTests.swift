import Testing
@testable import Portage

@Suite("MockDDCService")
struct MockDDCServiceTests {
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

    @Test("Returns configured displays")
    func discoverDisplays() async throws {
        let mock = MockDDCService()
        let displays = makeTestDisplays()
        await mock.configure(displays: displays)

        let discovered = try await mock.discoverDisplays()
        #expect(discovered.count == 2)
        #expect(discovered[0].edidUUID == "uuid-1")
        #expect(discovered[1].productName == "BenQ MA270U")
    }

    @Test("Reads configured VCP values")
    func readVCP() async throws {
        let mock = MockDDCService()
        await mock.setVCPValue(0x60, display: "uuid-1", current: 8, max: 18)

        let result = try await mock.readVCP(0x60, display: "uuid-1")
        #expect(result.current == 8)
        #expect(result.max == 18)
    }

    @Test("Read throws for unconfigured display")
    func readVCPUnconfigured() async {
        let mock = MockDDCService()

        await #expect(throws: DDCError.self) {
            try await mock.readVCP(0x60, display: "nonexistent")
        }
    }

    @Test("Write updates stored value and logs")
    func writeVCP() async throws {
        let mock = MockDDCService()
        await mock.setVCPValue(0x60, display: "uuid-1", current: 5, max: 18)

        try await mock.writeVCP(0x60, value: 8, display: "uuid-1")

        let result = try await mock.readVCP(0x60, display: "uuid-1")
        #expect(result.current == 8)

        let log = await mock.writeLog
        #expect(log.count == 1)
        #expect(log[0].display == "uuid-1")
        #expect(log[0].vcp == 0x60)
        #expect(log[0].value == 8)
    }

    @Test("Write failure throws correct error")
    func writeVCPFailure() async {
        let mock = MockDDCService()
        await mock.configure(displays: makeTestDisplays())
        await mock.setShouldFailWrite(true)

        await #expect(throws: DDCError.self) {
            try await mock.writeVCP(0x60, value: 8, display: "uuid-1")
        }
    }

    @Test("Read failure throws correct error")
    func readVCPFailure() async {
        let mock = MockDDCService()
        await mock.setVCPValue(0x60, display: "uuid-1", current: 8, max: 18)
        await mock.setShouldFailRead(true)

        await #expect(throws: DDCError.self) {
            try await mock.readVCP(0x60, display: "uuid-1")
        }
    }
}
