import Testing

@testable import Portage

@Suite("AutomationService")
@MainActor
struct AutomationServiceTests {
    private func makeTestDisplays() -> [DDCDisplayInfo] {
        [
            DDCDisplayInfo(
                edidUUID: "uuid-1",
                productName: "MSI MPG 274U",
                manufacturer: "MSI",
                alphanumericSerial: "SN001"
            ),
            DDCDisplayInfo(
                edidUUID: "uuid-2",
                productName: "BenQ MA270U",
                manufacturer: "BNQ",
                alphanumericSerial: "SN002"
            ),
        ]
    }

    private func makeService() async -> (AutomationService, MonitorStore, PresetStore, MockDDCService) {
        let mock = MockDDCService()
        await mock.configure(displays: makeTestDisplays())
        await mock.setVCPValue(0x60, display: "uuid-1", current: 8, max: 18)
        await mock.setVCPValue(0x60, display: "uuid-2", current: 19, max: 19)
        let defaults = UserDefaults(suiteName: "test-\(UUID().uuidString)")!
        let monitorStore = MonitorStore(ddcService: mock, defaults: defaults)
        await monitorStore.discover()
        let presetStore = PresetStore(monitorStore: monitorStore, defaults: defaults)
        let service = AutomationService(monitorStore: monitorStore, presetStore: presetStore)
        return (service, monitorStore, presetStore, mock)
    }

    // MARK: - resolveMonitor

    @Test("Resolves monitor by exact UUID")
    func resolveMonitorByUUID() async throws {
        let (service, _, _, _) = await makeService()
        let monitor = try service.resolveMonitor(query: "uuid-1")
        #expect(monitor.edidUUID == "uuid-1")
        #expect(monitor.displayName == "MSI MPG 274U")
    }

    @Test("Resolves monitor by display name (case-insensitive)")
    func resolveMonitorByName() async throws {
        let (service, _, _, _) = await makeService()
        let monitor = try service.resolveMonitor(query: "msi mpg 274u")
        #expect(monitor.edidUUID == "uuid-1")
    }

