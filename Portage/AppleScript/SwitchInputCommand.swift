import Foundation

class SwitchInputCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        guard let monitorQuery = directParameter as? String else {
            scriptErrorNumber = errOSAScriptError
            scriptErrorString = "Missing monitor name or UUID"
            return nil
        }
        guard let inputLabel = evaluatedArguments?["to"] as? String else {
            scriptErrorNumber = errOSAScriptError
            scriptErrorString = "Missing input label (use 'to' parameter)"
            return nil
        }

        suspendExecution()

        Task { @MainActor in
            let service = AppEnvironment.shared.automationService
            do {
                let result = try await service.switchInput(
                    monitorQuery: monitorQuery, inputLabel: inputLabel
                )
                self.resumeExecution(
                    withResult: "Switched \(result.monitorName) to \(result.inputLabel)"
                )
            } catch {
                self.scriptErrorNumber = errOSAScriptError
                self.scriptErrorString = (error as? AutomationError)?.sanitizedDescription ?? error.localizedDescription
                self.resumeExecution(withResult: nil)
            }
        }

        return nil
    }
}
