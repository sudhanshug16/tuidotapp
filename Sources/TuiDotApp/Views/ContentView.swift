import AppKit
import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: ProfileStore
    @State private var profilePendingDeletion: TuiProfile?
    @State private var isConfirmingLibraryReset = false
    @State private var recoveryMessage: String?

    var body: some View {
        Group {
            if let loadError = store.loadError {
                ContentUnavailableView {
                    Label("Profile library needs attention", systemImage: "exclamationmark.triangle")
                } description: {
                    Text(loadError)
                } actions: {
                    Button("Show File in Finder") {
                        NSWorkspace.shared.activateFileViewerSelecting([store.storageURL])
                    }
                    Button("Reset Profiles…", role: .destructive) {
                        isConfirmingLibraryReset = true
                    }
                }
            } else {
                profileManager
            }
        }
        .frame(minWidth: 900, minHeight: 620)
        .alert("Profile storage error", isPresented: Binding(
            get: { store.persistenceError != nil },
            set: { if !$0 { store.dismissPersistenceError() } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.persistenceError ?? "Unknown error")
        }
        .task {
            store.addDefaultProfileIfEmpty()
            store.updateOutdatedExportedAppsIfNeeded()
        }
        .confirmationDialog(
            "Reset the profile library?",
            isPresented: $isConfirmingLibraryReset,
            titleVisibility: .visible
        ) {
            Button("Reset and Keep Backup", role: .destructive) {
                resetProfileLibrary()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("The unreadable file will be copied beside the new profile library so it can be recovered later.")
        }
        .alert("Profile library reset", isPresented: Binding(
            get: { recoveryMessage != nil },
            set: { if !$0 { recoveryMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(recoveryMessage ?? "")
        }
        .alert(
            store.exportedAppsUpdateReport?.title ?? "Exported apps updated",
            isPresented: Binding(
                get: { store.exportedAppsUpdateReport != nil },
                set: { if !$0 { store.dismissExportedAppsUpdateReport() } }
            )
        ) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(store.exportedAppsUpdateReport?.message ?? "")
        }
    }

    private var profileManager: some View {
        NavigationSplitView {
            List(store.profiles, selection: $store.selectedProfileID) { profile in
                Label(
                    profile.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                        ? "Untitled TUI"
                        : profile.name,
                    systemImage: profile.kind == .ssh ? "network" : "terminal"
                )
                .tag(profile.id)
                .contextMenu {
                    Button("Duplicate") {
                        store.selectedProfileID = profile.id
                        store.duplicateSelectedProfile()
                    }
                    Button("Delete…", role: .destructive) {
                        profilePendingDeletion = profile
                    }
                }
            }
            .navigationTitle("TuiDotApp")
            .toolbar {
                ToolbarItemGroup {
                    Button {
                        store.addProfile()
                    } label: {
                        Label("New profile", systemImage: "plus")
                    }
                    Button {
                        store.duplicateSelectedProfile()
                    } label: {
                        Label("Duplicate profile", systemImage: "plus.square.on.square")
                    }
                    .disabled(store.selectedProfileID == nil)
                    Button(role: .destructive) {
                        profilePendingDeletion = store.selectedProfile
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
        .confirmationDialog(
            "Delete \(profilePendingDeletion?.name ?? "this profile")?",
            isPresented: Binding(
                get: { profilePendingDeletion != nil },
                set: { if !$0 { profilePendingDeletion = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Delete Profile", role: .destructive) {
                guard let profile = profilePendingDeletion else { return }
                store.selectedProfileID = profile.id
                store.deleteSelectedProfile()
                profilePendingDeletion = nil
            }
            Button("Cancel", role: .cancel) {
                profilePendingDeletion = nil
            }
        } message: {
            Text("Existing exported apps for this profile will stop launching. This cannot be undone.")
        }
    }

    private func resetProfileLibrary() {
        do {
            let backup = try store.resetProfilesKeepingBackup()
            recoveryMessage = "A new profile library was created. The unreadable file is preserved as \(backup.lastPathComponent)."
        } catch {
            recoveryMessage = "Nothing was reset because a backup could not be created: \(error.localizedDescription)"
        }
    }
}
