import SwiftUI
import AppKit

@MainActor
final class DisplayIdentifier {
    static let shared = DisplayIdentifier()
    private var windows: [UInt32: NSWindow] = [:]
    private var dismissals: [UInt32: Task<Void, Never>] = [:]

    func show(displayID: UInt32, name: String) {
        guard let screen = NSScreen.screens.first(where: {
            ($0.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber)?.uint32Value == displayID
        }) else { return }
        dismissals[displayID]?.cancel()
        windows[displayID]?.close()
        let controller = NSHostingController(rootView:
            VStack(spacing: 10) {
                Image(systemName: CGDisplayIsBuiltin(displayID) != 0 ? "laptopcomputer" : "display").font(.system(size: 32))
                Text(name).font(.title2.weight(.semibold)).lineLimit(2).multilineTextAlignment(.center)
            }
            .foregroundStyle(.white).padding(24).frame(width: 300, height: 150)
            .background(.black.opacity(0.8), in: .rect(cornerRadius: 24))
        )
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 300, height: 150), styleMask: .borderless, backing: .buffered, defer: false)
        window.contentViewController = controller
        window.isOpaque = false
        window.backgroundColor = .clear
        window.level = .screenSaver
        window.ignoresMouseEvents = true
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.isReleasedWhenClosed = false
        window.setFrameOrigin(NSPoint(x: screen.visibleFrame.midX - 150, y: screen.visibleFrame.midY - 75))
        windows[displayID] = window
        window.orderFrontRegardless()
        dismissals[displayID] = Task { @MainActor [weak self] in
            do { try await Task.sleep(for: .seconds(3)) } catch { return }
            self?.windows.removeValue(forKey: displayID)?.close()
            self?.dismissals[displayID] = nil
        }
    }
}
