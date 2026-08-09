import Foundation

enum ProfileIconStore {
    static func importIcon(from source: URL, profileID: UUID) throws -> URL {
        let fileManager = FileManager.default
        let base = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first ?? fileManager.homeDirectoryForCurrentUser
        let directory = base
            .appendingPathComponent("TuiDotApp", isDirectory: true)
            .appendingPathComponent("icons", isDirectory: true)
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)

        let extensionName = source.pathExtension.isEmpty ? "png" : source.pathExtension.lowercased()
        let destination = directory
            .appendingPathComponent(profileID.uuidString.lowercased())
            .appendingPathExtension(extensionName)
        if source.standardizedFileURL == destination.standardizedFileURL {
            return destination
        }
        let staging = directory.appendingPathComponent(
            ".\(profileID.uuidString.lowercased())-\(UUID().uuidString).tmp"
        )
        defer { try? fileManager.removeItem(at: staging) }
        try fileManager.copyItem(at: source, to: staging)

        guard fileManager.fileExists(atPath: destination.path) else {
            try fileManager.moveItem(at: staging, to: destination)
            return destination
        }

        let backup = directory.appendingPathComponent(
            ".\(profileID.uuidString.lowercased())-\(UUID().uuidString).backup"
        )
        try fileManager.moveItem(at: destination, to: backup)
        do {
            try fileManager.moveItem(at: staging, to: destination)
        } catch {
            try? fileManager.moveItem(at: backup, to: destination)
            throw error
        }
        try? fileManager.removeItem(at: backup)
        return destination
    }

    static func installBundledHerdrIcon(profileID: UUID) -> URL? {
        guard let source = AppResources.url(
            forResource: "HerdrIcon",
            withExtension: "png"
        ) else {
            return nil
        }
        return try? importIcon(from: source, profileID: profileID)
    }
}
