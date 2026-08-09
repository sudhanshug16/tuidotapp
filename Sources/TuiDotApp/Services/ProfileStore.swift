import Combine
import Foundation

@MainActor
final class ProfileStore: ObservableObject {
    @Published private(set) var profiles: [TuiProfile] = []
    @Published var selectedProfileID: TuiProfile.ID?
    @Published private(set) var persistenceError: String?

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
        let profile = TuiProfile()
        profiles.append(profile)
        selectedProfileID = profile.id
        save()
    }

    func addHerdrExampleIfEmpty() {
        guard profiles.isEmpty else { return }
        var profile = TuiProfile.herdrExample
        profile.iconPath = ProfileIconStore.installBundledHerdrIcon(
            profileID: profile.id
        )?.path
        profiles = [profile]
        selectedProfileID = profiles[0].id
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
            persistenceError = nil
            if migrated { save() }
        } catch let error as CocoaError where error.code == .fileReadNoSuchFile {
            profiles = []
        } catch {
            profiles = []
            persistenceError = "Profiles could not be loaded: \(error.localizedDescription)"
        }
    }

    private func save() {
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
}
