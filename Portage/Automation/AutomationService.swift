import Foundation

@MainActor
final class AutomationService: Sendable {
    private let monitorStore: MonitorStore
    private let presetStore: PresetStore

    init(monitorStore: MonitorStore, presetStore: PresetStore) {
        self.monitorStore = monitorStore
        self.presetStore = presetStore
    }

    func ensureDiscovered() async {
        if monitorStore.monitors.isEmpty {
            await monitorStore.discover()
        }
    }

    func resolveMonitor(query: String) throws -> MonitorConfig {
        if let monitor = monitorStore.monitors.first(where: { $0.edidUUID == query }) {
            return monitor
        }
        let nameMatches = monitorStore.monitors.filter {
            $0.displayName.localizedCaseInsensitiveCompare(query) == .orderedSame
        }
        switch nameMatches.count {
        case 1:
            return nameMatches[0]
        case let n where n > 1:
            throw AutomationError.ambiguousMonitorName(
                name: query, matchingIDs: nameMatches.map(\.edidUUID)
            )
        default:
            throw AutomationError.monitorNotFound(
                query: query, available: monitorStore.monitors.map(\.displayName)
            )
        }
    }

    func resolvePreset(query: String) throws -> Preset {
        if let uuid = UUID(uuidString: query),
           let preset = presetStore.presets.first(where: { $0.id == uuid })
        {
            return preset
        }
        if let preset = presetStore.presets.first(where: {
            $0.name.localizedCaseInsensitiveCompare(query) == .orderedSame
        }) {
            return preset
        }
        throw AutomationError.presetNotFound(
            query: query, available: presetStore.presets.map(\.name)
        )
    }

    func resolveInput(label: String, monitor: MonitorConfig) throws -> InputMapping {
        if let mapping = monitor.inputMappings.first(where: {
            $0.label.localizedCaseInsensitiveCompare(label) == .orderedSame
        }) {
            return mapping
        }
        throw AutomationError.inputNotFound(
            label: label, monitor: monitor.displayName,
            available: monitor.inputMappings.map(\.label)
        )
    }

    func listMonitors() async -> [MonitorInfo] {
        await monitorStore.discover()
        return monitorStore.monitors.map { monitor in
            MonitorInfo(
                id: monitor.edidUUID,
                name: monitor.displayName,
                currentInput: monitorStore.currentInputLabel(for: monitor),
                currentInputValue: monitor.currentInputValue,
                availableInputs: monitor.inputMappings.map(\.label)
            )
        }
    }

    func listPresets() -> [PresetInfo] {
        presetStore.presets.map { preset in
            PresetInfo(id: preset.id, name: preset.name, assignmentCount: preset.assignments.count)
        }
    }

    func getMonitorInput(query: String) async throws -> MonitorInfo {
        await monitorStore.discover()
        let monitor = try resolveMonitor(query: query)
        return MonitorInfo(
            id: monitor.edidUUID,
            name: monitor.displayName,
            currentInput: monitorStore.currentInputLabel(for: monitor),
            currentInputValue: monitor.currentInputValue,
            availableInputs: monitor.inputMappings.map(\.label)
        )
    }

    func switchInput(monitorQuery: String, inputLabel: String) async throws -> SwitchResult {
        await ensureDiscovered()
        let monitor = try resolveMonitor(query: monitorQuery)
        let mapping = try resolveInput(label: inputLabel, monitor: monitor)
        try await monitorStore.switchInput(monitorID: monitor.edidUUID, to: mapping.ddcValue)
        return SwitchResult(monitorName: monitor.displayName, inputLabel: mapping.label)
    }

    func activatePreset(query: String) async throws -> ActivateResult {
        await ensureDiscovered()
        let preset = try resolvePreset(query: query)
        await presetStore.activate(preset: preset)
        if let error = presetStore.lastActivationError {
            throw AutomationError.activationFailed(detail: error)
        }
        return ActivateResult(presetName: preset.name)
    }
}
