import AppKit

@main
enum PortageApp {
    @MainActor
    static func main() {
        // A second development or installed copy must not compete for the
        // same global shortcuts or issue simultaneous DDC requests.
        if !ProcessInfo.processInfo.environment.keys.contains("XCTestBundlePath"),
           let identifier = Bundle.main.bundleIdentifier,
           let running = NSRunningApplication.runningApplications(withBundleIdentifier: identifier)
               .first(where: { $0.processIdentifier != ProcessInfo.processInfo.processIdentifier && !$0.isTerminated }) {
            running.activate(options: [.activateIgnoringOtherApps])
            return
        }
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.setActivationPolicy(.accessory)
        application.run()
        withExtendedLifetime(delegate) {}
    }
}
