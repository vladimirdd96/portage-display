import Foundation

class ListMonitorsCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        suspendExecution()

        Task { @MainActor in
            let service = AppEnvironment.shared.automationService
            let monitors = await service.listMonitors()
            let records = monitors.map { monitor -> [String: String] in
                [
                    "name": monitor.name,
                    "id": monitor.id,
                    "currentInput": monitor.currentInput ?? "Unknown",
                    "availableInputs": monitor.availableInputs.joined(separator: ", "),
                ]
            }
            self.resumeExecution(withResult: records)
        }

        return nil
    }
}
