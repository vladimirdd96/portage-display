//  Copyright © @waydabber

import Foundation
import IOKit
import os

nonisolated(unsafe) private let logger = Logger(subsystem: "com.github.vladimirdd96.PortageDisplay", category: "ddc")

let ARM64_DDC_7BIT_ADDRESS: UInt8 = 0x37 // This works with DisplayPort devices
let ARM64_DDC_DATA_ADDRESS: UInt8 = 0x51

nonisolated public class AppleSiliconDDC: NSObject {
  #if arch(arm64)
    public static let isArm64: Bool = true
  #else
    public static let isArm64: Bool = false
  #endif
  static let MAX_MATCH_SCORE: Int = 20

  public struct IOregService {
    public var edidUUID: String = ""
    public var manufacturerID: String = ""
    public var productName: String = ""
    public var serialNumber: Int64 = 0
    public var alphanumericSerialNumber: String = ""
    public var location: String = ""
    public var ioDisplayLocation: String = ""
    public var transportUpstream: String = ""
    public var transportDownstream: String = ""
    public var service: IOAVService?
    public var serviceLocation: Int = 0
    public var ddcChipAddress: UInt32 = 0x37
    public var displayAttributes: NSDictionary?
  }

  public struct Arm64Service {
    var displayID: CGDirectDisplayID = 0
    var service: IOAVService?
    var serviceLocation: Int = 0
    var discouraged: Bool = false
    var dummy: Bool = false
    var serviceDetails: IOregService
    var matchScore: Int = 0
  }

  static func getServiceMatches(displayIDs: [CGDirectDisplayID]) -> [Arm64Service] {
    let ioregServicesForMatching = self.getIoregServicesForMatching()
    var matchedDisplayServices: [Arm64Service] = []
    var scoredCandidateDisplayServices: [Int: [Arm64Service]] = [:]
    for displayID in displayIDs {
      for ioregServiceForMatching in ioregServicesForMatching {
        let score = self.ioregMatchScore(displayID: displayID, ioregEdidUUID: ioregServiceForMatching.edidUUID, ioDisplayLocation: ioregServiceForMatching.ioDisplayLocation, ioregProductName: ioregServiceForMatching.productName, ioregSerialNumber: ioregServiceForMatching.serialNumber, serviceLocation: ioregServiceForMatching.serviceLocation)
        let discouraged = self.checkIfDiscouraged(ioregService: ioregServiceForMatching)
        let dummy = self.checkIfDummy(ioregService: ioregServiceForMatching)
        let displayService = Arm64Service(displayID: displayID, service: ioregServiceForMatching.service, serviceLocation: ioregServiceForMatching.serviceLocation, discouraged: discouraged, dummy: dummy, serviceDetails: ioregServiceForMatching, matchScore: score)
        if scoredCandidateDisplayServices[score] == nil {
          scoredCandidateDisplayServices[score] = []
        }
        scoredCandidateDisplayServices[score]?.append(displayService)
      }
    }
    var takenServiceLocations: [Int] = []
    var takenDisplayIDs: [CGDirectDisplayID] = []
    for score in stride(from: self.MAX_MATCH_SCORE, to: 0, by: -1) {
      if let scoredCandidateDisplayService = scoredCandidateDisplayServices[score] {
        for candidateDisplayService in scoredCandidateDisplayService where !(takenDisplayIDs.contains(candidateDisplayService.displayID) || takenServiceLocations.contains(candidateDisplayService.serviceLocation)) {
          takenDisplayIDs.append(candidateDisplayService.displayID)
          takenServiceLocations.append(candidateDisplayService.serviceLocation)
          matchedDisplayServices.append(candidateDisplayService)
        }
      }
    }
    return matchedDisplayServices
  }

  static func isValidVCPReply(_ reply: [UInt8], for command: UInt8) -> Bool {
    guard reply.count >= 11 else { return false }
    guard reply[0] == 0x6E else { return false } // source address
    guard reply[1] == 0x88 else { return false } // length: 0x80 | 8
    guard reply[2] == 0x02 else { return false } // GET VCP Feature Reply opcode
    guard reply[4] == command else { return false } // VCP code matches request
    return true
  }

  static public func read(service: IOAVService?, command: UInt8, chipAddress: UInt32 = 0x37, writeSleepTime: UInt32? = nil, numOfWriteCycles: UInt8? = nil, readSleepTime: UInt32? = nil, numOfRetryAttemps: UInt8? = nil, retrySleepTime: UInt32? = nil) -> (current: UInt16, max: UInt16)? {
    var values: (UInt16, UInt16)?
    var send: [UInt8] = [command]
    var reply = [UInt8](repeating: 0, count: 11)
    if Self.performDDCCommunication(service: service, send: &send, reply: &reply, chipAddress: chipAddress, writeSleepTime: writeSleepTime, numOfWriteCycles: numOfWriteCycles ?? 1, readSleepTime: readSleepTime, numOfRetryAttemps: numOfRetryAttemps, retrySleepTime: retrySleepTime) {
      guard isValidVCPReply(reply, for: command) else {
        logger.warning("DDC reply passed checksum but VCP header mismatch: expected=0x\(String(command, radix: 16)) got=0x\(String(reply[4], radix: 16))")
        return nil
      }
      let max = UInt16(reply[6]) * 256 + UInt16(reply[7])
      let current = UInt16(reply[8]) * 256 + UInt16(reply[9])
      values = (current, max)
    } else {
      values = nil
    }
    return values
  }

  // Read the monitor's advertised ports, without probing or switching any input.
  static func capabilities(service: IOAVService?, chipAddress: UInt32 = 0x37) -> String? {
    guard let service else { return nil }
    var bytes: [UInt8] = []
    for _ in 0..<128 {
      let offset = bytes.count
      var packet = ddcPacket(opcode: 0xF3, payload: [UInt8(offset >> 8), UInt8(offset & 255)])
      var fragment: [UInt8]?
      for _ in 0..<3 {
        guard IOAVServiceWriteI2C(service, chipAddress, 0x51, &packet, UInt32(packet.count)) == 0 else { continue }
        usleep(100_000)
        var reply = [UInt8](repeating: 0, count: 38)
        guard IOAVServiceReadI2C(service, chipAddress, 0x51, &reply, UInt32(reply.count)) == 0 else { continue }
        let length = Int(reply[1] & 0x7F)
        guard reply[0] == 0x6E, length >= 3, length + 3 <= reply.count,
              reply[2] == 0xE3, Int(reply[3]) * 256 + Int(reply[4]) == offset,
              reply.prefix(length + 3).reduce(UInt8(0x50), ^) == 0 else { continue }
        fragment = Array(reply[5..<(length + 2)])
        break
      }
      guard let fragment else { return nil }
      if fragment.isEmpty { return String(bytes: bytes, encoding: .ascii) }
      if let end = fragment.firstIndex(of: 0) {
        bytes.append(contentsOf: fragment[..<end])
        return String(bytes: bytes, encoding: .ascii)
      }
      bytes.append(contentsOf: fragment)
    }
    return nil
  }

  static public func write(service: IOAVService?, command: UInt8, value: UInt16, chipAddress: UInt32 = 0x37, writeSleepTime: UInt32? = nil, numOfWriteCycles: UInt8? = nil, numOfRetryAttemps: UInt8? = nil, retrySleepTime: UInt32? = nil) -> Bool {
    var send: [UInt8] = [command, UInt8(value >> 8), UInt8(value & 255)]
    var reply: [UInt8] = []
    return Self.performDDCCommunication(service: service, send: &send, reply: &reply, chipAddress: chipAddress, writeSleepTime: writeSleepTime, numOfWriteCycles: numOfWriteCycles, numOfRetryAttemps: numOfRetryAttemps, retrySleepTime: retrySleepTime)
  }

  static func interpretReadResult(writeSucceeded: Bool, readReturnCode: Int32, reply: inout [UInt8]) -> Bool {
    guard !reply.isEmpty else { return writeSucceeded }
    guard readReturnCode == 0 else { return false }
    return checksum(chk: 0x50, data: &reply, start: 0, end: reply.count - 2) == reply[reply.count - 1]
  }

  static func performDDCCommunication(service: IOAVService?, send: inout [UInt8], reply: inout [UInt8], chipAddress: UInt32 = 0x37, writeSleepTime: UInt32? = nil, numOfWriteCycles: UInt8? = nil, readSleepTime: UInt32? = nil, numOfRetryAttemps: UInt8? = nil, retrySleepTime: UInt32? = nil) -> Bool {
    let dataAddress = ARM64_DDC_DATA_ADDRESS
    var success = false
    guard service != nil else {
      return success
    }
    var packet = ddcPacket(opcode: reply.isEmpty ? 0x03 : 0x01, payload: send)
    let totalAttempts = Int(numOfRetryAttemps ?? 4) + 1
    let isRead = !reply.isEmpty

    // Flush stale data from the I2C bus before sending the command
    if isRead {
      var flush = [UInt8](repeating: 0, count: 11)
      IOAVServiceReadI2C(service, chipAddress, UInt32(dataAddress), &flush, UInt32(flush.count))
      usleep(10000)
    }

    for attempt in 1 ... totalAttempts {
      for _ in 1 ... max((numOfWriteCycles ?? 2) + 0, 1) {
        usleep(writeSleepTime ?? 20000)
        let writeResult = IOAVServiceWriteI2C(service, chipAddress, UInt32(dataAddress), &packet, UInt32(packet.count))
        success = writeResult == 0
        logger.debug("I2C write attempt \(attempt)/\(totalAttempts): result=\(writeResult)")
      }
      if isRead {
        // Try multiple reads per write — the DDC response may arrive after bus noise
        for readPass in 1 ... 3 {
          usleep(readPass == 1 ? (readSleepTime ?? 100000) : 50000)
          let readResult = IOAVServiceReadI2C(service, chipAddress, UInt32(dataAddress), &reply, UInt32(reply.count))
          success = interpretReadResult(writeSucceeded: success, readReturnCode: readResult, reply: &reply)
          let replyHex = reply.map { String(format: "%02X", $0) }.joined(separator: " ")
          logger.debug("I2C read attempt \(attempt)/\(totalAttempts) pass \(readPass): result=\(readResult) checksum_ok=\(success) reply=[\(replyHex)]")
          if success { break }
        }
      }
      if success {
        logger.info("DDC \(isRead ? "read" : "write") succeeded on attempt \(attempt)/\(totalAttempts)")
        return success
      }
      usleep(retrySleepTime ?? 40000)
    }
    logger.info("DDC \(isRead ? "read" : "write") failed after \(totalAttempts) attempts")
    return success
  }

  // The bridge address selects the transport, not the monitor's wire address.
  // DDC checksums must keep using the actual 0x6E destination and 0x51 source.
  static func ddcPacket(opcode: UInt8, payload: [UInt8]) -> [UInt8] {
    var packet = [UInt8(0x80 | (payload.count + 1)), opcode] + payload
    packet.append(packet.reduce(UInt8(0x6E ^ 0x51), ^))
    return packet
  }

  // MCDP29xx routing is documented by waydabber/m1ddc (MIT).
  // Select it only for a positively identified bridge, never by monitor model.
  static func ddcChipAddress(providerClass: String?) -> UInt32 {
    providerClass == "AppleDCPMCDP29XX" ? 0xB7 : 0x37
  }

  // DDC checksum calculator
  static func checksum(chk: UInt8, data: inout [UInt8], start: Int, end: Int) -> UInt8 {
    var chkd: UInt8 = chk
    for i in start ... end {
      chkd ^= data[i]
    }
    return chkd
  }

  static func ioregMatchScore(displayID: CGDirectDisplayID, ioregEdidUUID: String, ioDisplayLocation: String = "", ioregProductName: String = "", ioregSerialNumber: Int64 = 0, serviceLocation _: Int = 0) -> Int {
    var matchScore = 0
    if let dictionary = CoreDisplay_DisplayCreateInfoDictionary(displayID)?.takeRetainedValue() as NSDictionary? {
      if let kDisplayYearOfManufacture = dictionary[kDisplayYearOfManufacture] as? Int64, let kDisplayWeekOfManufacture = dictionary[kDisplayWeekOfManufacture] as? Int64, let kDisplayVendorID = dictionary[kDisplayVendorID] as? Int64, let kDisplayProductID = dictionary[kDisplayProductID] as? Int64, let kDisplayVerticalImageSize = dictionary[kDisplayVerticalImageSize] as? Int64, let kDisplayHorizontalImageSize = dictionary[kDisplayHorizontalImageSize] as? Int64 {
        struct KeyLoc {
          var key: String
          var loc: Int
        }
        let edidUUIDSearchKeys: [KeyLoc] = [
          // Vendor ID
          KeyLoc(key: String(format: "%04x", UInt16(max(0, min(kDisplayVendorID, 256 * 256 - 1)))).uppercased(), loc: 0),
          // Product ID
          KeyLoc(key: String(format: "%02x", UInt8((UInt16(max(0, min(kDisplayProductID, 256 * 256 - 1))) >> (0 * 8)) & 0xFF)).uppercased()
            + String(format: "%02x", UInt8((UInt16(max(0, min(kDisplayProductID, 256 * 256 - 1))) >> (1 * 8)) & 0xFF)).uppercased(), loc: 4),
          // Manufacture date
          KeyLoc(key: String(format: "%02x", UInt8(max(0, min(kDisplayWeekOfManufacture, 256 - 1)))).uppercased()
            + String(format: "%02x", UInt8(max(0, min(kDisplayYearOfManufacture - 1990, 256 - 1)))).uppercased(), loc: 19),
          // Image size
          KeyLoc(key: String(format: "%02x", UInt8(max(0, min(kDisplayHorizontalImageSize / 10, 256 - 1)))).uppercased()
            + String(format: "%02x", UInt8(max(0, min(kDisplayVerticalImageSize / 10, 256 - 1)))).uppercased(), loc: 30),
        ]
        for searchKey in edidUUIDSearchKeys where searchKey.key != "0000" && searchKey.key == ioregEdidUUID.prefix(searchKey.loc + 4).suffix(4) {
          matchScore += 1
        }
      }
      if ioDisplayLocation != "", let kIODisplayLocation = dictionary[kIODisplayLocationKey] as? String, ioDisplayLocation == kIODisplayLocation {
        matchScore += 10
      }
      if ioregProductName != "", let nameList = dictionary["DisplayProductName"] as? [String: String], let name = nameList["en_US"] ?? nameList.first?.value, name.lowercased() == ioregProductName.lowercased() {
        matchScore += 1
      }
      if ioregSerialNumber != 0, let serial = dictionary[kDisplaySerialNumber] as? Int64, serial == ioregSerialNumber {
        matchScore += 1
      }
    }
    return matchScore
  }

  static func ioregIterateToNextObjectOfInterest(interests: [String], iterator: inout io_iterator_t) -> (name: String, entry: io_service_t, preceedingEntry: io_service_t)? {
    var entry: io_service_t = IO_OBJECT_NULL
    var preceedingEntry: io_service_t = IO_OBJECT_NULL
    let name = UnsafeMutablePointer<CChar>.allocate(capacity: MemoryLayout<io_name_t>.size)
    defer {
      name.deallocate()
    }
    while true {
      preceedingEntry = entry
      entry = IOIteratorNext(iterator)
      guard IORegistryEntryGetName(entry, name) == KERN_SUCCESS, entry != MACH_PORT_NULL else {
        break
      }
      let nameString = String(cString: name)
      for interest in interests where entry != IO_OBJECT_NULL && nameString.contains(interest) {
        return (nameString, entry, preceedingEntry)
      }
    }
    return nil
  }

  static func getIORegServiceAppleCDC2Properties(entry: io_service_t) -> IOregService {
    var ioregService = IOregService()
    if let unmanagedEdidUUID = IORegistryEntryCreateCFProperty(entry, "EDID UUID" as CFString, kCFAllocatorDefault, IOOptionBits(kIORegistryIterateRecursively)), let edidUUID = unmanagedEdidUUID.takeRetainedValue() as? String {
      ioregService.edidUUID = edidUUID
    }
    let cpath = UnsafeMutablePointer<CChar>.allocate(capacity: MemoryLayout<io_string_t>.size)
    IORegistryEntryGetPath(entry, kIOServicePlane, cpath)
    ioregService.ioDisplayLocation = String(cString: cpath)
    if let unmanagedDisplayAttrs = IORegistryEntryCreateCFProperty(entry, "DisplayAttributes" as CFString, kCFAllocatorDefault, IOOptionBits(kIORegistryIterateRecursively)), let displayAttrs = unmanagedDisplayAttrs.takeRetainedValue() as? NSDictionary {
      ioregService.displayAttributes = displayAttrs
      if let productAttrs = displayAttrs.value(forKey: "ProductAttributes") as? NSDictionary {
        if let manufacturerID = productAttrs.value(forKey: "ManufacturerID") as? String {
          ioregService.manufacturerID = manufacturerID
        }
        if let productName = productAttrs.value(forKey: "ProductName") as? String {
          ioregService.productName = productName
        }
        if let serialNumber = productAttrs.value(forKey: "SerialNumber") as? Int64 {
          ioregService.serialNumber = serialNumber
        }
        if let alphanumericSerialNumber = productAttrs.value(forKey: "AlphanumericSerialNumber") as? String {
          ioregService.alphanumericSerialNumber = alphanumericSerialNumber
        }
      }
    }
    if let unmanagedTransport = IORegistryEntryCreateCFProperty(entry, "Transport" as CFString, kCFAllocatorDefault, IOOptionBits(kIORegistryIterateRecursively)), let transport = unmanagedTransport.takeRetainedValue() as? NSDictionary {
      if let upstream = transport.value(forKey: "Upstream") as? String {
        ioregService.transportUpstream = upstream
      }
      if let downstream = transport.value(forKey: "Downstream") as? String {
        ioregService.transportDownstream = downstream
      }
    }
    return ioregService
  }

  static func setIORegServiceDCPAVServiceProxy(entry: io_service_t, ioregService: inout IOregService) {
    var parent: io_registry_entry_t = IO_OBJECT_NULL
    var providerClass: String?
    if IORegistryEntryGetParentEntry(entry, kIOServicePlane, &parent) == KERN_SUCCESS {
      providerClass = IORegistryEntryCreateCFProperty(parent, "EPICProviderClass" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? String
      IOObjectRelease(parent)
    }
    ioregService.ddcChipAddress = ddcChipAddress(providerClass: providerClass)
    if let unmanagedLocation = IORegistryEntryCreateCFProperty(entry, "Location" as CFString, kCFAllocatorDefault, IOOptionBits(kIORegistryIterateRecursively)), let location = unmanagedLocation.takeRetainedValue() as? String {
      ioregService.location = location
      if location == "External" {
        ioregService.service = IOAVServiceCreateWithService(kCFAllocatorDefault, entry)?.takeRetainedValue() as IOAVService
      }
    }
  }

  static public func getIoregServicesForMatching() -> [IOregService] {
    var serviceLocation = 0
    var ioregServicesForMatching: [IOregService] = []
    let ioregRoot: io_registry_entry_t = IORegistryGetRootEntry(kIOMasterPortDefault)
    defer {
      IOObjectRelease(ioregRoot)
    }
    var iterator = io_iterator_t()
    defer {
      IOObjectRelease(iterator)
    }
    var ioregService = IOregService()
    guard IORegistryEntryCreateIterator(ioregRoot, "IOService", IOOptionBits(kIORegistryIterateRecursively), &iterator) == KERN_SUCCESS else {
      return ioregServicesForMatching
    }
    let keyDCPAVServiceProxy = "DCPAVServiceProxy"
    let keysFramebuffer = ["AppleCLCD2", "IOMobileFramebufferShim"]
    while true {
      guard let objectOfInterest = ioregIterateToNextObjectOfInterest(interests: [keyDCPAVServiceProxy] + keysFramebuffer, iterator: &iterator) else {
        break
      }
      if keysFramebuffer.contains(objectOfInterest.name) {
        ioregService = self.getIORegServiceAppleCDC2Properties(entry: objectOfInterest.entry)
        serviceLocation += 1
        ioregService.serviceLocation = serviceLocation
      } else if objectOfInterest.name == keyDCPAVServiceProxy {
        self.setIORegServiceDCPAVServiceProxy(entry: objectOfInterest.entry, ioregService: &ioregService)
        ioregServicesForMatching.append(ioregService)
      }
    }
    return ioregServicesForMatching
  }

  static func checkIfDummy(ioregService: IOregService) -> Bool {
    if ioregService.manufacturerID == "AOC", ioregService.productName == "28E850" {
      return true
    }
    return false
  }

  static func checkIfDiscouraged(ioregService _: IOregService) -> Bool {
    false
  }
}
