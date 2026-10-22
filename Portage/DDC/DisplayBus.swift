import Foundation
import os

nonisolated(unsafe) private let logger = Logger(subsystem: "com.github.vladimirdd96.PortageDisplay", category: "ddc.bus")

struct DDCRetryConfig: Sendable {
    let maxAttempts: Int
    let initialDelay: UInt32
    let backoffMultiplier: Double
    let maxDelay: UInt32

    nonisolated(unsafe) static let production = DDCRetryConfig(
        maxAttempts: 3,
        initialDelay: 200_000,
        backoffMultiplier: 1.5,
        maxDelay: 600_000
    )
}

actor DisplayBus {
    nonisolated let info: DDCDisplayInfo
    private let ioregService: AppleSiliconDDC.IOregService
    private let retryConfig: DDCRetryConfig

    init(
        ioregService: AppleSiliconDDC.IOregService, info: DDCDisplayInfo,
        retryConfig: DDCRetryConfig = .production
    ) {
        self.ioregService = ioregService
        self.info = info
        self.retryConfig = retryConfig
    }

    func read(vcp: UInt8) throws -> (current: UInt16, max: UInt16) {
        var delay = retryConfig.initialDelay
        for attempt in 1...retryConfig.maxAttempts {
            if let result = AppleSiliconDDC.read(service: ioregService.service, command: vcp, chipAddress: ioregService.ddcChipAddress) {
                if attempt > 1 {
                    logger.info("VCP 0x\(String(vcp, radix: 16)) read succeeded on backoff attempt \(attempt) for \(self.info.edidUUID, privacy: .public)")
                }
                return result
            }
            guard attempt < retryConfig.maxAttempts else { break }
            logger.debug("VCP 0x\(String(vcp, radix: 16)) read failed, backing off \(delay/1000)ms for \(self.info.edidUUID, privacy: .public)")
            usleep(delay)
            delay = min(UInt32(Double(delay) * retryConfig.backoffMultiplier), retryConfig.maxDelay)
        }
        logger.warning("VCP 0x\(String(vcp, radix: 16)) read failed after \(self.retryConfig.maxAttempts) backoff attempts for \(self.info.edidUUID, privacy: .public)")
        throw DDCError.readFailed(vcp: vcp, monitor: info.edidUUID)
    }

    func write(vcp: UInt8, value: UInt16) throws {
        let ok = AppleSiliconDDC.write(service: ioregService.service, command: vcp, value: value, chipAddress: ioregService.ddcChipAddress)
        guard ok else {
            throw DDCError.writeFailed(vcp: vcp, value: value, monitor: info.edidUUID)
        }
    }
}
