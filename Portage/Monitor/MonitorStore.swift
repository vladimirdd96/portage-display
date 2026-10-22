import Foundation
import Observation
import os

private let logger = Logger(subsystem: "com.github.vladimirdd96.PortageDisplay", category: "monitor")

@Observable
@MainActor
final class MonitorStore {
    private(set) var monitors: [MonitorConfig] = []
    private let ddcService: any DDCService
    let features: FeaturePreferences
    private let defaults: UserDefaults
    private var savedConfigs: [String: MonitorConfig] = [:]
    private var discoveryTask: Task<Void, Never>?
    private var inputRevisions: [String: UInt64] = [:]

    private var brightnessTasks: [String: Task<Void, Never>] = [:]
    var configuredMonitors: [MonitorConfig] { Array(savedConfigs.values) }
    var brightnessError: String?
    var hardwareErrors: [String: String] = [:]
    private var cyclingMonitors = Set<String>()
    private var hardwareTasks: [String: Task<Void, Never>] = [:]
    var isDiscovering = false

    init(ddcService: any DDCService, defaults: UserDefaults = .standard, features: FeaturePreferences = .shared) {
        self.features = features
        self.ddcService = ddcService
        self.defaults = defaults
        loadPersistedConfigs()
    }

    func discover() async {
        if let discoveryTask {
            await discoveryTask.value
            return
        }

        isDiscovering = true
        let task = Task { @MainActor in
            await self.performDiscovery()
        }
        discoveryTask = task

        await task.value

        discoveryTask = nil
        isDiscovering = false
    }

    private func performDiscovery() async {
        logger.info("Starting monitor discovery")
        let revisionsAtStart = inputRevisions

        do {
            let displays = try await ddcService.discoverDisplays()
            var updatedMonitors: [MonitorConfig] = []

            for display in displays {
                if var existing = monitors.first(where: { $0.edidUUID == display.edidUUID }) ?? savedConfigs[display.edidUUID] {
                    existing.systemDisplayID = display.systemDisplayID
                    do {
                        try features.require(.inputs)
                        let result = try await ddcService.readVCP(VCP_INPUT_SOURCE, display: display.edidUUID)
                        existing.currentInputValue = result.current
                        existing.lastSelectedInputValue = result.current
                    } catch {
                        existing.currentInputValue = nil
                        logger.warning("Failed to read input for \(display.productName, privacy: .public) (\(display.edidUUID, privacy: .public)): \(error.localizedDescription, privacy: .public)")
                    }
                    updatedMonitors.append(existing)
                } else {
                    let mappings = display.advertisedInputs ?? ManufacturerInputTable.defaultMappings(for: display.manufacturer)
                    var config = MonitorConfig(
                        edidUUID: display.edidUUID,
                        alphanumericSerial: display.alphanumericSerial,
                        displayName: display.productName,
                        manufacturer: display.manufacturer,
                        inputMappings: mappings
                    )
                    do {
                        try features.require(.inputs)
                        let result = try await ddcService.readVCP(VCP_INPUT_SOURCE, display: display.edidUUID)
                        config.currentInputValue = result.current
                        config.lastSelectedInputValue = result.current
                    } catch {
                        logger.warning("Failed to read input for \(display.productName, privacy: .public) (\(display.edidUUID, privacy: .public)): \(error.localizedDescription, privacy: .public)")
                    }
                    config.systemDisplayID = display.systemDisplayID
                    updatedMonitors.append(config)
                }
            }

            for index in updatedMonitors.indices {
                let id = updatedMonitors[index].edidUUID
                guard features.enabled(.brightness) else {
                    updatedMonitors[index].brightnessValue = nil
                    updatedMonitors[index].brightnessMaximum = nil
                    continue
                }
                do {
                    let value = try await ddcService.readVCP(0x10, display: id)
                    if value.max > 0, value.current <= value.max {
                        updatedMonitors[index].brightnessValue = Double(value.current) / Double(value.max)
                        updatedMonitors[index].brightnessMaximum = value.max
                    } else {
                        updatedMonitors[index].brightnessValue = nil
                        updatedMonitors[index].brightnessMaximum = nil
                    }
                } catch {
                    updatedMonitors[index].brightnessValue = nil
                    updatedMonitors[index].brightnessMaximum = nil
                }
            }
            for index in updatedMonitors.indices {
                let id = updatedMonitors[index].id
                let features = self.features.enabled(.hardware) ? (displays.first(where: { $0.id == id })?.supportedVCP ?? []) : []
                updatedMonitors[index].hardwareLevels = [:]
                updatedMonitors[index].hardwareMaximums = [:]
                updatedMonitors[index].isMuted = nil
                for feature in HardwareFeature.allCases where features.contains(feature.rawValue) {
                    if let result = try? await ddcService.readVCP(feature.rawValue, display: id),
                       result.max > 0, result.current <= result.max {
                        updatedMonitors[index].hardwareLevels?[feature.key] = Double(result.current) / Double(result.max)
                        updatedMonitors[index].hardwareMaximums?[feature.key] = result.max
                    }
                }
                if features.contains(0x8D), let result = try? await ddcService.readVCP(0x8D, display: id),
                   result.current == 1 || result.current == 2 {
                    updatedMonitors[index].isMuted = result.current == 1
                }
            }
            // A refresh may have read an input before a shortcut changed it.
            // Keep that refresh from overwriting the newer selection.
            for index in updatedMonitors.indices {
                let id = updatedMonitors[index].id
                if inputRevisions[id, default: 0] != revisionsAtStart[id, default: 0],
                   let latest = monitors.first(where: { $0.id == id }) {
                    updatedMonitors[index].currentInputValue = latest.currentInputValue
                    updatedMonitors[index].lastSelectedInputValue = latest.lastSelectedInputValue
                }
            }
            monitors = updatedMonitors
            persistConfigs()
            logger.info("Discovery complete: \(updatedMonitors.count) monitors")
        } catch {
            for index in monitors.indices {
                let id = monitors[index].id
                if inputRevisions[id, default: 0] == revisionsAtStart[id, default: 0] {
                    monitors[index].currentInputValue = nil
                }
            }
            persistConfigs()
            logger.error("Discovery failed: \(error.localizedDescription, privacy: .public)")
        }
    }

