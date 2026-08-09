import AppKit
import Foundation
import Testing
@testable import TuiDotApp

@Suite("Standalone profile app export")
struct ProfileAppExporterTests {
    @Test("Exported apps run their own host process without embedding the TUI command")
    func independentHostExport() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let destination = root.appendingPathComponent("Herdr.app", isDirectory: true)
        let host = root.appendingPathComponent("host")
        let hostContents = "#!/bin/zsh\nexit 0\n"
        try Data(hostContents.utf8).write(to: host)
        let profile = TuiProfile(name: "Herdr", command: "secret-tool --token hidden")

        try ProfileAppExporter.export(
            profile: profile,
            to: destination,
            hostExecutable: host
        )

        let executable = destination.appendingPathComponent("Contents/MacOS/Herdr")
        #expect(try String(contentsOf: executable, encoding: .utf8) == hostContents)
        #expect(!String(decoding: try Data(contentsOf: executable), as: UTF8.self).contains(profile.command))

        let info = try propertyList(at: destination.appendingPathComponent("Contents/Info.plist"))
        #expect(info["CFBundleDisplayName"] as? String == "Herdr")
        #expect(info["CFBundleExecutable"] as? String == "Herdr")
        #expect(info["TuiDotAppProfileID"] as? String == profile.id.uuidString)
    }

    @Test("Selected profile artwork is compiled into a macOS icon")
    func iconExport() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let destination = root.appendingPathComponent("Herdr.app", isDirectory: true)
        let host = root.appendingPathComponent("host")
        try Data("#!/bin/zsh\nexit 0\n".utf8).write(to: host)
        let icon = try #require(AppResources.url(forResource: "HerdrIcon", withExtension: "png"))
        let profile = TuiProfile(name: "Herdr", command: "herdr", iconPath: icon.path)

        try ProfileAppExporter.export(
            profile: profile,
            to: destination,
            hostExecutable: host
        )

        let iconURL = destination.appendingPathComponent("Contents/Resources/AppIcon.icns")
        #expect(FileManager.default.fileExists(atPath: iconURL.path))
        #expect(NSImage(contentsOf: iconURL)?.isValid == true)
        let info = try propertyList(at: destination.appendingPathComponent("Contents/Info.plist"))
        #expect(info["CFBundleIconFile"] as? String == "AppIcon")
    }

    private func propertyList(at url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url)
        return try #require(
            PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        )
    }
}
