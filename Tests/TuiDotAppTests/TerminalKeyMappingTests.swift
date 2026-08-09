import AppKit
import Testing
@testable import TuiDotApp

@Suite("Terminal key mapping")
struct TerminalKeyMappingTests {
    @Test("Command becomes Control without dropping other modifiers")
    @MainActor
    func commandBecomesControl() {
        let original: NSEvent.ModifierFlags = [.command, .option, .shift, .capsLock]
        let translated = TuiTerminalView.replacingCommandWithControl(in: original)

        #expect(!translated.contains(.command))
        #expect(translated.contains(.control))
        #expect(translated.contains(.option))
        #expect(translated.contains(.shift))
        #expect(translated.contains(.capsLock))
    }
}
