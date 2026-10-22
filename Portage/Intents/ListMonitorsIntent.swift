import AppIntents

struct ListMonitorsIntent: AppIntent {
    static var title: LocalizedStringResource = "List Monitors"
    static var description: IntentDescription = "List all connected monitors and their current inputs"

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let service = AppEnvironment.shared.automationService
        let monitors = await service.listMonitors()
        let description = monitors.map { monitor in
            let input = monitor.currentInput ?? "Unknown"
            return "\(monitor.name): \(input)"
        }.joined(separator: "\n")
        return .result(value: description)
    }
}
