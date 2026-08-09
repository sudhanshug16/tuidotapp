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
        let data = try JSONSerialization.data(withJSONObject: object)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(TuiProfile.self, from: data)

        #expect(!decoded.mapCommandToControl)
    }
}
