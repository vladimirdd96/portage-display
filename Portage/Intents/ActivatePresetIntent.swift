import AppIntents

struct ActivatePresetIntent: AppIntent {
    static var title: LocalizedStringResource = "Activate Preset"
    static var description: IntentDescription = "Switch monitors to a saved preset configuration"

    @Parameter(title: "Preset")
    var preset: PresetEntity

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<String> {
        let service = AppEnvironment.shared.automationService
        let result = try await service.activatePreset(query: preset.id.uuidString)
        return .result(value: "Activated \(result.presetName)")
    }
}
