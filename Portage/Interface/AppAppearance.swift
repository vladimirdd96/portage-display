import AppKit
import Observation

/// One app-wide override; nil lets AppKit follow live macOS appearance changes.
@Observable @MainActor
final class AppAppearance {
    static let shared = AppAppearance()

    enum Mode: String, CaseIterable, Identifiable {
        case system, light, dark
        var id: Self { self }
        var title: String {
            switch self {
            case .system: "System"
            case .light: "Light"
            case .dark: "Dark"
            }
        }
        var appearance: NSAppearance? {
            switch self {
            case .system: nil
            case .light: NSAppearance(named: .aqua)
            case .dark: NSAppearance(named: .darkAqua)
            }
        }
    }

    var mode: Mode {
        didSet {
            guard oldValue != mode else { return }
            defaults.set(mode.rawValue, forKey: "app.appearance")
            apply()
        }
    }
    private let defaults: UserDefaults

    private init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        mode = Mode(rawValue: defaults.string(forKey: "app.appearance") ?? "") ?? .system
    }

    func apply() { NSApplication.shared.appearance = mode.appearance }
}
