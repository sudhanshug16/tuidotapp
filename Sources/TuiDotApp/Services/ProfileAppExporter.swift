import Foundation

enum ProfileAppExporterError: LocalizedError {
    case invalidDestination
    case missingHostExecutable
    case signingFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidDestination:
            "Choose a destination ending in .app."
        case .missingHostExecutable:
            "The TuiDotApp host executable could not be found."
        case let .signingFailed(message):
            "The profile app could not be signed: \(message)"
        }
    }
}

enum ProfileAppExporter {
    static func export(
        profile: TuiProfile,
        to destination: URL,
        hostExecutable suppliedHost: URL? = nil,
        resourceBundle suppliedResourceBundle: URL? = nil
    ) throws {
        guard destination.pathExtension.lowercased() == "app" else {
            throw ProfileAppExporterError.invalidDestination
        }
        guard let hostExecutable = suppliedHost ?? Bundle.main.executableURL else {
            throw ProfileAppExporterError.missingHostExecutable
        }

        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }

        let contents = destination.appendingPathComponent("Contents", isDirectory: true)
        let macOS = contents.appendingPathComponent("MacOS", isDirectory: true)
        let resources = contents.appendingPathComponent("Resources", isDirectory: true)
        try fileManager.createDirectory(at: macOS, withIntermediateDirectories: true)
        try fileManager.createDirectory(at: resources, withIntermediateDirectories: true)

        let executableName = sanitizedExecutableName(profile.name)
        let executable = macOS.appendingPathComponent(executableName)
        try fileManager.copyItem(at: hostExecutable, to: executable)
        try fileManager.setAttributes(
            [.posixPermissions: 0o755],
            ofItemAtPath: executable.path
        )

        if let resourceBundle = suppliedResourceBundle ?? AppResources.swiftPMBundleURL,
           fileManager.fileExists(atPath: resourceBundle.path)
        {
            try fileManager.copyItem(
                at: resourceBundle,
                to: resources.appendingPathComponent(resourceBundle.lastPathComponent)
            )
        }

        var iconFile: String?
        if let iconPath = profile.iconPath, fileManager.fileExists(atPath: iconPath) {
            let destination = resources.appendingPathComponent("AppIcon.icns")
            try IconAssetBuilder.createICNS(
                from: URL(fileURLWithPath: iconPath),
                at: destination
            )
            iconFile = "AppIcon"
        }

        let safeBundleComponent = profile.id.uuidString.lowercased()
        var info: [String: Any] = [
            "CFBundleDevelopmentRegion": "en",
            "CFBundleDisplayName": profile.name,
            "CFBundleExecutable": executableName,
            "CFBundleIdentifier": "app.tui.desktop.profile.\(safeBundleComponent)",
            "CFBundleInfoDictionaryVersion": "6.0",
            "CFBundleName": profile.name,
            "CFBundlePackageType": "APPL",
            "CFBundleShortVersionString": "1.0",
            "CFBundleVersion": "1",
            "LSMinimumSystemVersion": "14.0",
            "NSHighResolutionCapable": true,
            "NSQuitAlwaysKeepsWindows": false,
            "TuiDotAppProfileID": profile.id.uuidString,
        ]
        if let iconFile {
            info["CFBundleIconFile"] = iconFile
        }
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

    private static func sanitizedExecutableName(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalars = value.unicodeScalars.filter { allowed.contains($0) }
        let result = String(String.UnicodeScalarView(scalars))
        return result.isEmpty ? "TUI" : result
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
