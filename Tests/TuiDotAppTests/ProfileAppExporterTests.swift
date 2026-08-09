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
        #expect(info["LSMultipleInstancesProhibited"] as? Bool == true)
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

    @Test("A failed replacement leaves the existing app untouched")
    func failedReplacementIsNonDestructive() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let destination = root.appendingPathComponent("Existing.app", isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let marker = destination.appendingPathComponent("keep-me")
        try Data("existing".utf8).write(to: marker)
        let host = root.appendingPathComponent("host")
        try Data("#!/bin/zsh\nexit 0\n".utf8).write(to: host)
        let invalidIcon = root.appendingPathComponent("invalid.png")
        try Data("not an image".utf8).write(to: invalidIcon)
        let profile = TuiProfile(name: "Broken", command: "broken", iconPath: invalidIcon.path)
        let contents = destination.appendingPathComponent("Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        let infoData = try PropertyListSerialization.data(
            fromPropertyList: ["TuiDotAppProfileID": profile.id.uuidString],
            format: .xml,
            options: 0
        )
        try infoData.write(to: contents.appendingPathComponent("Info.plist"))

        #expect(throws: IconAssetBuilderError.self) {
            try ProfileAppExporter.export(
                profile: profile,
                to: destination,
                hostExecutable: host
            )
        }

        #expect(try String(contentsOf: marker, encoding: .utf8) == "existing")
    }

    @Test("An existing app from another profile is never overwritten")
    func foreignAppIsNotOverwritten() throws {
        let root = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        let destination = root.appendingPathComponent("Existing.app", isDirectory: true)
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)
        let marker = destination.appendingPathComponent("keep-me")
        try Data("existing".utf8).write(to: marker)
        let host = root.appendingPathComponent("host")
        try Data("#!/bin/zsh\nexit 0\n".utf8).write(to: host)

        #expect(throws: ProfileAppExporterError.destinationBelongsToAnotherApp) {
            try ProfileAppExporter.export(
                profile: TuiProfile(name: "Replacement", command: "replacement"),
                to: destination,
                hostExecutable: host
            )
        }

        #expect(try String(contentsOf: marker, encoding: .utf8) == "existing")
    }

    private func propertyList(at url: URL) throws -> [String: Any] {
        let data = try Data(contentsOf: url)
        return try #require(
            PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any]
        )
    }
}
