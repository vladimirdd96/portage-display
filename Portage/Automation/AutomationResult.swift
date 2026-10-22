import Foundation

struct MonitorInfo: Sendable {
    let id: String
    let name: String
    let currentInput: String?
    let currentInputValue: UInt16?
    let availableInputs: [String]
}

struct PresetInfo: Sendable {
    let id: UUID
    let name: String
    let assignmentCount: Int
}

struct SwitchResult: Sendable {
    let monitorName: String
    let inputLabel: String
}

struct ActivateResult: Sendable {
    let presetName: String
}