    @Test("Throws ambiguous error when multiple monitors share a name")
    func resolveMonitorAmbiguous() async throws {
        let (service, monitorStore, _, _) = await makeService()
        monitorStore.updateDisplayName(monitorID: "uuid-2", name: "MSI MPG 274U")
        #expect(throws: AutomationError.self) {
            try service.resolveMonitor(query: "MSI MPG 274U")
        }
    }

    @Test("Throws not found error when no monitor matches")
    func resolveMonitorNotFound() async throws {
        let (service, _, _, _) = await makeService()
        #expect(throws: AutomationError.self) {
            try service.resolveMonitor(query: "nonexistent")
        }
    }

    // MARK: - resolvePreset

    @Test("Resolves preset by name (case-insensitive)")
    func resolvePresetByName() async throws {
        let (service, _, presetStore, _) = await makeService()
        let preset = Preset(name: "Work Mode")
        presetStore.addPreset(preset)
        let resolved = try service.resolvePreset(query: "work mode")
        #expect(resolved.id == preset.id)
    }

    @Test("Resolves preset by UUID string")
    func resolvePresetByUUID() async throws {
        let (service, _, presetStore, _) = await makeService()
        let preset = Preset(name: "Work Mode")
        presetStore.addPreset(preset)
        let resolved = try service.resolvePreset(query: preset.id.uuidString)
        #expect(resolved.id == preset.id)
    }

    @Test("Throws not found error when no preset matches")
    func resolvePresetNotFound() async throws {
        let (service, _, _, _) = await makeService()
        #expect(throws: AutomationError.self) {
            try service.resolvePreset(query: "nonexistent")
        }
    }

    // MARK: - resolveInput

    @Test("Resolves input by label (case-insensitive)")
    func resolveInputByLabel() async throws {
        let (service, monitorStore, _, _) = await makeService()
        let monitor = monitorStore.monitors[0]
        let mapping = try service.resolveInput(label: "usb-c", monitor: monitor)
        #expect(mapping.ddcValue == 8)
    }

    @Test("Throws not found error when input label doesn't match")
    func resolveInputNotFound() async throws {
        let (service, monitorStore, _, _) = await makeService()
        let monitor = monitorStore.monitors[0]
        #expect(throws: AutomationError.self) {
            try service.resolveInput(label: "VGA", monitor: monitor)
        }
    }

    // MARK: - listMonitors

    @Test("Lists monitors with current input labels")
    func listMonitors() async {
        let (service, _, _, _) = await makeService()
        let monitors = await service.listMonitors()
        #expect(monitors.count == 2)
        #expect(monitors[0].name == "MSI MPG 274U")
        #expect(monitors[0].currentInput == "USB-C")
        #expect(monitors[1].name == "BenQ MA270U")
        #expect(monitors[1].currentInput == "USB-C")
    }

    @Test("List monitors refreshes stale input state")
    func listMonitorsRefreshesInputs() async {
        let (service, _, _, mock) = await makeService()
        await mock.setVCPValue(0x60, display: "uuid-1", current: 5, max: 18)

        let monitors = await service.listMonitors()

        let discoveryCount = await mock.discoveryCount
        #expect(monitors[0].currentInput == "HDMI-1")
        #expect(monitors[0].currentInputValue == 5)
        #expect(discoveryCount == 2)
    }

    // MARK: - listPresets

    @Test("Lists presets with assignment counts")
    func listPresets() async {
        let (service, _, presetStore, _) = await makeService()
        let preset = Preset(
            name: "Work Mode",
            assignments: [
                PresetAssignment(monitorEdidUUID: "uuid-1", targetInputValue: 5, targetInputLabel: "HDMI-1")
            ]
        )
        presetStore.addPreset(preset)
        let presets = service.listPresets()
        #expect(presets.count == 1)
        #expect(presets[0].name == "Work Mode")
        #expect(presets[0].assignmentCount == 1)
    }

    // MARK: - getMonitorInput

    @Test("Gets current input for a specific monitor")
    func getMonitorInput() async throws {
        let (service, _, _, _) = await makeService()
        let info = try await service.getMonitorInput(query: "uuid-1")
        #expect(info.name == "MSI MPG 274U")
        #expect(info.currentInput == "USB-C")
        #expect(info.currentInputValue == 8)
    }

    @Test("Get monitor input refreshes stale state")
    func getMonitorInputRefreshesInput() async throws {
        let (service, _, _, mock) = await makeService()
        await mock.setVCPValue(0x60, display: "uuid-1", current: 5, max: 18)

        let info = try await service.getMonitorInput(query: "uuid-1")

        let discoveryCount = await mock.discoveryCount
        #expect(info.currentInput == "HDMI-1")
        #expect(info.currentInputValue == 5)
        #expect(discoveryCount == 2)
    }

    // MARK: - switchInput

    @Test("Switches input via monitor name and input label")
    func switchInput() async throws {
        let (service, _, _, mock) = await makeService()
        let result = try await service.switchInput(monitorQuery: "MSI MPG 274U", inputLabel: "HDMI-1")
        #expect(result.monitorName == "MSI MPG 274U")
        #expect(result.inputLabel == "HDMI-1")
        let log = await mock.writeLog
        #expect(log.count == 1)
        #expect(log[0].value == 5)
    }

    @Test("Switch input throws for unknown monitor")
    func switchInputUnknownMonitor() async {
        let (service, _, _, _) = await makeService()
        await #expect(throws: AutomationError.self) {
            try await service.switchInput(monitorQuery: "nonexistent", inputLabel: "HDMI-1")
        }
    }

    @Test("Switch input throws for unknown input label")
    func switchInputUnknownInput() async {
        let (service, _, _, _) = await makeService()
        await #expect(throws: AutomationError.self) {
            try await service.switchInput(monitorQuery: "uuid-1", inputLabel: "VGA")
        }
    }

    // MARK: - activatePreset

    @Test("Activates preset by name")
    func activatePreset() async throws {
        let (service, _, presetStore, mock) = await makeService()
        let preset = Preset(
            name: "Work Mode",
            assignments: [
                PresetAssignment(monitorEdidUUID: "uuid-1", targetInputValue: 5, targetInputLabel: "HDMI-1"),
                PresetAssignment(monitorEdidUUID: "uuid-2", targetInputValue: 17, targetInputLabel: "HDMI-1"),
            ]
        )
        presetStore.addPreset(preset)
        let result = try await service.activatePreset(query: "Work Mode")
        #expect(result.presetName == "Work Mode")
        let log = await mock.writeLog
        #expect(log.count == 2)
    }

    @Test("Activate preset throws for unknown preset")
    func activatePresetNotFound() async {
        let (service, _, _, _) = await makeService()
        await #expect(throws: AutomationError.self) {
            try await service.activatePreset(query: "nonexistent")
        }
    }

    @Test("Activate preset throws on DDC failure")
    func activatePresetDDCFailure() async {
        let (service, _, presetStore, mock) = await makeService()
        await mock.setShouldFailWrite(true)
        let preset = Preset(
            name: "Broken",
            assignments: [
                PresetAssignment(monitorEdidUUID: "uuid-1", targetInputValue: 5, targetInputLabel: "HDMI-1")
            ]
        )
        presetStore.addPreset(preset)
        await #expect(throws: AutomationError.self) {
            try await service.activatePreset(query: "Broken")
        }
    }
}
