import AppKit

final class FloatingPanel: NSPanel {
    var onHide: (() -> Void)?
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 300),
            styleMask: [.titled, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        title = "Portage Displays"
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        isMovableByWindowBackground = false
        isFloatingPanel = true
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        animationBehavior = .utilityWindow
        isOpaque = false
        backgroundColor = .clear
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func resignKey() {
        super.resignKey()
        guard attachedSheet == nil, NSApp.modalWindow == nil else { return }
        orderOut(nil)
        NotificationCenter.default.post(name: .portageMenuClosed, object: nil)
        onHide?()
    }
}
