import AppKit
import Foundation

@MainActor
enum ProfileDeepLinkHandler {
    static func open(_ url: URL) {
        guard let link = ProfileDeepLink(url: url) else {
            showError("TuiDotApp received an invalid launch link.")
            return
        }

        let store = ProfileStore()
        do {
            switch link {
            case let .launch(id):
                guard let profile = store.profile(withID: id) else {
                    showError("That TUI profile no longer exists.")
                    return
                }
                try TerminalWindowManager.shared.launch(profile: profile)
            }
        } catch {
            showError(error.localizedDescription)
        }
    }

    private static func showError(_ message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Could not launch profile"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

final class TuiDotAppDelegate: NSObject, NSApplicationDelegate {
    func application(_ application: NSApplication, open urls: [URL]) {
        Task { @MainActor in
            for url in urls {
                ProfileDeepLinkHandler.open(url)
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        EmbeddedProfile.isStandaloneProfileApp
    }
}
