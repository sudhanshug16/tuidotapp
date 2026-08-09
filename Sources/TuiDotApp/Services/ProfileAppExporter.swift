import Foundation

enum ProfileAppExporterError: LocalizedError {
    case invalidDestination
    case signingFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidDestination:
            "Choose a destination ending in .app."
        case let .signingFailed(message):
            "The launcher app could not be signed: \(message)"
        }
    }
}

enum ProfileAppExporter {
    static func export(profile: TuiProfile, to destination: URL) throws {
        guard destination.pathExtension.lowercased() == "app" else {
            throw ProfileAppExporterError.invalidDestination
        }

        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }

        let contents = destination.appendingPathComponent("Contents", isDirectory: true)
        let macOS = contents.appendingPathComponent("MacOS", isDirectory: true)
        try fileManager.createDirectory(at: macOS, withIntermediateDirectories: true)

        let executable = macOS.appendingPathComponent("LaunchTUI")
        let deepLink = ProfileDeepLink.launch(profile.id).url.absoluteString
        let script = """
        #!/bin/zsh
        exec /usr/bin/open '\(deepLink)'

        """
        try Data(script.utf8).write(to: executable, options: .atomic)
        try fileManager.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: executable.path
        )

        let safeBundleComponent = profile.id.uuidString.lowercased()
        let info: [String: Any] = [
            "CFBundleDevelopmentRegion": "en",
            "CFBundleDisplayName": profile.name,
            "CFBundleExecutable": "LaunchTUI",
            "CFBundleIdentifier": "app.tui.desktop.profile.\(safeBundleComponent)",
            "CFBundleInfoDictionaryVersion": "6.0",
            "CFBundleName": profile.name,
            "CFBundlePackageType": "APPL",
            "CFBundleShortVersionString": "1.0",
            "CFBundleVersion": "1",
            "LSMinimumSystemVersion": "14.0",
            "NSHighResolutionCapable": true,
        ]
        let plist = try PropertyListSerialization.data(
            fromPropertyList: info,
            format: .xml,
            options: 0
        )
        try plist.write(
            to: contents.appendingPathComponent("Info.plist"),
            options: .atomic
        )

        try sign(app: destination)
    }

    private static func sign(app: URL) throws {
        let process = Process()
        let errors = Pipe()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/codesign")
        process.arguments = ["--force", "--deep", "--sign", "-", app.path]
        process.standardError = errors
        try process.run()
        process.waitUntilExit()
        guard process.terminationStatus == 0 else {
            let data = errors.fileHandleForReading.readDataToEndOfFile()
            let message = String(decoding: data, as: UTF8.self)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            throw ProfileAppExporterError.signingFailed(message)
        }
    }
}
