import Testing
@testable import Portage

@Suite("Advertised hardware capabilities")
struct DDCCapabilitiesTests {
    @Test func ignoresNestedInputAndPresetValues() {
        let features = DDCCapabilities.features(in: "(vcp(10 12 14(01 62 8D) 60(0F 11 12)))")
        #expect(features == Set([UInt8(0x10), 0x12, 0x14, 0x60]))
        #expect(features?.contains(0x62) == false)
    }
    @Test func handlesSpacingAndCase() {
        #expect(DDCCapabilities.features(in: "(VCP ( 10 12 62 8d ))") == Set([UInt8(0x10), 0x12, 0x62, 0x8D]))
    }
    @Test func refusesMalformedOrMissingList() {
        #expect(DDCCapabilities.features(in: "(prot(monitor))") == nil)
        #expect(DDCCapabilities.features(in: "vcp(10 62") == nil)
        #expect(DDCCapabilities.features(in: "vcp(zz)") == nil)
    }
}
