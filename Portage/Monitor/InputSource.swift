import Foundation

let VCP_INPUT_SOURCE: UInt8 = 0x60

struct InputMapping: Codable, Identifiable, Sendable, Hashable {
    let id: UUID
    var ddcValue: UInt16
    var label: String

    init(ddcValue: UInt16, label: String) {
        self.id = UUID()
        self.ddcValue = ddcValue
        self.label = label
    }
}

enum KnownManufacturer: String, CaseIterable, Sendable {
    case msi = "MSI"
    case benQ = "BNQ"
    case dell = "DEL"
    case lg = "GSM"
}

enum ManufacturerInputTable {
    static let defaults: [KnownManufacturer: [InputMapping]] = [
        .msi: [
            InputMapping(ddcValue: 5, label: "HDMI-1"),
            InputMapping(ddcValue: 6, label: "HDMI-2"),
            InputMapping(ddcValue: 7, label: "DisplayPort"),
            InputMapping(ddcValue: 8, label: "USB-C"),
        ],
        .benQ: [
            InputMapping(ddcValue: 17, label: "HDMI-1"),
            InputMapping(ddcValue: 18, label: "HDMI-2"),
            InputMapping(ddcValue: 19, label: "USB-C"),
        ],
        .dell: [
            InputMapping(ddcValue: 15, label: "DisplayPort-1"),
            InputMapping(ddcValue: 16, label: "DisplayPort-2"),
            InputMapping(ddcValue: 17, label: "HDMI-1"),
            InputMapping(ddcValue: 18, label: "HDMI-2"),
            InputMapping(ddcValue: 27, label: "USB-C"),
        ],
        .lg: [
            InputMapping(ddcValue: 15, label: "DisplayPort-1"),
            InputMapping(ddcValue: 16, label: "DisplayPort-2"),
            InputMapping(ddcValue: 17, label: "HDMI-1"),
            InputMapping(ddcValue: 18, label: "HDMI-2"),
        ],
    ]

    static let standardMCCS: [InputMapping] = [
        InputMapping(ddcValue: 15, label: "DisplayPort-1"),
        InputMapping(ddcValue: 16, label: "DisplayPort-2"),
        InputMapping(ddcValue: 17, label: "HDMI-1"),
        InputMapping(ddcValue: 18, label: "HDMI-2"),
    ]

    static func advertisedMappings(_ capabilities: String, manufacturer: String) -> [InputMapping]? {
        guard let vcp = capabilities.range(of: "vcp(", options: .caseInsensitive) else { return nil }
        let text = String(capabilities[vcp.upperBound...])
        guard let regex = try? NSRegularExpression(pattern: #"(?:^|[\s)])60\s*\(([^()]*)\)"#, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range(at: 1), in: text) else { return nil }
        let known = defaultMappings(for: manufacturer)
        var seen = Set<UInt16>()
        let inputs = text[range].split(whereSeparator: { $0.isWhitespace }).compactMap { token -> InputMapping? in
            guard let value = UInt16(token, radix: 16), seen.insert(value).inserted else { return nil }
            let label = known.first(where: { $0.ddcValue == value })?.label
                ?? [UInt16(1): "VGA-1", 3: "DVI-1", 4: "DVI-2", 15: "DisplayPort-1", 16: "DisplayPort-2", 17: "HDMI-1", 18: "HDMI-2"][value]
                ?? String(format: "Input 0x%02X", value)
            return InputMapping(ddcValue: value, label: label)
        }
        return inputs.isEmpty ? nil : inputs
    }

    static func defaultMappings(for manufacturerID: String) -> [InputMapping] {
        guard let known = KnownManufacturer(rawValue: manufacturerID) else {
            return standardMCCS
        }
        return defaults[known] ?? standardMCCS
    }
}
