import Foundation

struct LaunchInput: Sendable {
    let id: UUID
    let url: URL
}

enum LaunchInputStore {
    static func create(contents: String) throws -> LaunchInput {
        let id = UUID()
        let directory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".config", isDirectory: true)
            .appendingPathComponent("tuidotapp", isDirectory: true)
            .appendingPathComponent("launch-inputs", isDirectory: true)
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let url = directory.appendingPathComponent(id.uuidString)
        try Data(contents.utf8).write(to: url, options: [.atomic])
        return LaunchInput(id: id, url: url)
    }

    static func remove(_ input: LaunchInput) {
        try? FileManager.default.removeItem(at: input.url)
    }
}
