import Testing

@testable import Portage

@Suite("InputSource")
struct InputSourceTests {
    @Test("MSI returns MSI-specific mappings")
    func msiMappings() {
        let mappings = ManufacturerInputTable.defaultMappings(for: "MSI")
        #expect(mappings.count == 4)
        #expect(mappings.contains(where: { $0.ddcValue == 8 && $0.label == "USB-C" }))
    }

    @Test("BenQ returns BenQ-specific mappings")
    func benQMappings() {
        let mappings = ManufacturerInputTable.defaultMappings(for: "BNQ")
        #expect(mappings.count == 3)
        #expect(mappings.contains(where: { $0.ddcValue == 19 && $0.label == "USB-C" }))
    }

    @Test("Dell returns Dell-specific mappings")
    func dellMappings() {
        let mappings = ManufacturerInputTable.defaultMappings(for: "DEL")
        #expect(mappings.count == 5)
        #expect(mappings.contains(where: { $0.ddcValue == 27 && $0.label == "USB-C" }))
    }

    @Test("Unknown manufacturer falls back to standard MCCS")
    func unknownManufacturer() {
        let mappings = ManufacturerInputTable.defaultMappings(for: "UNKNOWN")
        #expect(mappings.count == 4)
        #expect(mappings.contains(where: { $0.ddcValue == 15 && $0.label == "DisplayPort-1" }))
        #expect(mappings.contains(where: { $0.ddcValue == 17 && $0.label == "HDMI-1" }))
    }
}

@Suite("Advertised input discovery")
struct AdvertisedInputTests {
    @Test func onlyAdvertisedPorts() {
        let result = ManufacturerInputTable.advertisedMappings("(prot(monitor)vcp(10 60(0F 11 12) D6(01 04)))", manufacturer: "DEL")
        #expect(result?.map(\.ddcValue) == [15, 17, 18])
    }
    @Test func unknownAndDuplicatePorts() {
        let result = ManufacturerInputTable.advertisedMappings("vcp(60(11 11 42))", manufacturer: "DEL")
        #expect(result?.map(\.ddcValue) == [17, 66])
        #expect(result?.last?.label == "Input 0x42")
    }
    @Test func missingCapabilitiesUseFallback() {
        #expect(ManufacturerInputTable.advertisedMappings("vcp(10 12)", manufacturer: "DEL") == nil)
        #expect(ManufacturerInputTable.advertisedMappings("vcp(60())", manufacturer: "DEL") == nil)
    }
}
