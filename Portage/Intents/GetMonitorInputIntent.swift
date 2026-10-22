import AppIntents

struct GetMonitorInputIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Monitor Input"
    static var description: IntentDescription = "Get the current input source for a specific monitor"

    @Parameter(title: "Monitor")
    var monitor: MonitorEntity

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let service = AppEnvironment.shared.automationService
        let info = try await service.getMonitorInput(query: monitor.id)
        return .result(value: info.currentInput ?? "Unknown")
    }
}
