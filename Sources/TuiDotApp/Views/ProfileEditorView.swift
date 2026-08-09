import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ProfileEditorView: View {
    @EnvironmentObject private var store: ProfileStore
    @State private var draft: TuiProfile
    @State private var launchError: String?
    @State private var exportError: String?
    @State private var lastExportedAppURL: URL?

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
                Toggle("Send Command shortcuts as Control", isOn: $draft.mapCommandToControl)
                    .toggleStyle(.checkbox)
                if draft.mapCommandToControl {
                    TextField(
                        "Keep as Command",
                        text: $draft.commandToControlExclusions,
                        prompt: Text("c, v")
                    )
                    .font(.system(.body, design: .monospaced))
                    Text("Comma-separated keys that keep normal Mac behavior. C and V preserve Copy and Paste; ⌘Q always quits the app.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Other Command shortcuts reach the TUI as their Control equivalents.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
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

            if let message = draft.exportValidationMessage {
                Section {
                    Label(message, systemImage: "info.circle")
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
                if let installedAppURL {
                    LabeledContent("Created app") {
                        HStack(spacing: 12) {
                            Text(installedAppURL.path)
                                .lineLimit(1)
                                .truncationMode(.middle)
                                .foregroundStyle(.secondary)
                            Button("Show") {
                                NSWorkspace.shared.activateFileViewerSelecting([installedAppURL])
                            }
                            Button("Choose New Location…") {
                                exportLauncherApp(alwaysChooseDestination: true)
                            }
                        }
                    }
                }
                Text("PNG, JPEG, and ICNS images are compiled into the exported app. The TUI executable is still resolved externally at launch.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Theme") {
                ThemePickerButton(
                    title: "Light appearance",
                    selection: $draft.lightThemeName
                )
                ThemePickerButton(
                    title: "Dark appearance",
                    selection: $draft.darkThemeName
                )

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
                    Label(
                        installedAppURL == nil ? "Create App…" : "Update App",
                        systemImage: installedAppURL == nil ? "plus.app" : "arrow.triangle.2.circlepath"
                    )
                }
                .disabled(draft.exportValidationMessage != nil)
                .help("Create or replace a standalone app on this Mac")

                Button {
                    launch()
                } label: {
                    Label("Launch", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.return, modifiers: [.command])
                .disabled(draft.launchValidationMessage != nil)
            }
        }
        .alert("App created", isPresented: Binding(
            get: { lastExportedAppURL != nil },
            set: { if !$0 { lastExportedAppURL = nil } }
        )) {
            Button("Open App") {
                if let lastExportedAppURL {
                    NSWorkspace.shared.open(lastExportedAppURL)
                }
            }
            Button("Show in Finder") {
                if let lastExportedAppURL {
                    NSWorkspace.shared.activateFileViewerSelecting([lastExportedAppURL])
                }
            }
            Button("Done", role: .cancel) {}
        } message: {
            Text("\(lastExportedAppURL?.lastPathComponent ?? "The app") is ready. Its settings stay linked to this profile; use Update App after updating TuiDotApp to refresh the bundled terminal host.")
        }
        .alert("Could not create app", isPresented: Binding(
            get: { exportError != nil },
            set: { if !$0 { exportError = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(exportError ?? "Unknown error")
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

    private func exportLauncherApp(alwaysChooseDestination: Bool = false) {
        store.update(draft)
        let url: URL
        if !alwaysChooseDestination, let existing = installedAppURL {
            url = existing
        } else {
            let panel = NSSavePanel()
            panel.title = "Create TUI App"
            panel.prompt = "Create App"
            panel.nameFieldStringValue = sanitizedAppName(draft.name) + ".app"
            panel.allowedContentTypes = [.application]
            panel.canCreateDirectories = true
            let applications = URL(fileURLWithPath: "/Applications", isDirectory: true)
            if FileManager.default.fileExists(atPath: applications.path) {
                panel.directoryURL = applications
            }
            guard panel.runModal() == .OK, let selectedURL = panel.url else { return }
            url = selectedURL
        }

        do {
            try ProfileAppExporter.export(profile: draft, to: url)
            draft.exportedAppPath = url.path
            store.update(draft)
            lastExportedAppURL = url
        } catch {
            exportError = error.localizedDescription
        }
    }

    private var selectedIcon: NSImage? {
        guard let iconPath = draft.iconPath else { return nil }
        return NSImage(contentsOfFile: iconPath)
    }

    private var installedAppURL: URL? {
        guard let path = draft.exportedAppPath else { return nil }
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return url
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

private struct ThemePickerButton: View {
    let title: String
    @Binding var selection: String
    @State private var isPresented = false

    var body: some View {
        LabeledContent(title) {
            Button(selection) {
                isPresented = true
            }
            .buttonStyle(.borderless)
        }
        .sheet(isPresented: $isPresented) {
            ThemePickerSheet(title: title, selection: $selection)
        }
    }
}

private struct ThemePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    let title: String
    @Binding var selection: String
    @State private var query = ""

    private var filteredThemes: [String] {
        guard !query.isEmpty else { return GhosttyConfiguration.availableThemeNames }
        return GhosttyConfiguration.availableThemeNames.filter {
            $0.localizedCaseInsensitiveContains(query)
        }
    }

    var body: some View {
        NavigationStack {
            List(filteredThemes, id: \.self) { theme in
                Button {
                    selection = theme
                    dismiss()
                } label: {
                    HStack {
                        Text(theme)
                            .foregroundStyle(.primary)
                        Spacer()
                        if theme == selection {
                            Image(systemName: "checkmark")
                                .foregroundStyle(Color.accentColor)
                        }
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
            .overlay {
                if filteredThemes.isEmpty {
                    ContentUnavailableView.search(text: query)
                }
            }
            .searchable(text: $query, prompt: "Search themes")
            .navigationTitle(title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .frame(minWidth: 440, minHeight: 520)
    }
}
