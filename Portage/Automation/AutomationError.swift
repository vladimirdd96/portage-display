import Foundation

enum AutomationError: Error, LocalizedError, Sendable {
    case monitorNotFound(query: String, available: [String])
    case ambiguousMonitorName(name: String, matchingIDs: [String])
    case presetNotFound(query: String, available: [String])
    case inputNotFound(label: String, monitor: String, available: [String])
    case discoveryFailed
    case activationFailed(detail: String)

    var errorDescription: String? {
        switch self {
        case .monitorNotFound(let query, let available):
            "Monitor '\(query)' not found. Available: \(available.joined(separator: ", "))"
        case .ambiguousMonitorName(let name, let matchingIDs):
            "Multiple monitors named '\(name)'. Use UUID to disambiguate: \(matchingIDs.joined(separator: ", "))"
        case .presetNotFound(let query, let available):
            "Preset '\(query)' not found. Available: \(available.joined(separator: ", "))"
        case .inputNotFound(let label, let monitor, let available):
            "Input '\(label)' not found on '\(monitor)'. Available: \(available.joined(separator: ", "))"
        case .discoveryFailed:
            "Monitor discovery failed"
        case .activationFailed(let detail):
            "Preset activation failed: \(detail)"
        }
    }

    var sanitizedDescription: String {
        switch self {
        case .monitorNotFound(let query, _):
            "Monitor '\(query)' not found"
        case .ambiguousMonitorName(let name, _):
            "Multiple monitors named '\(name)' — use UUID to disambiguate"
        case .presetNotFound(let query, _):
            "Preset '\(query)' not found"
        case .inputNotFound(let label, let monitor, _):
            "Input '\(label)' not found on '\(monitor)'"
        case .discoveryFailed:
            "Monitor discovery failed"
        case .activationFailed(let detail):
            "Preset activation failed: \(detail)"
        }
    }
}
