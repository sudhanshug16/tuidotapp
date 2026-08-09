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
        if fileManager.fileExists(atPath: destination.path) {
            try fileManager.removeItem(at: destination)
        }
        try fileManager.copyItem(at: source, to: destination)
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
