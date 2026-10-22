import AppIntents

struct SetMonitorInputIntent: AppIntent {
    static var title: LocalizedStringResource = "Set Monitor Input"
    static var description: IntentDescription = "Switch a specific monitor to a given input source"

    @Parameter(title: "Monitor")
    var monitor: MonitorEntity

    @Parameter(title: "Input")
    var inputLabel: String

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let service = AppEnvironment.shared.automationService
        let result = try await service.switchInput(monitorQuery: monitor.id, inputLabel: inputLabel)
        return .result(value: "Switched \(result.monitorName) to \(result.inputLabel)")
    }
}
