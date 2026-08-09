import Foundation

enum ProfileAppExporterError: LocalizedError, Equatable {
    case invalidDestination
    case destinationBelongsToAnotherApp
    case missingHostExecutable
    case signingFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidDestination:
            "Choose a destination ending in .app."
        case .destinationBelongsToAnotherApp:
            "The existing app at this location was not created from this profile, so it was left untouched."
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
        resourceBundle suppliedResourceBundle: URL? = nil,
        frameworksDirectory suppliedFrameworksDirectory: URL? = nil
    ) throws {
        guard destination.pathExtension.lowercased() == "app" else {
            throw ProfileAppExporterError.invalidDestination
        }
        guard let hostExecutable = suppliedHost ?? Bundle.main.executableURL else {
            throw ProfileAppExporterError.missingHostExecutable
        }

        let fileManager = FileManager.default
        if fileManager.fileExists(atPath: destination.path),
           exportedProfileID(at: destination) != profile.id
        {
            throw ProfileAppExporterError.destinationBelongsToAnotherApp
        }
        let staging = destination.deletingLastPathComponent()
            .appendingPathComponent(".tuidotapp-export-\(UUID().uuidString).app", isDirectory: true)
        defer { try? fileManager.removeItem(at: staging) }

        let contents = staging.appendingPathComponent("Contents", isDirectory: true)
        let macOS = contents.appendingPathComponent("MacOS", isDirectory: true)
        let resources = contents.appendingPathComponent("Resources", isDirectory: true)
        let frameworks = contents.appendingPathComponent("Frameworks", isDirectory: true)
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

        if let frameworkRoot = suppliedFrameworksDirectory ?? Bundle.main.privateFrameworksURL {
            let sparkle = frameworkRoot.appendingPathComponent("Sparkle.framework", isDirectory: true)
            if fileManager.fileExists(atPath: sparkle.path) {
                try fileManager.createDirectory(at: frameworks, withIntermediateDirectories: true)
                try fileManager.copyItem(
                    at: sparkle,
                    to: frameworks.appendingPathComponent("Sparkle.framework", isDirectory: true)
                )
            }
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
        let hostVersion = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "development"
        let hostBuild = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        var info: [String: Any] = [
            "CFBundleDevelopmentRegion": "en",
            "CFBundleDisplayName": profile.name,
            "CFBundleExecutable": executableName,
            "CFBundleIdentifier": "app.tui.desktop.profile.\(safeBundleComponent)",
            "CFBundleInfoDictionaryVersion": "6.0",
            "CFBundleName": profile.name,
            "CFBundlePackageType": "APPL",
            "CFBundleShortVersionString": hostVersion,
            "CFBundleVersion": hostBuild,
            "LSMinimumSystemVersion": "14.0",
            "LSMultipleInstancesProhibited": true,
            "NSHighResolutionCapable": true,
            "NSQuitAlwaysKeepsWindows": false,
            "TuiDotAppProfileID": profile.id.uuidString,
            "TuiDotAppHostVersion": hostVersion,
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

        try sign(app: staging)
        try install(staging, at: destination)
    }

    private static func sanitizedExecutableName(_ value: String) -> String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let scalars = value.unicodeScalars.filter { allowed.contains($0) }
        let result = String(String.UnicodeScalarView(scalars))
        return result.isEmpty ? "TUI" : result
    }

    private static func exportedProfileID(at appURL: URL) -> UUID? {
        let infoURL = appURL.appendingPathComponent("Contents/Info.plist")
        guard let data = try? Data(contentsOf: infoURL),
              let value = try? PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: nil
              ),
              let info = value as? [String: Any],
              let rawID = info["TuiDotAppProfileID"] as? String
        else {
            return nil
        }
        return UUID(uuidString: rawID)
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

    private static func install(_ staging: URL, at destination: URL) throws {
        let fileManager = FileManager.default
        guard fileManager.fileExists(atPath: destination.path) else {
            try fileManager.moveItem(at: staging, to: destination)
            return
        }

        let backup = destination.deletingLastPathComponent()
            .appendingPathComponent(".tuidotapp-backup-\(UUID().uuidString).app", isDirectory: true)
        try fileManager.moveItem(at: destination, to: backup)
        do {
            try fileManager.moveItem(at: staging, to: destination)
        } catch {
            if !fileManager.fileExists(atPath: destination.path) {
                try? fileManager.moveItem(at: backup, to: destination)
            }
            throw error
        }
        try? fileManager.removeItem(at: backup)
    }
}
