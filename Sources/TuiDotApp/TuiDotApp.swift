import SwiftUI

@main
struct TuiDotApp: App {
    @NSApplicationDelegateAdaptor(TuiDotAppDelegate.self) private var appDelegate
    @StateObject private var store = ProfileStore()
    private let updateChecker = UpdateChecker()

    var body: some Scene {
        Window(Bundle.main.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "TuiDotApp", id: "main") {
            Group {
                if let profileID = EmbeddedProfile.id {
                EmbeddedProfileView(profileID: profileID)
                } else {
                    ContentView()
                }
            }
            .environmentObject(store)
        }
        .defaultSize(width: 1000, height: 680)
        .commands {
            CommandGroup(after: .appInfo) {
                if !EmbeddedProfile.isStandaloneProfileApp {
                    Button("Check for Updates…") {
                        updateChecker.checkForUpdates()
                    }

                    Button("Update All Exported Apps") {
                        store.updateAllExportedApps()
                    }
                    .disabled(store.exportedAppCount == 0 || store.isUpdatingExportedApps)
                }
            }
            CommandGroup(replacing: .newItem) {
                Button("New TUI Profile") {
                    store.addProfile()
                }
                .keyboardShortcut("n", modifiers: [.command])
                .disabled(EmbeddedProfile.isStandaloneProfileApp)
            }
        }
    }
}
