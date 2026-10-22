import Testing
@testable import Portage

@Suite("DDC transport and input replies")
struct DDCTransportTests {
    @Test("Only an identified MCDP29xx HDMI bridge uses the alternate transport address")
    func bridgeAddress() {
        #expect(AppleSiliconDDC.ddcChipAddress(providerClass: "AppleDCPMCDP29XX") == 0xB7)
        #expect(AppleSiliconDDC.ddcChipAddress(providerClass: "OtherHDMIProvider") == 0x37)
        #expect(AppleSiliconDDC.ddcChipAddress(providerClass: nil) == 0x37)
    }

    @Test("Bridge transport keeps the standard DDC packet and checksum")
    func packets() {
        #expect(AppleSiliconDDC.ddcPacket(opcode: 0x01, payload: [0x60]) == [0x82, 0x01, 0x60, 0xDC])
        #expect(AppleSiliconDDC.ddcPacket(opcode: 0x03, payload: [0x60, 0x00, 0x12]) == [0x84, 0x03, 0x60, 0x00, 0x12, 0xCA])
        let capabilities = AppleSiliconDDC.ddcPacket(opcode: 0xF3, payload: [0, 32])
        #expect(capabilities.prefix(4) == [0x83, 0xF3, 0, 32])
        #expect(capabilities.reduce(UInt8(0x6E ^ 0x51), ^) == 0)
    }

    @Test("Dell input replies use the low byte even when both bytes differ")
    func dellReplies() {
        #expect(ManufacturerInputTable.normalizedInputValue(0x1111, manufacturer: "DEL") == 17)
        #expect(ManufacturerInputTable.normalizedInputValue(0x1112, manufacturer: "DEL") == 18)
        #expect(ManufacturerInputTable.normalizedInputValue(0x110F, manufacturer: "DEL") == 15)
    }

    @Test("Other vendors retain distinct two-byte values")
    func otherReplies() {
        #expect(ManufacturerInputTable.normalizedInputValue(0x1234, manufacturer: "OTHER") == 0x1234)
        #expect(ManufacturerInputTable.normalizedInputValue(0x1111, manufacturer: "OTHER") == 17)
        #expect(ManufacturerInputTable.normalizedInputValue(18, manufacturer: "DEL") == 18)
    }
}
