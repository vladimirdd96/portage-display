import AppIntents

struct ListPresetsIntent: AppIntent {
    static var title: LocalizedStringResource = "List Presets"
    static var description: IntentDescription = "List all saved presets"

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let service = AppEnvironment.shared.automationService
        let presets = service.listPresets()
        let description = presets.map(\.name).joined(separator: "\n")
        return .result(value: description)
    }
}
