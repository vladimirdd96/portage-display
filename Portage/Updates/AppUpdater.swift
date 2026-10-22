import AppKit
import Observation
import Sparkle

@Observable
@MainActor
final class AppUpdater {
    static let shared = AppUpdater()
    private let controller = SPUStandardUpdaterController(
        startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil)
    private var observations: [NSKeyValueObservation] = []
    private var started = false
    private(set) var canCheckForUpdates = false
    private(set) var automaticallyChecks = false

    private init() {
        observations = [
            controller.updater.observe(\.canCheckForUpdates, options: [.initial, .new]) { [weak self] updater, _ in
                MainActor.assumeIsolated { self?.canCheckForUpdates = updater.canCheckForUpdates }
            },
            controller.updater.observe(\.automaticallyChecksForUpdates, options: [.initial, .new]) { [weak self] updater, _ in
                MainActor.assumeIsolated { self?.automaticallyChecks = updater.automaticallyChecksForUpdates }
            }
        ]
    }

    func start() {
        guard !started else { return }
        started = true
        controller.startUpdater()
    }

    func setAutomaticallyChecks(_ enabled: Bool) {
        controller.updater.automaticallyChecksForUpdates = enabled
    }

    func checkForUpdates() {
        start()
        controller.checkForUpdates(nil)
    }
}
