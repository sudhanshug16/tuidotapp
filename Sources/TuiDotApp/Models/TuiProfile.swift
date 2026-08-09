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
    var mapCommandToControl: Bool
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
        mapCommandToControl: Bool = false,
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
        self.mapCommandToControl = mapCommandToControl
        self.iconPath = iconPath
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    static let herdrExample = TuiProfile(
        name: "Herdr",
        command: "herdr"
    )

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case kind
        case command
        case workingDirectory
        case sshDestination
        case sshArguments
        case lightThemeName
        case darkThemeName
        case ghosttyConfig
        case mapCommandToControl
        case iconPath
        case createdAt
        case updatedAt
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        name = try container.decode(String.self, forKey: .name)
        kind = try container.decode(LaunchKind.self, forKey: .kind)
        command = try container.decode(String.self, forKey: .command)
        workingDirectory = try container.decode(String.self, forKey: .workingDirectory)
        sshDestination = try container.decode(String.self, forKey: .sshDestination)
        sshArguments = try container.decode(String.self, forKey: .sshArguments)
        lightThemeName = try container.decode(String.self, forKey: .lightThemeName)
        darkThemeName = try container.decode(String.self, forKey: .darkThemeName)
        ghosttyConfig = try container.decode(String.self, forKey: .ghosttyConfig)
        mapCommandToControl = try container.decodeIfPresent(
            Bool.self,
            forKey: .mapCommandToControl
        ) ?? false
        iconPath = try container.decodeIfPresent(String.self, forKey: .iconPath)
        createdAt = try container.decode(Date.self, forKey: .createdAt)
        updatedAt = try container.decode(Date.self, forKey: .updatedAt)
    }
}
