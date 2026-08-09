import Foundation
import Testing
@testable import TuiDotApp

@Suite("Thin profile app export")
struct ProfileAppExporterTests {
    @Test("Exported apps contain a deep link but no TUI command or binary")
    func thinExport() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let destination = root.appendingPathComponent("Herdr.app", isDirectory: true)
        let profile = TuiProfile(name: "Herdr", command: "secret-tool --token hidden")

        try ProfileAppExporter.export(profile: profile, to: destination)

        let executable = destination
            .appendingPathComponent("Contents/MacOS/LaunchTUI")
        let script = try String(contentsOf: executable, encoding: .utf8)
        #expect(script.contains(ProfileDeepLink.launch(profile.id).url.absoluteString))
        #expect(!script.contains(profile.command))

        let bundledExecutables = try FileManager.default.contentsOfDirectory(
            atPath: destination.appendingPathComponent("Contents/MacOS").path
        )
        #expect(bundledExecutables == ["LaunchTUI"])
        #expect(Data(script.utf8).prefix(4) != Data([0xCF, 0xFA, 0xED, 0xFE]))
    }
}
