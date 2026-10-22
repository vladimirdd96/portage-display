import KeyboardShortcuts

extension KeyboardShortcuts.Name {
    static func inputSource(_ monitorID: String, _ value: UInt16) -> Self {
        Self("input-\(monitorID)-\(value)")
    }
    static func cycleInputs(_ monitorID: String) -> Self { Self("cycle-inputs-\(monitorID)") }
    static let togglePanel = Self("togglePanel")
}
