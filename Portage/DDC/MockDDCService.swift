import Foundation

actor MockDDCService: DDCService {
    var displays: [DDCDisplayInfo] = []
    var values: [String: [UInt8: (current: UInt16, max: UInt16)]] = [:]
    var shouldFailWrite = false
    var shouldFailRead = false
    var shouldFailDiscovery = false
    var readFailDisplays: Set<String> = []
    var shouldRejectWriteSilently = false
    var writeLog: [(display: String, vcp: UInt8, value: UInt16)] = []
    var discoveryCount = 0
    var discoveryDelay: Duration?

    func configure(displays: [DDCDisplayInfo]) {
        self.displays = displays
    }

    func setVCPValue(_ vcp: UInt8, display: String, current: UInt16, max: UInt16) {
        values[display, default: [:]][vcp] = (current, max)
    }

    func setShouldFailWrite(_ fail: Bool) {
        shouldFailWrite = fail
    }

    func setShouldFailRead(_ fail: Bool) {
        shouldFailRead = fail
    }

    func setShouldFailDiscovery(_ fail: Bool) {
        shouldFailDiscovery = fail
    }

    func setReadFailForDisplay(_ display: String) {
        readFailDisplays.insert(display)
    }

    func setShouldRejectWriteSilently(_ reject: Bool) {
        shouldRejectWriteSilently = reject
    }

    func setDiscoveryDelay(_ delay: Duration?) {
        discoveryDelay = delay
    }

    func discoverDisplays() async throws -> [DDCDisplayInfo] {
        discoveryCount += 1
        if let discoveryDelay {
            try? await Task.sleep(for: discoveryDelay)
        }
        if shouldFailDiscovery {
            throw DDCError.communicationFailed(monitor: "discovery")
        }
        return displays
    }

    func readVCP(_ vcp: UInt8, display: String) async throws -> (current: UInt16, max: UInt16) {
        if shouldFailRead || readFailDisplays.contains(display) { throw DDCError.readFailed(vcp: vcp, monitor: display) }
        guard let val = values[display]?[vcp] else {
            throw DDCError.readFailed(vcp: vcp, monitor: display)
        }
        return val
    }

    func writeVCP(_ vcp: UInt8, value: UInt16, display: String) async throws {
        if shouldFailWrite { throw DDCError.writeFailed(vcp: vcp, value: value, monitor: display) }
        writeLog.append((display, vcp, value))
        if !shouldRejectWriteSilently {
            values[display, default: [:]][vcp] = (value, values[display]?[vcp]?.max ?? 255)
        }
    }
}
