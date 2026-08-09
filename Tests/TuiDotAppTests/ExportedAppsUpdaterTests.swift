import Foundation
import Testing
@testable import TuiDotApp

@Suite("Exported app updates")
struct ExportedAppsUpdaterTests {
    @Test("Only older exported hosts need an automatic refresh")
    func detectsOlderHosts() throws {
        let root = try temporaryDirectory()
        let oldApp = try makeApp(named: "Old", version: "0.1.5", in: root)
        let currentApp = try makeApp(named: "Current", version: "0.1.6", in: root)
        let newerApp = try makeApp(named: "Newer", version: "0.2.0", in: root)

        #expect(ExportedAppsUpdater.needsHostUpdate(at: oldApp, currentHostVersion: "0.1.6"))
        #expect(!ExportedAppsUpdater.needsHostUpdate(at: currentApp, currentHostVersion: "0.1.6"))
        #expect(!ExportedAppsUpdater.needsHostUpdate(at: newerApp, currentHostVersion: "0.1.6"))
    }

    @Test("One failed app does not prevent the others from updating")
    func failureIsIsolated() throws {
        let root = try temporaryDirectory()
        let host = root.appendingPathComponent("host")
        try Data("#!/bin/zsh\nexit 0\n".utf8).write(to: host)

        let workingDestination = root.appendingPathComponent("Working.app", isDirectory: true)
        var working = TuiProfile(name: "Working", command: "working")
        working.exportedAppPath = workingDestination.path

        let brokenDestination = root.appendingPathComponent("Broken.app", isDirectory: true)
        try FileManager.default.createDirectory(at: brokenDestination, withIntermediateDirectories: true)
        let marker = brokenDestination.appendingPathComponent("keep-me")
        try Data("existing".utf8).write(to: marker)
        let badIcon = root.appendingPathComponent("bad.png")
        try Data("not an image".utf8).write(to: badIcon)
        var broken = TuiProfile(name: "Broken", command: "broken", iconPath: badIcon.path)
        broken.exportedAppPath = brokenDestination.path

        let report = ExportedAppsUpdater.update(
            profiles: [broken, working],
            hostExecutable: host,
            resourceBundle: nil,
            frameworksDirectory: nil
        )

        #expect(report.updatedNames == ["Working"])
        #expect(report.failures.map(\.profileName) == ["Broken"])
        #expect(FileManager.default.fileExists(
            atPath: workingDestination.appendingPathComponent("Contents/MacOS/Working").path
        ))
        #expect(try String(contentsOf: marker, encoding: .utf8) == "existing")
    }

    private func temporaryDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    private func makeApp(named name: String, version: String, in root: URL) throws -> URL {
        let app = root.appendingPathComponent("\(name).app", isDirectory: true)
        let contents = app.appendingPathComponent("Contents", isDirectory: true)
        try FileManager.default.createDirectory(at: contents, withIntermediateDirectories: true)
        let info: [String: Any] = ["TuiDotAppHostVersion": version]
        let data = try PropertyListSerialization.data(
            fromPropertyList: info,
            format: .xml,
            options: 0
        )
        try data.write(to: contents.appendingPathComponent("Info.plist"))
        return app
    }
}