    func switchInput(monitorID: String, to inputValue: UInt16) async throws {
        try features.require(.inputs)
        try await applyInput(monitorID: monitorID, to: inputValue)
    }

    private func applyInput(monitorID: String, to inputValue: UInt16) async throws {
        try features.require(.inputs)
        // Always send explicit requests: the cached input may have changed via
        // the monitor's own controls or another computer.
        do {
            try await ddcService.writeVCP(VCP_INPUT_SOURCE, value: inputValue, display: monitorID)
        } catch DDCError.serviceUnavailable {
            // Cold launch/reconnection only: bind services without refreshing
            // brightness, volume, contrast, or the other monitors' controls.
            _ = try await ddcService.discoverDisplays()
            try features.require(.inputs)
            try await ddcService.writeVCP(VCP_INPUT_SOURCE, value: inputValue, display: monitorID)
        } catch {
            try await Task.sleep(for: .milliseconds(200))
            try features.require(.inputs)
            try await ddcService.writeVCP(VCP_INPUT_SOURCE, value: inputValue, display: monitorID)
        }

        inputRevisions[monitorID, default: 0] += 1
        let requestedRevision = inputRevisions[monitorID]
        if let idx = monitors.firstIndex(where: { $0.edidUUID == monitorID }) {
            monitors[idx].currentInputValue = inputValue
            monitors[idx].lastSelectedInputValue = inputValue
            persistConfigs()
        }

        try await Task.sleep(for: .milliseconds(500))
        guard inputRevisions[monitorID] == requestedRevision else { return }

        do {
            let result = try await ddcService.readVCP(VCP_INPUT_SOURCE, display: monitorID)
            guard inputRevisions[monitorID] == requestedRevision else { return }
            if result.current != inputValue,
               let idx = monitors.firstIndex(where: { $0.edidUUID == monitorID })
            {
                inputRevisions[monitorID, default: 0] += 1
                monitors[idx].currentInputValue = result.current
                monitors[idx].lastSelectedInputValue = result.current
                persistConfigs()
                throw DDCError.switchRejected(
                    monitor: monitorID, requested: inputValue, actual: result.current
                )
            }
        } catch let error as DDCError where error.isSwitchRejected {
            throw error
        } catch {
            logger.warning("Post-switch verify failed for \(monitorID, privacy: .public): \(error.localizedDescription, privacy: .public)")
        }
    }

    enum CycleError: LocalizedError {
        case unavailable, tooFewInputs
        var errorDescription: String? {
            switch self {
            case .unavailable: "This monitor is not connected or cannot switch inputs."
            case .tooFewInputs: "Choose at least two inputs in Settings → Inputs & Shortcuts → Cycle Inputs."
            }
        }
    }

