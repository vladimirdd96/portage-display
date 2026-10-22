import AppKit
import KeyboardShortcuts
import Testing
@testable import Portage

@Suite("Shortcut recorder")
@MainActor
struct ShortcutRecorderTests {
    @Test("The native clear button removes the persisted shortcut")
    func clearButtonPersistsRemoval() throws {
        let name = KeyboardShortcuts.Name("test-recorder-clear-\(UUID())")
        defer { KeyboardShortcuts.setShortcut(nil, for: name) }
        KeyboardShortcuts.setShortcut(.init(.f20, modifiers: [.command, .shift]), for: name)
        var receivedRemoval = false
        let coordinator = ShortcutRecorder.Coordinator { shortcut in
            receivedRemoval = shortcut == nil
        }
        let recorder = coordinator.makeRecorder(for: name)
        let cell = try #require(recorder.cell as? NSSearchFieldCell)
        let clear = try #require(cell.cancelButtonCell)
        clear.performClick(recorder)

        #expect(recorder.stringValue.isEmpty)
        #expect(KeyboardShortcuts.getShortcut(for: name) == nil)
        #expect(receivedRemoval)
        let reopened = KeyboardShortcuts.RecorderCocoa(for: name)
        #expect(reopened.stringValue.isEmpty)
    }

    @Test("An empty field action does not cancel shortcut recording")
    func emptyFieldActionIsIgnored() {
        let name = KeyboardShortcuts.Name("test-recorder-empty-\(UUID())")
        defer { KeyboardShortcuts.setShortcut(nil, for: name) }
        var changes = 0
        let coordinator = ShortcutRecorder.Coordinator { _ in changes += 1 }
        let recorder = coordinator.makeRecorder(for: name)
        NSApp.sendAction(recorder.action!, to: recorder.target, from: recorder)
        #expect(changes == 0)
    }

}
