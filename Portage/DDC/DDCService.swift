import Foundation

enum DDCError: Error, Sendable, LocalizedError {
    case communicationFailed(monitor: String)
    case readFailed(vcp: UInt8, monitor: String)
    case writeFailed(vcp: UInt8, value: UInt16, monitor: String)
    case serviceUnavailable(monitor: String)
    case switchRejected(monitor: String, requested: UInt16, actual: UInt16)

    var isSwitchRejected: Bool {
        if case .switchRejected = self { return true }
        return false
    }

    var errorDescription: String? {
        switch self {
        case .communicationFailed:
            "DDC communication failed"
        case .readFailed:
            "Failed to read monitor value"
        case .writeFailed:
            "Failed to write monitor value"
        case .serviceUnavailable:
            "Monitor service unavailable"
        case .switchRejected:
            "Input switch was rejected by the monitor"
        }
    }
}

struct DDCDisplayInfo: Sendable, Identifiable {
    let edidUUID: String
    let productName: String
    let manufacturer: String
    let alphanumericSerial: String
    var advertisedInputs: [InputMapping]? = nil
    var systemDisplayID: UInt32? = nil
    var supportedVCP: Set<UInt8>? = nil
    var id: String { edidUUID }
}

nonisolated protocol DDCService: Sendable {
    func discoverDisplays() async throws -> [DDCDisplayInfo]
    func readVCP(_ vcp: UInt8, display: String) async throws -> (current: UInt16, max: UInt16)
    func writeVCP(_ vcp: UInt8, value: UInt16, display: String) async throws
}
