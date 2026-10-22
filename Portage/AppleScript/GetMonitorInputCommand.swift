import Foundation

class GetMonitorInputCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        guard let monitorQuery = directParameter as? String else {
            scriptErrorNumber = errOSAScriptError
            scriptErrorString = "Missing monitor name or UUID"
            return nil
        }

        suspendExecution()

        Task { @MainActor in
            let service = AppEnvironment.shared.automationService
            do {
                let info = try await service.getMonitorInput(query: monitorQuery)
                let record: NSDictionary = [
                    "name": info.name,
                    "id": info.id,
                    "currentInput": info.currentInput ?? "Unknown",
                    "availableInputs": info.availableInputs.joined(separator: ", "),
                ]
                self.resumeExecution(withResult: record)
            } catch {
                self.scriptErrorNumber = errOSAScriptError
                self.scriptErrorString = (error as? AutomationError)?.sanitizedDescription ?? error.localizedDescription
                self.resumeExecution(withResult: nil)
            }
        }

        return nil
    }
}
