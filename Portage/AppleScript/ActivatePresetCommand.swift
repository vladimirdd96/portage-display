import Foundation

class ActivatePresetCommand: NSScriptCommand {
    override func performDefaultImplementation() -> Any? {
        guard let presetQuery = directParameter as? String else {
            scriptErrorNumber = errOSAScriptError
            scriptErrorString = "Missing preset name"
            return nil
        }

        suspendExecution()

        Task { @MainActor in
            let service = AppEnvironment.shared.automationService
            do {
                let result = try await service.activatePreset(query: presetQuery)
                self.resumeExecution(withResult: "Activated \(result.presetName)")
            } catch {
                self.scriptErrorNumber = errOSAScriptError
                self.scriptErrorString = (error as? AutomationError)?.sanitizedDescription ?? error.localizedDescription
                self.resumeExecution(withResult: nil)
            }
        }

        return nil
    }
}
