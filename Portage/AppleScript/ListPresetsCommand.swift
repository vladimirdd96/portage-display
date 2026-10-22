import Foundation

class ListPresetsCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        suspendExecution()

        Task { @MainActor in
            let service = AppEnvironment.shared.automationService
            let presets = service.listPresets()
            let records = presets.map { preset -> [String: String] in
                [
                    "name": preset.name,
                    "id": preset.id.uuidString,
                ]
            }
            self.resumeExecution(withResult: records)
        }

        return nil
    }
}
