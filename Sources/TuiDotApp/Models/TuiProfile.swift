import Foundation

enum LaunchKind: String, Codable, CaseIterable, Identifiable, Sendable {
    case local
    case ssh

    var id: Self { self }

    var label: String {
        switch self {
        case .local: "Local"
        case .ssh: "SSH"
        }
    }
}

struct TuiProfile: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var name: String
    var kind: LaunchKind
    var command: String
    var workingDirectory: String
    var sshDestination: String
    var sshArguments: String
    var lightThemeName: String
    var darkThemeName: String
    var ghosttyConfig: String
    var iconPath: String?
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = UUID(),
        name: String = "New TUI",
        kind: LaunchKind = .local,
        command: String = "",
        workingDirectory: String = "~",
        sshDestination: String = "",
        sshArguments: String = "",
        lightThemeName: String = "Catppuccin Latte",
        darkThemeName: String = "Catppuccin Mocha",
        ghosttyConfig: String = "font-size = 14\nwindow-padding-x = 8\nwindow-padding-y = 8",
        iconPath: String? = nil,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.name = name
        self.kind = kind
        self.command = command
        self.workingDirectory = workingDirectory
        self.sshDestination = sshDestination
        self.sshArguments = sshArguments
        self.lightThemeName = lightThemeName
        self.darkThemeName = darkThemeName
        self.ghosttyConfig = ghosttyConfig
        self.iconPath = iconPath
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    static let herdrExample = TuiProfile(
        name: "Herdr",
        command: "herdr"
    )
}
