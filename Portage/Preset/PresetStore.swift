import Foundation
import Observation

@Observable
@MainActor
final class PresetStore {
    private(set) var presets: [Preset] = []
    private let monitorStore: MonitorStore
    private let defaults: UserDefaults
    private weak var toastState: ToastState?

    var lastActivationError: String?

    init(monitorStore: MonitorStore, defaults: UserDefaults = .standard) {
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

        await withTaskGroup(of: (String, Error?).self) { group in
            for assignment in preset.assignments {
                group.addTask {
                    do {
                        try await self.monitorStore.switchInput(
                            monitorID: assignment.monitorEdidUUID,
                            to: assignment.targetInputValue
                        )
                        return (assignment.monitorEdidUUID, nil)
                    } catch {
                        return (assignment.monitorEdidUUID, error)
                    }
                }
            }

            for await (monitorID, error) in group {
                if let error {
                    let name = monitorStore.monitors.first(where: { $0.edidUUID == monitorID })?.displayName ?? monitorID
                    errors.append("\(name): \(error.localizedDescription)")
                }
            }
        }

        if !errors.isEmpty {
            let message = errors.joined(separator: "\n")
            lastActivationError = message
            toastState?.show(message, isError: true)
        } else {
            toastState?.show("Activated \(preset.name)")
        }
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
