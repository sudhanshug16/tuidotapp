import Foundation

enum LaunchCommandError: LocalizedError, Equatable {
    case missingCommand
    case missingSSHDestination

    var errorDescription: String? {
        switch self {
        case .missingCommand: "Enter the TUI command to launch."
        case .missingSSHDestination: "Enter an SSH host or alias."
        }
    }
}

enum LaunchCommandBuilder {
    static func startupInput(for profile: TuiProfile) throws -> String {
        let command = profile.command.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !command.isEmpty else { throw LaunchCommandError.missingCommand }

        switch profile.kind {
        case .local:
            return "exec \(command)\n"

        case .ssh:
            let destination = profile.sshDestination
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !destination.isEmpty else {
                throw LaunchCommandError.missingSSHDestination
            }

            let extra = profile.sshArguments.trimmingCharacters(in: .whitespacesAndNewlines)
            let extraSegment = extra.isEmpty ? "" : " \(extra)"
            // xterm-256color is widely installed on remote hosts. Advertising
            // xterm-ghostty without first installing its terminfo entry can
            // leave remote TUIs partially rendered with no obvious error.
            return "exec env TERM=xterm-256color /usr/bin/ssh -tt\(extraSegment) -- \(shellQuote(destination)) \(shellQuote(command))\n"
        }
    }

    static func shellQuote(_ value: String) -> String {
        "'\(value.replacingOccurrences(of: "'", with: "'\\''"))'"
    }
}
