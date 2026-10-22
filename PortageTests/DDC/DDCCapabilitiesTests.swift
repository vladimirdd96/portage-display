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
    @Test func readsOnlyTopLevelAdvertisedColorPresets() {
        #expect(DDCCapabilities.values(for: 0x14, in: "vcp(60(14 01) 14 (01 05 08 0B 0C) 16 18 1A)") == [1, 5, 8, 11, 12])
        #expect(DDCCapabilities.values(for: 0x14, in: "vcp(60(14 01) 16)").isEmpty)
        #expect(DDCCapabilities.values(for: 0x14, in: "vcp(14(01 05)").isEmpty)
    }

}