    func cycleInput(monitorID: String) async throws {
        try features.require(.inputs)
        // Ignore repeats while the monitor is still processing its previous switch.
        guard cyclingMonitors.insert(monitorID).inserted else { return }
        defer { cyclingMonitors.remove(monitorID) }
        // Use the last known input so the write is the first hardware command.
        // Menu opens and display connection changes refresh this state separately.
        guard let monitor = monitors.first(where: { $0.id == monitorID }), !monitor.isBuiltIn else {
            throw CycleError.unavailable
        }
        let inputs = monitor.orderedCycleInputs
        guard inputs.count >= 2 else { throw CycleError.tooFewInputs }
        let current = monitor.currentInputValue ?? monitor.lastSelectedInputValue
        let next = current.flatMap { value in inputs.firstIndex { $0.ddcValue == value } }
            .map { ($0 + 1) % inputs.count } ?? 0
        try await applyInput(monitorID: monitorID, to: inputs[next].ddcValue)
    }

    func updateCycleInputs(monitorID: String, values: [UInt16]?) {
        guard let index = monitors.firstIndex(where: { $0.id == monitorID }) else { return }
        monitors[index].cycleInputValues = values
        persistConfigs()
    }

    func setBrightness(monitorID: String, value: Double) {
        guard features.enabled(.brightness) else { return }
        guard value.isFinite,
              let index = monitors.firstIndex(where: { $0.edidUUID == monitorID }),
              let maximum = monitors[index].brightnessMaximum else { return }
        // A small minimum keeps the built-in panel usable while testing controls.
        let level = min(1, max(0.01, value))
        monitors[index].brightnessValue = level
        brightnessTasks[monitorID]?.cancel()
        brightnessTasks[monitorID] = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(100))
                guard let self, !Task.isCancelled else { return }
                try self.features.require(.brightness)
                try await self.ddcService.writeVCP(0x10, value: UInt16((level * Double(maximum)).rounded()), display: monitorID)
                self.brightnessError = nil
            } catch is CancellationError {
                // A newer slider position superseded this pending write.
            } catch {
                self?.brightnessError = error.localizedDescription
                await self?.discover()
            }
        }
    }

    func setHardwareLevel(monitorID: String, feature: HardwareFeature, value: Double) {
        guard features.enabled(.hardware) else { return }
        guard value.isFinite,
              let index = monitors.firstIndex(where: { $0.id == monitorID }),
              let maximum = monitors[index].hardwareMaximums?[feature.key] else { return }
        let level = min(1, max(0, value))
        monitors[index].hardwareLevels?[feature.key] = level
        let key = monitorID + ":" + feature.key
        hardwareTasks[key]?.cancel()
        hardwareTasks[key] = Task { [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(120))
                guard let self, !Task.isCancelled else { return }
                try self.features.require(.hardware)
                try await self.ddcService.writeVCP(feature.rawValue, value: UInt16((level * Double(maximum)).rounded()), display: monitorID)
                self.hardwareErrors[monitorID] = nil
            } catch is CancellationError {} catch {
                self?.hardwareErrors[monitorID] = error.localizedDescription
                await self?.discover()
            }
        }
    }

    func setMute(monitorID: String, muted: Bool) async throws {
        try features.require(.hardware)
        guard let index = monitors.firstIndex(where: { $0.id == monitorID }), monitors[index].isMuted != nil else {
            throw DDCError.serviceUnavailable(monitor: monitorID)
        }
        try await ddcService.writeVCP(0x8D, value: muted ? 1 : 2, display: monitorID)
        if let currentIndex = monitors.firstIndex(where: { $0.id == monitorID }) {
            monitors[currentIndex].isMuted = muted
        }
    }

    func updateInputMappings(monitorID: String, mappings: [InputMapping]) {
        if let idx = monitors.firstIndex(where: { $0.edidUUID == monitorID }) {
            monitors[idx].inputMappings = mappings
            persistConfigs()
        }
    }

    func updateDisplayName(monitorID: String, name: String) {
        if let idx = monitors.firstIndex(where: { $0.edidUUID == monitorID }) {
            monitors[idx].displayName = name
            persistConfigs()
        }
    }

    func currentInputLabel(for monitor: MonitorConfig) -> String? {
        guard let value = monitor.currentInputValue else { return nil }
        return monitor.inputMappings.first(where: { $0.ddcValue == value })?.label
    }

    private func persistConfigs() {
        for monitor in monitors { savedConfigs[monitor.edidUUID] = monitor }
        let configs = savedConfigs.values.sorted { $0.edidUUID < $1.edidUUID }
        if let data = try? JSONEncoder().encode(configs) {
            defaults.set(data, forKey: "monitorConfigs")
        }
    }

    private func loadPersistedConfigs() {
        guard let data = defaults.data(forKey: "monitorConfigs"),
              let configs = try? JSONDecoder().decode([MonitorConfig].self, from: data) else { return }
        monitors = configs
        for config in configs { savedConfigs[config.edidUUID] = config }
    }
}
