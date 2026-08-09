import SwiftUI

@main
struct TuiDotApp: App {
    @NSApplicationDelegateAdaptor(TuiDotAppDelegate.self) private var appDelegate
    @StateObject private var store = ProfileStore()

    var body: some Scene {
        Window("TuiDotApp", id: "manager") {
            ContentView()
                .environmentObject(store)
        }
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New TUI Profile") {
                    store.addProfile()
                }
                .keyboardShortcut("n", modifiers: [.command])
            }
        }

        Settings {
            VStack(alignment: .leading, spacing: 12) {
                Text("TuiDotApp")
                    .font(.title2.bold())
                Text("Profiles run installed commands through your login shell. TuiDotApp never copies the TUI binary.")
                    .foregroundStyle(.secondary)
            }
            .padding(24)
            .frame(width: 480)
        }
    }
}
