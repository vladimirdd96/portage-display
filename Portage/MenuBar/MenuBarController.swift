import AppKit
import SwiftUI

@MainActor
final class MenuBarController: NSObject, NSPopoverDelegate {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let popover = NSPopover()
    private let environment: AppEnvironment
    private let store: MonitorStore
    private var globalClickMonitor: Any?
    private var localClickMonitor: Any?

    init(environment: AppEnvironment) {
        self.environment = environment
        store = environment.monitorStore
        super.init()
        if let button = item.button {
            button.image = NSImage(systemSymbolName: "display.2", accessibilityDescription: "Portage display controls")
            button.target = self
            button.action = #selector(toggle)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.toolTip = "Portage — Displays & Inputs"
            button.setAccessibilityLabel("Portage")
        }
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentSize = NSSize(width: 400, height: 260)
    }

    private func loadContent() {
        guard popover.contentViewController == nil else { return }
        popover.contentViewController = NSHostingController(rootView: PanelContentView(
            monitorStore: environment.monitorStore,
            presetStore: environment.presetStore,
            toastState: environment.toastState,
            onDismiss: { [weak self] in self?.popover.performClose(nil) },
            onSizeChange: { [weak self] size in
                guard let self, abs(self.popover.contentSize.height - size.height) > 1 else { return }
                self.popover.contentSize = size
            }
        ))
    }

    func popoverShouldClose(_ popover: NSPopover) -> Bool {
        NSApp.modalWindow == nil && popover.contentViewController?.view.window?.attachedSheet == nil
    }

    func popoverDidClose(_ notification: Notification) {
        stopClickAwayMonitoring()
        NotificationCenter.default.post(name: .portageMenuClosed, object: nil)
        popover.contentViewController = nil
    }

    func popoverDidShow(_ notification: Notification) {
        stopClickAwayMonitoring()
        let clicks: NSEvent.EventTypeMask = [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: clicks) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, self.popover.isShown, self.popoverShouldClose(self.popover) else { return }
                self.popover.performClose(nil)
            }
        }
        localClickMonitor = NSEvent.addLocalMonitorForEvents(matching: clicks) { [weak self] event in
            MainActor.assumeIsolated {
                guard let self, self.popover.isShown, self.popoverShouldClose(self.popover) else { return event }
                let contentWindow = self.popover.contentViewController?.view.window
                var clickedWindow = event.window
                while let window = clickedWindow {
                    if window === contentWindow { return event }
                    clickedWindow = window.parent
                }
                // Native dropdown menus may extend beyond the popover.
                if let window = event.window, window.level.rawValue >= NSWindow.Level.popUpMenu.rawValue { return event }
                // Let the status item's own handler close or toggle the menu.
                if let button = self.item.button, let window = button.window {
                    let point = button.convert(window.convertPoint(fromScreen: NSEvent.mouseLocation), from: nil)
                    if button.bounds.contains(point) { return event }
                }
                self.popover.performClose(nil)
                return event // Preserve the click in the destination window.
            }
        }
    }

    private func stopClickAwayMonitoring() {
        if let globalClickMonitor { NSEvent.removeMonitor(globalClickMonitor) }
        if let localClickMonitor { NSEvent.removeMonitor(localClickMonitor) }
        globalClickMonitor = nil
        localClickMonitor = nil
    }

    @objc private func toggle() {
        if NSApp.currentEvent?.type == .rightMouseUp || NSEvent.modifierFlags.contains(.control) {
            showQuickMenu()
            return
        }
        if NSEvent.modifierFlags.contains(.option) {
            NotificationCenter.default.post(name: .portageOpenSettings, object: nil)
            return
        }
        if popover.isShown { popover.performClose(nil) }
        else { showControls() }
    }

    private func showQuickMenu() {
        guard let button = item.button else { return }
        popover.performClose(nil)
        let menu = NSMenu()
        menu.appearance = AppAppearance.shared.mode.appearance
        menu.autoenablesItems = false
        func add(_ title: String, symbol: String, action: Selector, enabled: Bool = true) {
            let entry = NSMenuItem(title: title, action: action, keyEquivalent: "")
            entry.target = self
            entry.image = NSImage(systemSymbolName: symbol, accessibilityDescription: nil)
            entry.isEnabled = enabled
            menu.addItem(entry)
        }
        add("Display Controls", symbol: "display.2", action: #selector(openControls))
        add("Settings…", symbol: "gearshape", action: #selector(openSettings))
        add(store.isDiscovering ? "Refreshing Monitors…" : "Refresh Monitors", symbol: "arrow.clockwise", action: #selector(refreshMonitors), enabled: !store.isDiscovering)
        menu.addItem(.separator())
        add("Quit Portage", symbol: "power", action: #selector(quit))
        menu.popUp(positioning: nil, at: NSPoint(x: 0, y: button.bounds.minY), in: button)
    }

    @objc private func openControls() {
        // Let menu tracking finish before opening another transient surface.
        DispatchQueue.main.async { [weak self] in self?.showControls() }
    }

    private func showControls() {
        guard let button = item.button else { return }
        popover.appearance = AppAppearance.shared.mode.appearance
        loadContent()
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    @objc private func openSettings() {
        NotificationCenter.default.post(name: .portageOpenSettings, object: nil)
    }

    @objc private func refreshMonitors() {
        Task { await store.discover() }
    }

    @objc private func quit() { NSApp.terminate(nil) }

    func popoverWillShow(_ notification: Notification) {
        Task { await store.discover() }
    }
}
