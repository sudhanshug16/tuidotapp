import Foundation
import GhosttyTerminal
import GhosttyTheme

enum GhosttyConfiguration {
    static var availableThemeNames: [String] {
        GhosttyThemeCatalog.allThemes.map(\.name).sorted()
    }

    static func theme(for profile: TuiProfile) -> TerminalTheme {
        let light = GhosttyThemeCatalog.theme(named: profile.lightThemeName)?
            .toTerminalConfiguration() ?? .init()
        let dark = GhosttyThemeCatalog.theme(named: profile.darkThemeName)?
            .toTerminalConfiguration() ?? .init()
        return TerminalTheme(light: light, dark: dark)
    }

    static func source(
        for profile: TuiProfile,
        shell: String,
        input: LaunchInput
    ) -> TerminalController.ConfigSource {
        var lines = [profile.ghosttyConfig]
        lines.append("command = direct:\(shell) -l")
        // LaunchInputStore deliberately uses ~/.config/tuidotapp so this path
        // contains no spaces. Ghostty treats quotes after the `path:` prefix
        // as literal filename characters.
        lines.append("input = path:\(input.url.path)")
        lines.append("shell-integration = detect")
        lines.append("quit-after-last-window-closed = true")
        return .generated(lines.filter { !$0.isEmpty }.joined(separator: "\n"))
    }
}
