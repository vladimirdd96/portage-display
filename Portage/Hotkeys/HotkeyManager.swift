import KeyboardShortcuts
import Observation

@MainActor
final class HotkeyManager {
    private let panelController: PanelController
    private let presetStore: PresetStore
    private let monitorStore: MonitorStore?
    private var registeredSignature: [String]?

    init(panelController: PanelController, presetStore: PresetStore, monitorStore: MonitorStore? = nil) {
        self.panelController = panelController
        self.presetStore = presetStore
        self.monitorStore = monitorStore
        registerAllHotkeys()
        observePresetChanges()
    }

    private func registerAllHotkeys() {
        let signature = presetStore.presets.map { "\($0.id)-\($0.hotkeyName ?? "")" }
            + (monitorStore?.monitors ?? []).flatMap { monitor in
                monitor.inputMappings.map { "\(monitor.id)-\($0.ddcValue)" }
            }
        guard signature != registeredSignature else { return }
        registeredSignature = signature
        KeyboardShortcuts.removeAllHandlers()

        KeyboardShortcuts.onKeyDown(for: .togglePanel) { [weak self] in
            self?.panelController.toggle()
        }

        for monitor in monitorStore?.monitors ?? [] {
            guard !monitor.isBuiltIn else { continue }
            KeyboardShortcuts.onKeyDown(for: .cycleInputs(monitor.id)) { [weak self] in
                guard let store = self?.monitorStore else { return }
                Task { @MainActor in
                    do { try await store.cycleInput(monitorID: monitor.id) }
                    catch { AppEnvironment.shared.toastState.show(error.localizedDescription, isError: true) }
                }
            }
            for input in monitor.inputMappings {
                KeyboardShortcuts.onKeyDown(for: .inputSource(monitor.edidUUID, input.ddcValue)) { [weak self] in
                    guard let self, let store = self.monitorStore else { return }
                    Task { @MainActor in
                        do {
                            try await store.switchInput(monitorID: monitor.edidUUID, to: input.ddcValue)
                        } catch {
                            AppEnvironment.shared.toastState.show(error.localizedDescription, isError: true)
                        }
                    }
                }
            }
        }
        for preset in presetStore.presets {
            guard let hotkeyName = preset.hotkeyName else { continue }
            let name = KeyboardShortcuts.Name(hotkeyName)
            let presetID = preset.id
            KeyboardShortcuts.onKeyDown(for: name) { [weak self] in
                guard let self else { return }
                Task { @MainActor in
                    guard let current = self.presetStore.presets.first(where: { $0.id == presetID }) else { return }
                    await self.presetStore.activate(preset: current)
                }
            }
        }
    }

    private func observePresetChanges() {
        withObservationTracking {
            _ = presetStore.presets
            _ = monitorStore?.monitors
        } onChange: { [weak self] in
            Task { @MainActor in
                self?.registerAllHotkeys()
                self?.observePresetChanges()
            }
        }
    }
}
