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
}

nonisolated enum HardwareFeature: UInt8, CaseIterable, Sendable {
    case contrast = 0x12
    case volume = 0x62
    var title: String { self == .contrast ? "Contrast" : "Volume" }
    var symbol: String { self == .contrast ? "circle.lefthalf.filled" : "speaker.wave.2" }
    var key: String { String(rawValue) }
}
