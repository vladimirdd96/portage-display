import AppKit
import KeyboardShortcuts
import SwiftUI

/// Keeps AppKit's clear-button action connected to the shortcut's saved value.
/// NSSearchField can clear its text without sending controlTextDidChange.
struct ShortcutRecorder: NSViewRepresentable {
    let name: KeyboardShortcuts.Name
    let onChange: (KeyboardShortcuts.Shortcut?) -> Void

    init(for name: KeyboardShortcuts.Name, onChange: @escaping (KeyboardShortcuts.Shortcut?) -> Void) {
        self.name = name
        self.onChange = onChange
    }

    func makeCoordinator() -> Coordinator { Coordinator(onChange: onChange) }

    func makeNSView(context: Context) -> KeyboardShortcuts.RecorderCocoa {
        context.coordinator.makeRecorder(for: name)
    }

    func updateNSView(_ recorder: KeyboardShortcuts.RecorderCocoa, context: Context) {
        context.coordinator.onChange = onChange
        recorder.shortcutName = name
    }

    @MainActor
    final class Coordinator: NSObject {
        var onChange: (KeyboardShortcuts.Shortcut?) -> Void

        init(onChange: @escaping (KeyboardShortcuts.Shortcut?) -> Void) {
            self.onChange = onChange
        }

        func makeRecorder(for name: KeyboardShortcuts.Name) -> KeyboardShortcuts.RecorderCocoa {
            let recorder = KeyboardShortcuts.RecorderCocoa(for: name) { [weak self] shortcut in
                self?.onChange(shortcut)
            }
            recorder.target = self
            recorder.action = #selector(fieldAction(_:))
            return recorder
        }

        @objc private func fieldAction(_ recorder: KeyboardShortcuts.RecorderCocoa) {
            guard recorder.stringValue.isEmpty,
                  KeyboardShortcuts.getShortcut(for: recorder.shortcutName) != nil else { return }
            KeyboardShortcuts.setShortcut(nil, for: recorder.shortcutName)
            recorder.window?.makeFirstResponder(nil)
            onChange(nil)
        }
    }
}
