import Foundation
import os

private let logger = Logger(subsystem: "com.github.vladimirdd96.PortageDisplay", category: "ddc.discovery")

final class LiveDDCService: DDCService, @unchecked Sendable {
    private var capabilitiesCache: [String: String] = [:]
    private var buses: [String: DisplayBus] = [:]

    func discoverDisplays() async throws -> [DDCDisplayInfo] {
        var displayCount: UInt32 = 0
        CGGetActiveDisplayList(0, nil, &displayCount)
        var displayIDs = [CGDirectDisplayID](repeating: 0, count: Int(displayCount))
        CGGetActiveDisplayList(displayCount, &displayIDs, &displayCount)
        logger.info("CGGetActiveDisplayList returned \(displayCount) displays")

        let matchedServices = AppleSiliconDDC.getServiceMatches(displayIDs: displayIDs)
        logger.info("getServiceMatches returned \(matchedServices.count) matched services")

        var infos: [DDCDisplayInfo] = displayIDs.filter { CGDisplayIsBuiltin($0) != 0 }.map {
            DDCDisplayInfo(edidUUID: "native-\($0)", productName: "Built-in Display", manufacturer: "Apple", alphanumericSerial: "", advertisedInputs: [], systemDisplayID: $0)
        }
        var newBuses: [String: DisplayBus] = [:]

        for matched in matchedServices {
            var details = matched.serviceDetails
            guard matched.service != nil else {
                logger.debug("Skipping service with nil IOAVService: \(details.productName, privacy: .public)")
                continue
            }
            guard !details.edidUUID.isEmpty else {
                logger.debug("Skipping service with empty EDID UUID: \(details.productName, privacy: .public)")
                continue
            }
            guard !matched.dummy else {
                logger.debug("Skipping dummy display: \(details.productName, privacy: .public)")
                continue
            }

            var info = DDCDisplayInfo(
                edidUUID: details.edidUUID,
                productName: details.productName,
                manufacturer: details.manufacturerID,
                alphanumericSerial: details.alphanumericSerialNumber
            )
            info.systemDisplayID = matched.displayID == 0 ? nil : matched.displayID
            let capabilities = capabilitiesCache[info.edidUUID] ?? AppleSiliconDDC.capabilities(service: matched.service, chipAddress: details.ddcChipAddress)
            if let capabilities {
                capabilitiesCache[info.edidUUID] = capabilities
                info.advertisedInputs = ManufacturerInputTable.advertisedMappings(capabilities, manufacturer: info.manufacturer)
                info.supportedVCP = DDCCapabilities.features(in: capabilities)
            }
            infos.append(info)

            // Health check: probe I2C to detect broken services early
            var probe = [UInt8](repeating: 0, count: 1)
            let probeResult = IOAVServiceReadI2C(matched.service, details.ddcChipAddress, UInt32(ARM64_DDC_DATA_ADDRESS), &probe, 1)
            if probeResult != 0 {
                logger.warning("IOAVService I2C unavailable for \(details.productName, privacy: .public) (error=\(probeResult)), skipping DDC for this display")
            } else {
                let bus = DisplayBus(ioregService: details, info: info)
                newBuses[info.edidUUID] = bus
            }
            logger.info("Matched display: \(details.productName, privacy: .public) (\(details.manufacturerID, privacy: .public)) uuid=\(details.edidUUID, privacy: .public) score=\(matched.matchScore) displayID=\(matched.displayID) ddc=\(probeResult == 0)")
        }

        let activeIDs = Set(infos.map(\.edidUUID))
        capabilitiesCache = capabilitiesCache.filter { activeIDs.contains($0.key) }
        buses = newBuses
        logger.info("Discovery complete: \(infos.count) displays matched")
        return infos
    }

    func readVCP(_ vcp: UInt8, display: String) async throws -> (current: UInt16, max: UInt16) {
        if display.hasPrefix("native-"), let id = UInt32(display.dropFirst(7)) {
            guard vcp == 0x10, let brightness = NativeBrightness.read(id) else {
                throw DDCError.readFailed(vcp: vcp, monitor: display)
            }
            return (UInt16((brightness * 1000).rounded()), 1000)
        }
        guard let bus = buses[display] else {
            throw DDCError.serviceUnavailable(monitor: display)
        }
        let result = try await bus.read(vcp: vcp)
        let normalized = ManufacturerInputTable.normalizedInputValue(
            result.current, manufacturer: bus.info.manufacturer)
        if vcp == VCP_INPUT_SOURCE { return (normalized, result.max) }
        return result
    }

    func writeVCP(_ vcp: UInt8, value: UInt16, display: String) async throws {
        if display.hasPrefix("native-"), let id = UInt32(display.dropFirst(7)) {
            guard vcp == 0x10, NativeBrightness.write(id, value: Float(value) / 1000) else {
                throw DDCError.writeFailed(vcp: vcp, value: value, monitor: display)
            }
            return
        }
        guard let bus = buses[display] else {
            throw DDCError.serviceUnavailable(monitor: display)
        }
        try await bus.write(vcp: vcp, value: value)
    }
}
