import Combine
import Foundation

@MainActor
final class ProfileStore: ObservableObject {
    @Published private(set) var profiles: [TuiProfile] = []
    @Published var selectedProfileID: TuiProfile.ID?
    @Published private(set) var persistenceError: String?
    @Published private(set) var loadError: String?

    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    convenience init() {
        let base = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? FileManager.default.homeDirectoryForCurrentUser
        self.init(fileURL: base
            .appendingPathComponent("TuiDotApp", isDirectory: true)
            .appendingPathComponent("profiles.json"))
    }

    init(fileURL: URL) {
        self.fileURL = fileURL
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        load()
    }

    var selectedProfile: TuiProfile? {
        guard let selectedProfileID else { return nil }
        return profiles.first { $0.id == selectedProfileID }
    }

    func profile(withID id: TuiProfile.ID) -> TuiProfile? {
        profiles.first { $0.id == id }
    }

    func addProfile() {
        guard loadError == nil else { return }
        let profile = TuiProfile()
        profiles.append(profile)
        selectedProfileID = profile.id
        save()
    }

    func addHerdrExampleIfEmpty() {
        guard profiles.isEmpty, loadError == nil else { return }
        var profile = TuiProfile.herdrExample
        profile.iconPath = ProfileIconStore.installBundledHerdrIcon(
            profileID: profile.id
        )?.path
        profiles = [profile]
        selectedProfileID = profiles[0].id
        save()
    }

    func addDefaultProfileIfEmpty() {
        guard profiles.isEmpty, loadError == nil else { return }
        addProfile()
    }

    func duplicateSelectedProfile() {
        guard loadError == nil, var profile = selectedProfile else { return }
        profile.id = UUID()
        profile.name = profile.name.trimmingCharacters(in: .whitespacesAndNewlines) + " Copy"
        profile.createdAt = .now
        profile.updatedAt = .now
        profile.exportedAppPath = nil
        profiles.append(profile)
        selectedProfileID = profile.id
        save()
    }

    func update(_ profile: TuiProfile) {
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else { return }
        var updated = profile
        updated.updatedAt = .now
        profiles[index] = updated
        save()
    }

    func deleteSelectedProfile() {
        guard let selectedProfileID else { return }
        profiles.removeAll { $0.id == selectedProfileID }
        self.selectedProfileID = profiles.first?.id
        save()
    }

    func dismissPersistenceError() {
        persistenceError = nil
    }

    var storageURL: URL { fileURL }

    @discardableResult
    func resetProfilesKeepingBackup() throws -> URL {
        let fileManager = FileManager.default
        let backupURL = uniqueBackupURL()
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.copyItem(at: fileURL, to: backupURL)
            try fileManager.removeItem(at: fileURL)
        }
        profiles = []
        selectedProfileID = nil
        loadError = nil
        persistenceError = nil
        addProfile()
        return backupURL
    }

    private func load() {
        do {
            let data = try Data(contentsOf: fileURL)
            profiles = try decoder.decode([TuiProfile].self, from: data)
            var migrated = false
            for index in profiles.indices where
                profiles[index].name == "Herdr" && profiles[index].command == "herdr"
            {
                if profiles[index].iconPath == nil ||
                    profiles[index].iconPath?.contains("tuidotapp_TuiDotApp.bundle/HerdrIcon.png") == true
                {
                    profiles[index].iconPath = ProfileIconStore.installBundledHerdrIcon(
                        profileID: profiles[index].id
                    )?.path
                    migrated = true
                }
                let legacyTitlebar = "macos-titlebar-style = tabs"
                if profiles[index].ghosttyConfig.contains(legacyTitlebar) {
                    profiles[index].ghosttyConfig = profiles[index].ghosttyConfig
                        .components(separatedBy: .newlines)
                        .filter { $0.trimmingCharacters(in: .whitespaces) != legacyTitlebar }
                        .joined(separator: "\n")
                    migrated = true
                }
            }
            selectedProfileID = profiles.first?.id
            loadError = nil
            persistenceError = nil
            if migrated { save() }
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            profiles = []
            loadError = nil
        } catch {
            profiles = []
            loadError = "The profile library could not be read. The original file has not been changed. \(error.localizedDescription)"
        }
    }

    private func save() {
        guard loadError == nil else { return }
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try encoder.encode(profiles).write(to: fileURL, options: .atomic)
            persistenceError = nil
        } catch {
            persistenceError = "Profiles could not be saved: \(error.localizedDescription)"
        }
    }


    private func uniqueBackupURL() -> URL {
        let directory = fileURL.deletingLastPathComponent()
        let base = fileURL.deletingPathExtension().lastPathComponent
        let formatter = ISO8601DateFormatter()
        let stamp = formatter.string(from: .now)
            .replacingOccurrences(of: ":", with: "-")
        return directory.appendingPathComponent("\(base)-unreadable-\(stamp).json")
    }
}
