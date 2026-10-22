import AppKit
import SwiftUI

@MainActor
final class PanelController {
    private let panel: FloatingPanel
    private var contentSize = NSSize(width: 400, height: 260)

    var isVisible: Bool { panel.isVisible }
    var onShow: (() -> Void)?
    var contentBuilder: (() -> AnyView)?

    init() {
        panel = FloatingPanel()
        panel.contentView = nil
        panel.onHide = { [weak self] in self?.panel.contentView = nil }
    }

    func setContent<V: View>(_ view: V) {
        let hosting = NSHostingView(rootView: AnyView(view))
        let material = NSVisualEffectView()
        material.material = .popover
        material.state = .active
        material.blendingMode = .behindWindow
        material.wantsLayer = true
        material.layer?.cornerRadius = 26
        material.layer?.masksToBounds = true
        hosting.translatesAutoresizingMaskIntoConstraints = false
        material.addSubview(hosting)
        NSLayoutConstraint.activate([
            hosting.topAnchor.constraint(equalTo: material.topAnchor),
            hosting.bottomAnchor.constraint(equalTo: material.bottomAnchor),
            hosting.leadingAnchor.constraint(equalTo: material.leadingAnchor),
            hosting.trailingAnchor.constraint(equalTo: material.trailingAnchor)
        ])
        panel.contentView = material
        panel.setContentSize(contentSize)
    }

    func resize(to size: CGSize) {
        guard abs(contentSize.height - size.height) > 1 || abs(contentSize.width - size.width) > 1 else { return }
        contentSize = size
        let top = panel.frame.maxY
        panel.setContentSize(size)
        if panel.isVisible, let screen = panel.screen {
            let bounds = screen.visibleFrame
            let y = max(bounds.minY + 12, min(top - panel.frame.height, bounds.maxY - panel.frame.height - 12))
            panel.setFrameOrigin(NSPoint(x: panel.frame.minX, y: y))
        }
    }

    func toggle() {
        if panel.isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        if panel.contentView == nil, let view = contentBuilder?() { setContent(view) }
        let builtIn = NSScreen.screens.first {
            guard let number = $0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return false }
            return CGDisplayIsBuiltin(number.uint32Value) != 0
        }
        guard let screen = builtIn ?? NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let panelSize = panel.frame.size
        let x = screenFrame.midX - panelSize.width / 2
        let height = min(contentSize.height, screenFrame.height - 48)
        panel.setContentSize(NSSize(width: contentSize.width, height: height))
        let y = screenFrame.midY - panel.frame.height / 2
        panel.setFrameOrigin(NSPoint(x: x, y: y))
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
        onShow?()
    }

    func hide() {
        panel.orderOut(nil)
        NotificationCenter.default.post(name: .portageMenuClosed, object: nil)
        panel.contentView = nil
    }
}
