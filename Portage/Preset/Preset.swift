import Foundation

struct PresetAssignment: Codable, Identifiable, Sendable {
    let id: UUID
    var monitorEdidUUID: String
    var targetInputValue: UInt16
    var targetInputLabel: String

    init(monitorEdidUUID: String, targetInputValue: UInt16, targetInputLabel: String) {
        self.id = UUID()
        self.monitorEdidUUID = monitorEdidUUID
        self.targetInputValue = targetInputValue
        self.targetInputLabel = targetInputLabel
    }
}

struct Preset: Codable, Identifiable, Sendable {
    let id: UUID
    var name: String
    var assignments: [PresetAssignment]
    var hotkeyName: String?
    var displaySettings: [PresetDisplaySettings]?

    var displayCount: Int { Set(assignments.map(\.monitorEdidUUID) + (displaySettings ?? []).map(\.monitorEdidUUID)).count }

    init(name: String, assignments: [PresetAssignment] = []) {
        self.id = UUID()
        self.name = name
        self.assignments = assignments
    }
}
