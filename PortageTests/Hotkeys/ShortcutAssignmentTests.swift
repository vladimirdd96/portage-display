import AppKit
import Foundation
import KeyboardShortcuts
import Testing
@testable import Portage

@Suite("Shortcut conflicts")
@MainActor
struct ShortcutAssignmentTests {
    @Test("Moving a shortcut clears its previous action only")
    func moveShortcut() {
        let first = KeyboardShortcuts.Name("test-first-\(UUID())")
        let second = KeyboardShortcuts.Name("test-second-\(UUID())")
        defer {
            KeyboardShortcuts.setShortcut(nil, for: first)
            KeyboardShortcuts.setShortcut(nil, for: second)
        }
        let shortcut = KeyboardShortcuts.Shortcut(.f20, modifiers: [.command, .option, .control])
        KeyboardShortcuts.setShortcut(shortcut, for: first)
        KeyboardShortcuts.setShortcut(shortcut, for: second)
        ShortcutAssignment.move(shortcut, to: second, among: [first, second])
        #expect(KeyboardShortcuts.getShortcut(for: first) == nil)
        #expect(KeyboardShortcuts.getShortcut(for: second) == shortcut)
    }
}
