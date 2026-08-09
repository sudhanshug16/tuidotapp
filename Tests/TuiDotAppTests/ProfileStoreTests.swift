import Foundation
import Testing
@testable import TuiDotApp

@Suite("Profile persistence")
@MainActor
struct ProfileStoreTests {
    @Test("Profiles persist without embedding executable contents")
    func roundTrip() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let fileURL = directory.appendingPathComponent("profiles.json")
        let store = ProfileStore(fileURL: fileURL)
        store.addHerdrExampleIfEmpty()

        let loaded = ProfileStore(fileURL: fileURL)
        #expect(loaded.profiles.count == 1)
        #expect(loaded.profiles[0].command == "herdr")
        #expect(!loaded.profiles[0].mapCommandToControl)
        #expect(loaded.profiles[0].commandToControlExclusions == "c, v")

        let persisted = try String(contentsOf: fileURL, encoding: .utf8)
        #expect(!persisted.contains("Mach-O"))
    }

    @Test("Profiles created before key remapping default it off")
    func legacyProfileDefaultsKeyRemappingOff() throws {
        let profile = TuiProfile(name: "Legacy", command: "legacy")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        var object = try #require(
            JSONSerialization.jsonObject(with: encoder.encode(profile)) as? [String: Any]
        )
        object.removeValue(forKey: "mapCommandToControl")
        object.removeValue(forKey: "commandToControlExclusions")
        object.removeValue(forKey: "exportedAppPath")
        let data = try JSONSerialization.data(withJSONObject: object)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(TuiProfile.self, from: data)

        #expect(!decoded.mapCommandToControl)
        #expect(decoded.commandToControlExclusions == "c, v")
        #expect(decoded.exportedAppPath == nil)
    }

    @Test("An unreadable profile library is never overwritten during startup")
    func unreadableLibraryIsPreserved() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("profiles.json")
        let original = Data("{ definitely-not-json".utf8)
        try original.write(to: fileURL)

        let store = ProfileStore(fileURL: fileURL)
        #expect(store.loadError != nil)
        store.addDefaultProfileIfEmpty()

        #expect(store.profiles.isEmpty)
        #expect(try Data(contentsOf: fileURL) == original)
    }

    @Test("Resetting an unreadable library keeps a backup")
    func resetKeepsBackup() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let fileURL = directory.appendingPathComponent("profiles.json")
        let original = Data("broken".utf8)
        try original.write(to: fileURL)
        let store = ProfileStore(fileURL: fileURL)

        let backup = try store.resetProfilesKeepingBackup()

        #expect(try Data(contentsOf: backup) == original)
        #expect(store.loadError == nil)
        #expect(store.profiles.count == 1)
        #expect(store.profiles[0].name == "New TUI")
    }
}
