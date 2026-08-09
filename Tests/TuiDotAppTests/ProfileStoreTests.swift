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

        let persisted = try String(contentsOf: fileURL, encoding: .utf8)
        #expect(!persisted.contains("Mach-O"))
    }
}
