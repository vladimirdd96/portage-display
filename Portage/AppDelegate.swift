import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    private var menuBarController: MenuBarController?
    private var panelController: PanelController?
    private var hotkeyManager: HotkeyManager?
    private var screenObserver: Any?
    private var settingsWindow: NSWindow?
    private var settingsObserver: Any?
    private var refreshTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        guard !ProcessInfo.processInfo.environment.keys.contains("XCTestBundlePath") else { return }

        AppAppearance.shared.apply()
        settingsObserver = NotificationCenter.default.addObserver(
            forName: .portageOpenSettings, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.showSettings() }
        }
        let env = AppEnvironment.shared
        menuBarController = MenuBarController(environment: env)
        configureApplicationMenu()

        let panel = PanelController()
        panel.contentBuilder = { [weak panel] in
            AnyView(PanelContentView(
                monitorStore: env.monitorStore,
                presetStore: env.presetStore,
                toastState: env.toastState,
                onDismiss: { [weak panel] in panel?.hide() },
                onSizeChange: { [weak panel] size in panel?.resize(to: size) }
            ))
        }
        panel.onShow = {
            Task { await env.monitorStore.discover() }
        }
        panelController = panel

        hotkeyManager = HotkeyManager(panelController: panel, presetStore: env.presetStore, monitorStore: env.monitorStore)

        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.scheduleRefresh()
        }

        showSettings()
    }

    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window === settingsWindow else { return }
        window.contentViewController = nil
        settingsWindow = nil
    }

    private func configureApplicationMenu() {
        let main = NSMenu()
        let applicationItem = NSMenuItem()
        let applicationMenu = NSMenu(title: "Portage")
        let settings = NSMenuItem(title: "Settings…", action: #selector(showSettings), keyEquivalent: ",")
        settings.target = self
        let displays = NSMenuItem(title: "Display Controls", action: #selector(showDisplayPanel), keyEquivalent: "")
        displays.target = self
        applicationMenu.addItem(displays)
        applicationMenu.addItem(settings)
        applicationMenu.addItem(.separator())
        applicationMenu.addItem(withTitle: "Quit Portage", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        applicationItem.submenu = applicationMenu
        main.addItem(applicationItem)
        let editItem = NSMenuItem()
        let edit = NSMenu(title: "Edit")
        edit.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        edit.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        edit.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        edit.addItem(withTitle: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v")
        edit.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editItem.submenu = edit
        main.addItem(editItem)
        NSApp.mainMenu = main
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if panelController?.isVisible == true { return false }
        showSettings()
        return false
    }

    @objc private func showDisplayPanel() {
        DispatchQueue.main.async { [weak self] in
            self?.settingsWindow?.close()
            self?.panelController?.show()
        }
    }

    @objc private func showSettings() {
        let env = AppEnvironment.shared
        if settingsWindow == nil {
            let controller = NSHostingController(rootView: SettingsView(monitorStore: env.monitorStore, presetStore: env.presetStore))
            let window = NSWindow(contentViewController: controller)
            window.title = "Portage Settings"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
            window.titlebarAppearsTransparent = true
            window.setContentSize(NSSize(width: 840, height: 600))
            window.minSize = NSSize(width: 820, height: 620)
            window.isReleasedWhenClosed = false
            window.delegate = self
            window.center()
            settingsWindow = window
        }
        if let screen = NSScreen.screens.first(where: {
            guard let number = $0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return false }
            return CGDisplayIsBuiltin(number.uint32Value) != 0
        }), let window = settingsWindow {
            let frame = screen.visibleFrame
            window.setFrameOrigin(NSPoint(x: frame.midX - window.frame.width / 2,
                                          y: frame.midY - window.frame.height / 2))
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
        Task { await env.monitorStore.discover() }
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            guard url.scheme == "portagedisplay" else { continue }
            if url.host == "panel" {
                showDisplayPanel()
                continue
            }
            if url.host == "settings" {
                showSettings()
                continue
            }
            guard let action = URLRouter.parse(url) else { continue }
            Task {
                await handleURLAction(action)
            }
        }
    }

    private func handleURLAction(_ action: URLAction) async {
        let env = AppEnvironment.shared
        switch action {
        case .activatePreset(let name, let id):
            guard let query = id ?? name else { return }
            do {
                _ = try await env.automationService.activatePreset(query: query)
            } catch let error as AutomationError {
                switch error {
                case .activationFailed:
                    break
                default:
                    env.toastState.show(error.localizedDescription, isError: true)
                }
            } catch {
                env.toastState.show(error.localizedDescription, isError: true)
            }
        case .switchInput(let monitor, let input):
            do {
                let result = try await env.automationService.switchInput(
                    monitorQuery: monitor, inputLabel: input
                )
                env.toastState.show("Switched \(result.monitorName) to \(result.inputLabel)")
            } catch {
                env.toastState.show(error.localizedDescription, isError: true)
            }
        case .listMonitors, .listPresets:
            panelController?.show()
        case .unknown:
            env.toastState.show("Unknown portagedisplay:// command", isError: true)
        }
    }

    private func scheduleRefresh() {
        refreshTask?.cancel()
        refreshTask = Task {
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            await AppEnvironment.shared.monitorStore.discover()
        }
    }
}
