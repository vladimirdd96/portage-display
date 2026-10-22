import Foundation

struct MonitorConfig: Codable, Identifiable, Sendable {
    var id: String { edidUUID }
    let edidUUID: String
    let alphanumericSerial: String
    var displayName: String
    let manufacturer: String
    var inputMappings: [InputMapping]
    var currentInputValue: UInt16?
    var systemDisplayID: UInt32?
    var brightnessValue: Double?
    var brightnessMaximum: UInt16?
    var hardwareLevels: [String: Double]?
    var hardwareMaximums: [String: UInt16]?
    var cycleInputValues: [UInt16]?
    var lastSelectedInputValue: UInt16?
    var isMuted: Bool?
    var orderedCycleInputs: [InputMapping] {
        let values = cycleInputValues ?? inputMappings.map(\.ddcValue)
        var seen = Set<UInt16>()
        return values.compactMap { value in
            guard seen.insert(value).inserted else { return nil }
            return inputMappings.first { $0.ddcValue == value }
        }
    }
    var isBuiltIn: Bool { edidUUID.hasPrefix("native-") }
}
