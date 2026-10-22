import Foundation
import Observation

@Observable
@MainActor
final class PresetStore {
    private(set) var presets: [Preset] = []
    private let monitorStore: MonitorStore
    private let defaults: UserDefaults
    private let applyProfile: (UInt32, URL) -> Bool
    private weak var toastState: ToastState?

    var lastActivationError: String?

    init(monitorStore: MonitorStore, defaults: UserDefaults = .standard,
         applyProfile: @escaping (UInt32, URL) -> Bool = { DisplayColorProfiles.apply(displayID: $0, url: $1) }) {
        self.applyProfile = applyProfile
        self.monitorStore = monitorStore
        self.defaults = defaults
        loadPresets()
    }

    func setToastState(_ state: ToastState) {
        self.toastState = state
    }

    func addPreset(_ preset: Preset) {
        presets.append(preset)
        persistPresets()
    }

    func deletePreset(id: UUID) {
        presets.removeAll { $0.id == id }
        persistPresets()
    }

    func updatePreset(_ preset: Preset) {
        if let idx = presets.firstIndex(where: { $0.id == preset.id }) {
            presets[idx] = preset
            persistPresets()
        }
    }

    func activate(preset: Preset) async {
        do { try monitorStore.features.require(.presets) } catch {
            lastActivationError = error.localizedDescription
            toastState?.show(error.localizedDescription, isError: true)
            return
        }
        lastActivationError = nil
        var errors: [String] = []

        let monitorIDs = Set(preset.assignments.map(\.monitorEdidUUID) + (preset.displaySettings ?? []).map(\.monitorEdidUUID))
        if monitorIDs.isEmpty { errors.append("This preset has no saved settings. Add controls in Settings → Presets.") }
        await withTaskGroup(of: [String].self) { group in
            for monitorID in monitorIDs {
                group.addTask { await self.apply(preset: preset, monitorID: monitorID) }
            }
            for await messages in group { errors.append(contentsOf: messages) }
        }

        if !errors.isEmpty {
            let message = errors.joined(separator: "\n")
            lastActivationError = message
            toastState?.show(message, isError: true)
        } else {
            toastState?.show("Activated \(preset.name)")
        }
    }

    func saveCurrentAppearance() -> Preset {
        var preset = Preset(name: "Current Display Settings")
        preset.displaySettings = monitorStore.monitors.compactMap { monitor in
            let settings = PresetDisplaySettings(
                monitorEdidUUID: monitor.id, displayName: monitor.displayName,
                brightness: monitorStore.features.enabled(.brightness) ? monitor.brightnessValue : nil,
                contrast: monitorStore.features.enabled(.hardware) ? monitor.hardwareLevels?[HardwareFeature.contrast.key] : nil,
                volume: monitorStore.features.enabled(.hardware) ? monitor.hardwareLevels?[HardwareFeature.volume.key] : nil,
                muted: monitorStore.features.enabled(.hardware) ? monitor.isMuted : nil,
                colorPreset: monitorStore.features.enabled(.monitorColors) ? monitor.currentColorPreset : nil,
                rgbGains: monitorStore.features.enabled(.monitorColors) ? Dictionary(uniqueKeysWithValues: HardwareFeature.allCases.filter(\.isColor).compactMap { feature in
                    monitor.hardwareLevels?[feature.key].map { (feature.key, $0) }
                }) : nil)
            return settings.isEmpty ? nil : settings
        }
        addPreset(preset)
        return preset
    }

    private func apply(preset: Preset, monitorID: String) async -> [String] {
        let name = monitorStore.monitors.first { $0.id == monitorID }?.displayName
            ?? preset.displaySettings?.first { $0.id == monitorID }?.displayName ?? monitorID
        var errors: [String] = []
        func attempt(_ label: String, _ action: () async throws -> Void) async {
            do { try await action() }
            catch { errors.append("\(name) · \(label): \(error.localizedDescription)") }
        }
        if let settings = preset.displaySettings?.first(where: { $0.id == monitorID }) {
            if let value = settings.colorPreset {
                await attempt("Monitor color preset") { try await monitorStore.applyColorPreset(monitorID: monitorID, value: value) }
            }
            for feature in HardwareFeature.allCases.filter(\.isColor) {
                if let value = settings.rgbGains?[feature.key] {
                    await attempt(feature.title) { try await monitorStore.applyHardwareLevel(monitorID: monitorID, feature: feature, value: value) }
                }
            }
            if let value = settings.brightness {
                await attempt("Brightness") { try await monitorStore.applyBrightness(monitorID: monitorID, value: value) }
            }
            if let value = settings.contrast {
                await attempt("Contrast") { try await monitorStore.applyHardwareLevel(monitorID: monitorID, feature: .contrast, value: value) }
            }
            if let value = settings.volume {
                await attempt("Volume") { try await monitorStore.applyHardwareLevel(monitorID: monitorID, feature: .volume, value: value) }
            }
            if let value = settings.muted {
                await attempt("Mute") { try await monitorStore.setMute(monitorID: monitorID, muted: value) }
            }
            if let path = settings.colorProfilePath {
                await attempt("Color profile") {
                    try monitorStore.features.require(.profiles)
                    guard let id = monitorStore.monitors.first(where: { $0.id == monitorID })?.systemDisplayID,
                          FileManager.default.fileExists(atPath: path),
                          applyProfile(id, URL(fileURLWithPath: path)) else {
                        throw PresetError.profileUnavailable
                    }
                }
            }
        }
        // Switching away can end DDC communication. Apply other controls first.
        if let input = preset.assignments.first(where: { $0.monitorEdidUUID == monitorID }) {
            await attempt("Input") { try await monitorStore.switchInput(monitorID: monitorID, to: input.targetInputValue) }
        }
        return errors
    }

    private enum PresetError: LocalizedError {
        case profileUnavailable
        var errorDescription: String? { "The saved color profile or display is unavailable on this Mac. Choose an available profile in Settings → Presets." }
    }

    private func persistPresets() {
        if let data = try? JSONEncoder().encode(presets) {
            defaults.set(data, forKey: "presets")
        }
    }

    private func loadPresets() {
        guard let data = defaults.data(forKey: "presets"),
              let loaded = try? JSONDecoder().decode([Preset].self, from: data) else { return }
        presets = loaded
    }
}
