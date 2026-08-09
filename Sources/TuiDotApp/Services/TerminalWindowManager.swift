import AppKit

@MainActor
final class TerminalWindowManager {
    static let shared = TerminalWindowManager()

    private var windows: [UUID: TerminalWindowController] = [:]

    func launch(profile: TuiProfile) throws {
        let startupInput = try LaunchCommandBuilder.startupInput(for: profile)
        let input = try LaunchInputStore.create(contents: startupInput)
        let id = UUID()
        let controller = TerminalWindowController(
            profile: profile,
            launchInput: input,
            onClose: { [weak self] in
                self?.windows[id] = nil
            }
        )
        windows[id] = controller
        controller.showWindow(nil)
        controller.window?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
