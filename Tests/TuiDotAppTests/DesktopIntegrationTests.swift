import AppKit
import Testing
@testable import TuiDotApp

struct DesktopIntegrationTests {
    @Test
    func notificationUsesProfileNameWhenTerminalTitleIsEmpty() {
        let payload = DesktopNotificationPayload(
            title: "  \n",
            body: " Ready to continue \n",
            fallbackTitle: "Herdr"
        )

        #expect(payload.title == "Herdr")
        #expect(payload.body == "Ready to continue")
    }

    @Test
    func notificationKeepsTerminalProvidedTitle() {
        let payload = DesktopNotificationPayload(
            title: " Codex ",
            body: "Waiting for input",
            fallbackTitle: "Herdr"
        )

        #expect(payload.title == "Codex")
        #expect(payload.body == "Waiting for input")
    }

    @Test @MainActor
    func terminalAdvertisesEditableTextRole() {
        let view = TuiTerminalView(frame: .zero)

        #expect(view.accessibilityRole() == .textArea)
        #expect(TuiTerminalView.committedText(from: "hello") == "hello")
        #expect(TuiTerminalView.committedText(
            from: NSAttributedString(string: "namaste")
        ) == "namaste")
    }
}
