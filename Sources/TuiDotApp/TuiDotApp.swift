import SwiftUI

@main
struct TuiDotApp: App {
    @NSApplicationDelegateAdaptor(TuiDotAppDelegate.self) private var appDelegate
    @StateObject private var store = ProfileStore()

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
