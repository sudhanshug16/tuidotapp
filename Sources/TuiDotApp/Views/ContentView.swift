import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: ProfileStore

    var body: some View {
        NavigationSplitView {
            List(store.profiles, selection: $store.selectedProfileID) { profile in
                Label(profile.name, systemImage: profile.kind == .ssh ? "network" : "terminal")
                    .tag(profile.id)
            }
            .navigationTitle("TuiDotApp")
            .toolbar {
                ToolbarItemGroup {
                    Button {
                        store.addProfile()
                    } label: {
                        Label("New profile", systemImage: "plus")
                    }
                    Button(role: .destructive) {
                        store.deleteSelectedProfile()
                    } label: {
                        Label("Delete profile", systemImage: "trash")
                    }
                    .disabled(store.selectedProfileID == nil)
                }
            }
        } detail: {
            if let profile = store.selectedProfile {
                ProfileEditorView(profile: profile)
                    .id(profile.id)
            } else {
                ContentUnavailableView(
                    "No TUI selected",
                    systemImage: "terminal",
                    description: Text("Create a profile to turn an installed command into a Mac app window.")
                )
            }
        }
        .frame(minWidth: 900, minHeight: 620)
        .alert("Profile storage error", isPresented: Binding(
            get: { store.persistenceError != nil },
            set: { _ in }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.persistenceError ?? "Unknown error")
        }
        .task {
            store.addHerdrExampleIfEmpty()
        }
    }
}
