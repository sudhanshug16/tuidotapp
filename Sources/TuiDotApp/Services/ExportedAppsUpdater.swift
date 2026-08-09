import Foundation

struct ExportedAppUpdateFailure: Identifiable, Sendable {
    let profileName: String
    let path: String
    let message: String

    var id: String { path }
}

struct ExportedAppsUpdateReport: Identifiable, Sendable {
    let id = UUID()
    let updatedNames: [String]
    let failures: [ExportedAppUpdateFailure]

    var title: String {
        failures.isEmpty ? "Exported apps updated" : "Some apps could not be updated"
    }

    var message: String {
        var lines: [String] = []
        if !updatedNames.isEmpty {
            lines.append("Updated: \(updatedNames.joined(separator: ", ")).")
            lines.append("Quit and reopen any of these apps that are already running.")
        }
        if !failures.isEmpty {
            lines.append(contentsOf: failures.map {
                "\($0.profileName): \($0.message)"
            })
        }
        return lines.joined(separator: "\n\n")
    }
}

enum ExportedAppsUpdater {
    static func existingExportedProfiles(
        in profiles: [TuiProfile],
        fileManager: FileManager = .default
    ) -> [TuiProfile] {
        profiles.filter { profile in
            guard let path = profile.exportedAppPath else { return false }
            return fileManager.fileExists(atPath: path)
        }
    }

    static func profilesNeedingHostUpdate(
        in profiles: [TuiProfile],
        currentHostVersion: String,
        fileManager: FileManager = .default
    ) -> [TuiProfile] {
        existingExportedProfiles(in: profiles, fileManager: fileManager).filter { profile in
            guard let path = profile.exportedAppPath else { return false }
            return needsHostUpdate(
                at: URL(fileURLWithPath: path),
                currentHostVersion: currentHostVersion
            )
        }
    }

    static func needsHostUpdate(at appURL: URL, currentHostVersion: String) -> Bool {
        guard let installedString = installedHostVersion(at: appURL) else { return true }
        guard let installed = AppVersion(installedString),
              let current = AppVersion(currentHostVersion)
        else {
            return installedString != currentHostVersion
        }
        return installed < current
    }

    static func installedHostVersion(at appURL: URL) -> String? {
        let infoURL = appURL
            .appendingPathComponent("Contents", isDirectory: true)
            .appendingPathComponent("Info.plist")
        guard let data = try? Data(contentsOf: infoURL),
              let value = try? PropertyListSerialization.propertyList(
                from: data,
                options: [],
                format: nil
              ),
              let info = value as? [String: Any]
        else {
            return nil
        }
        return info["TuiDotAppHostVersion"] as? String
            ?? info["CFBundleShortVersionString"] as? String
    }

    static func update(
        profiles: [TuiProfile],
        hostExecutable: URL?,
        resourceBundle: URL?,
        frameworksDirectory: URL?
    ) -> ExportedAppsUpdateReport {
        var updatedNames: [String] = []
        var failures: [ExportedAppUpdateFailure] = []

        for profile in profiles {
            guard let path = profile.exportedAppPath else { continue }
            do {
                try ProfileAppExporter.export(
                    profile: profile,
                    to: URL(fileURLWithPath: path),
                    hostExecutable: hostExecutable,
                    resourceBundle: resourceBundle,
                    frameworksDirectory: frameworksDirectory
                )
                updatedNames.append(profile.name)
            } catch {
                failures.append(ExportedAppUpdateFailure(
                    profileName: profile.name,
                    path: path,
                    message: error.localizedDescription
                ))
            }
        }

        return ExportedAppsUpdateReport(
            updatedNames: updatedNames,
            failures: failures
        )
    }
}
