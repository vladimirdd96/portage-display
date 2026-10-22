import Foundation

/// Optional controls: omitted values leave that setting unchanged.
struct PresetDisplaySettings: Codable, Identifiable, Sendable {
    var id: String { monitorEdidUUID }
    var monitorEdidUUID: String
    var displayName: String
    var brightness: Double?
    var contrast: Double?
    var volume: Double?
    var muted: Bool?
    var colorPreset: UInt16?
    var rgbGains: [String: Double]?
    var colorProfilePath: String?
    var colorProfileName: String?

    var isEmpty: Bool {
        brightness == nil && contrast == nil && volume == nil && muted == nil && colorPreset == nil && (rgbGains ?? [:]).isEmpty && colorProfilePath == nil
    }
    var summary: String {
        var parts: [String] = []
        if let brightness { parts.append("Brightness \(Int((brightness * 100).rounded()))%") }
        if contrast != nil { parts.append("Contrast") }
        if volume != nil { parts.append("Volume") }
        if muted != nil { parts.append("Mute") }
        if let colorPreset { parts.append(MonitorColorPreset.label(colorPreset)) }
        if !(rgbGains ?? [:]).isEmpty { parts.append("RGB gain") }
        if let colorProfileName { parts.append(colorProfileName) }
        return parts.joined(separator: ", ")
    }
}
