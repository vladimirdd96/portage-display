import AppIntents

struct PresetEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Preset" }
    static var defaultQuery = PresetQuery()

    var id: UUID
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct PresetQuery: EntityQuery {
    @MainActor
    func entities(for identifiers: [UUID]) async throws -> [PresetEntity] {
        AppEnvironment.shared.presetStore.presets
            .filter { identifiers.contains($0.id) }
            .map { PresetEntity(id: $0.id, name: $0.name) }
    }

    @MainActor
    func suggestedEntities() async throws -> [PresetEntity] {
        AppEnvironment.shared.presetStore.presets
            .map { PresetEntity(id: $0.id, name: $0.name) }
    }
}
