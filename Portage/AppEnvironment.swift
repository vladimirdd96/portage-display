import Foundation

@MainActor
final class AppEnvironment {
    static let shared = AppEnvironment()

    let ddcService: any DDCService
    let monitorStore: MonitorStore
    let presetStore: PresetStore
    let toastState = ToastState()
    let automationService: AutomationService

    private init() {
        let service = LiveDDCService()
        self.ddcService = service
        self.monitorStore = MonitorStore(ddcService: service)
        self.presetStore = PresetStore(monitorStore: monitorStore)
        self.automationService = AutomationService(monitorStore: monitorStore, presetStore: presetStore)
        self.presetStore.setToastState(toastState)
    }
}
