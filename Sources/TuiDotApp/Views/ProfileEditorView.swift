import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ProfileEditorView: View {
    @EnvironmentObject private var store: ProfileStore
    @State private var draft: TuiProfile
    @State private var launchError: String?
    @State private var exportMessage: String?

    init(profile: TuiProfile) {
        _draft = State(initialValue: profile)
    }

    var body: some View {
        Form {
            Section("Application") {
                TextField("Name", text: $draft.name)
                Picker("Runs on", selection: $draft.kind) {
                    ForEach(LaunchKind.allCases) { kind in
                        Text(kind.label).tag(kind)
                    }
                }
                TextField("Command", text: $draft.command, prompt: Text("herdr"))
                    .font(.system(.body, design: .monospaced))
                TextField("Working directory", text: $draft.workingDirectory)
                    .font(.system(.body, design: .monospaced))
            }

            if draft.kind == .ssh {
                Section("SSH") {
                    TextField("Host or ~/.ssh/config alias", text: $draft.sshDestination)
                        .textContentType(.URL)
                    TextField("Additional ssh arguments", text: $draft.sshArguments)
                        .font(.system(.body, design: .monospaced))
                    Text("Authentication, ProxyJump, ports, identities, and host keys remain owned by OpenSSH and ~/.ssh/config.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Standalone app icon") {
                HStack(spacing: 16) {
                    Group {
                        if let icon = selectedIcon {
                            Image(nsImage: icon)
                                .resizable()
                                .scaledToFit()
                        } else {
                            Image(systemName: "terminal.fill")
                                .resizable()
                                .scaledToFit()
                                .padding(12)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 64, height: 64)
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    VStack(alignment: .leading, spacing: 8) {
                        Text(draft.iconPath.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "No custom icon")
                            .lineLimit(1)
                            .foregroundStyle(.secondary)
                        HStack {
                            Button("Choose Image…") { chooseIcon() }
                            if draft.iconPath != nil {
                                Button("Clear", role: .destructive) {
                                    draft.iconPath = nil
                                }
                            }
                        }
                    }
                }
                Text("PNG, JPEG, and ICNS images are compiled into the exported app. The TUI executable is still resolved externally at launch.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Theme") {
                Picker("Light appearance", selection: $draft.lightThemeName) {
                    ForEach(GhosttyConfiguration.availableThemeNames, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }
                .searchable(text: .constant(""))

                Picker("Dark appearance", selection: $draft.darkThemeName) {
                    ForEach(GhosttyConfiguration.availableThemeNames, id: \.self) { name in
                        Text(name).tag(name)
                    }
                }

                Text("All Ghostty config")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextEditor(text: $draft.ghosttyConfig)
                    .font(.system(.body, design: .monospaced))
                    .frame(minHeight: 180)
                    .overlay {
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(.separator, lineWidth: 1)
                    }
                Text("Unknown Ghostty keys pass through unchanged. Launch control owns command, input, and shell-integration.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let launchError {
                Section {
                    Label(launchError, systemImage: "exclamationmark.triangle.fill")
                        .foregroundStyle(.red)
                }
            }
        }
        .formStyle(.grouped)
        .navigationTitle(draft.name.isEmpty ? "TUI profile" : draft.name)
        .toolbar {
            ToolbarItemGroup {
                Button {
                    exportLauncherApp()
                } label: {
                    Label("Export App", systemImage: "square.and.arrow.up")
                }

                Button("Save") {
                    store.update(draft)
                }
                .keyboardShortcut("s", modifiers: [.command])

                Button {
                    launch()
                } label: {
                    Label("Launch", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: [.command])
            }
        }
        .alert("TUI app export", isPresented: Binding(
            get: { exportMessage != nil },
            set: { if !$0 { exportMessage = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportMessage ?? "")
        }
        .onChange(of: draft) { _, newValue in
            store.update(newValue)
        }
    }

    private func launch() {
        do {
            store.update(draft)
            try TerminalWindowManager.shared.launch(profile: draft)
            launchError = nil
        } catch {
            launchError = error.localizedDescription
        }
    }

    private func exportLauncherApp() {
        store.update(draft)
        let panel = NSSavePanel()
        panel.title = "Export TUI App"
        panel.nameFieldStringValue = sanitizedAppName(draft.name) + ".app"
        panel.allowedContentTypes = [.application]
        panel.canCreateDirectories = true
        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try ProfileAppExporter.export(profile: draft, to: url)
            exportMessage = "Created \(url.lastPathComponent) as an independent Mac app. It contains the Ghostty host and profile ID, never the TUI binary."
        } catch {
            exportMessage = error.localizedDescription
        }
    }

    private var selectedIcon: NSImage? {
        guard let iconPath = draft.iconPath else { return nil }
        return NSImage(contentsOfFile: iconPath)
    }

    private func chooseIcon() {
        let panel = NSOpenPanel()
        panel.title = "Choose App Icon"
        panel.allowedContentTypes = [.png, .jpeg, UTType(filenameExtension: "icns")!]
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do {
            draft.iconPath = try ProfileIconStore.importIcon(
                from: url,
                profileID: draft.id
            ).path
        } catch {
            launchError = "The icon could not be saved: \(error.localizedDescription)"
        }
    }

    private func sanitizedAppName(_ value: String) -> String {
        let invalid = CharacterSet(charactersIn: "/:")
        let pieces = value.components(separatedBy: invalid)
        let result = pieces.joined(separator: "-")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return result.isEmpty ? "TUI" : result
    }
}
