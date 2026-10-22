import Foundation
import Observation

enum AppFeature: String, CaseIterable, Identifiable, Codable {
    case inputs, brightness, hardware, modes, profiles, presets
    var id: Self { self }
    var title: String {
        switch self {
        case .inputs: "Input Switching"
        case .brightness: "Brightness"
        case .hardware: "Contrast & Display Audio"
        case .modes: "Resolution & Refresh Rate"
        case .profiles: "Color Profiles"
        case .presets: "Multi-display Presets"
        }
    }
}

@Observable @MainActor
final class FeaturePreferences {
    static let shared = FeaturePreferences()
    private let defaults: UserDefaults
    private(set) var disabled: Set<String>
    private(set) var hidden: Set<String>

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        disabled = Set(defaults.stringArray(forKey: "features.disabled") ?? [])
        hidden = Set(defaults.stringArray(forKey: "features.hiddenFromMenu") ?? [])
    }
    func enabled(_ feature: AppFeature) -> Bool { !disabled.contains(feature.rawValue) }
    func shown(_ feature: AppFeature) -> Bool { enabled(feature) && !hidden.contains(feature.rawValue) }
    func setEnabled(_ enabled: Bool, _ feature: AppFeature) {
        if enabled { disabled.remove(feature.rawValue) } else { disabled.insert(feature.rawValue) }
        defaults.set(disabled.sorted(), forKey: "features.disabled")
    }
    func setShown(_ shown: Bool, _ feature: AppFeature) {
        if shown { hidden.remove(feature.rawValue) } else { hidden.insert(feature.rawValue) }
        defaults.set(hidden.sorted(), forKey: "features.hiddenFromMenu")
    }
    func require(_ feature: AppFeature) throws {
        if !enabled(feature) { throw DisabledFeature(name: feature.title) }
    }
    struct DisabledFeature: LocalizedError {
        let name: String
        var errorDescription: String? { "\(name) is disabled. Enable it in Settings → Features." }
    }
}
