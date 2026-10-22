import AppIntents

struct MonitorEntity: AppEntity {
    static var typeDisplayRepresentation: TypeDisplayRepresentation { "Monitor" }
    static var defaultQuery = MonitorQuery()

    var id: String
    var name: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct MonitorQuery: EntityQuery {
    @MainActor
    func entities(for identifiers: [String]) async throws -> [MonitorEntity] {
        AppEnvironment.shared.monitorStore.monitors
            .filter { identifiers.contains($0.edidUUID) }
            .map { MonitorEntity(id: $0.edidUUID, name: $0.displayName) }
    }

    @MainActor
    func suggestedEntities() async throws -> [MonitorEntity] {
        AppEnvironment.shared.monitorStore.monitors
            .map { MonitorEntity(id: $0.edidUUID, name: $0.displayName) }
    }
}
