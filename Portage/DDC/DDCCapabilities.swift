import Foundation

nonisolated enum DDCCapabilities {
    // Only tokens at the first VCP nesting level are feature codes. Nested tokens
    // describe values (e.g. input codes), and must not imply support for a feature.
    static func features(in text: String) -> Set<UInt8>? {
        guard let regex = try? NSRegularExpression(pattern: #"vcp\s*\("#, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range, in: text) else { return nil }
        var depth = 1
        var token = ""
        var result = Set<UInt8>()
        func flush() -> Bool {
            guard !token.isEmpty else { return true }
            defer { token = "" }
            guard let code = UInt8(token, radix: 16) else { return false }
            result.insert(code)
            return true
        }
        for character in text[range.upperBound...] {
            if character == "(" {
                if depth == 1, !flush() { return nil }
                depth += 1
            } else if character == ")" {
                if depth == 1, !flush() { return nil }
                depth -= 1
                if depth == 0 { return result }
            } else if depth == 1 {
                if character.isWhitespace {
                    if !flush() { return nil }
                } else { token.append(character) }
            }
        }
        return nil
    }
    static func values(for feature: UInt8, in text: String) -> [UInt16] {
        guard features(in: text) != nil,
              let regex = try? NSRegularExpression(pattern: #"vcp\s*\("#, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let range = Range(match.range, in: text) else { return [] }
        var depth = 1
        var token = ""
        var current: UInt8?
        var collecting = false
        var values: [UInt16] = []
        func flush() {
            guard !token.isEmpty else { return }
            if depth == 1 { current = UInt8(token, radix: 16) }
            else if depth == 2, collecting, let value = UInt16(token, radix: 16), !values.contains(value) { values.append(value) }
            token = ""
        }
        for character in text[range.upperBound...] {
            if character == "(" {
                flush()
                if depth == 1 { collecting = current == feature }
                depth += 1
            } else if character == ")" {
                flush()
                if depth == 2, collecting { return values }
                depth -= 1
                if depth == 0 { return [] }
            } else if character.isWhitespace { flush() }
            else if depth <= 2 { token.append(character) }
        }
        return []
    }

}

nonisolated enum HardwareFeature: UInt8, CaseIterable, Sendable {
    case contrast = 0x12
    case volume = 0x62
    case redGain = 0x16
    case greenGain = 0x18
    case blueGain = 0x1A
    var isColor: Bool { self == .redGain || self == .greenGain || self == .blueGain }
    var requiredFeature: AppFeature { isColor ? .monitorColors : .hardware }
    var title: String {
        switch self {
        case .contrast: "Contrast"
        case .volume: "Volume"
        case .redGain: "Red gain"
        case .greenGain: "Green gain"
        case .blueGain: "Blue gain"
        }
    }
    var symbol: String { self == .contrast ? "circle.lefthalf.filled" : "speaker.wave.2" }
    var key: String { String(rawValue) }
}

nonisolated enum MonitorColorPreset {
    static func label(_ value: UInt16) -> String {
        [UInt16(1): "sRGB", 2: "Display Native", 3: "4000 K", 4: "5000 K", 5: "6500 K", 6: "7500 K", 7: "8200 K", 8: "9300 K", 9: "10000 K", 10: "11500 K", 11: "User 1", 12: "User 2", 13: "User 3"][value]
            ?? String(format: "Monitor preset 0x%02X", value)
    }
}
