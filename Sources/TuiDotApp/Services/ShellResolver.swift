import Darwin
import Foundation

enum ShellResolver {
    static func loginShell() -> String {
        if let shell = ProcessInfo.processInfo.environment["SHELL"],
           shell.hasPrefix("/")
        {
            return shell
        }

        if let entry = getpwuid(getuid()), let shell = entry.pointee.pw_shell {
            let value = String(cString: shell)
            if value.hasPrefix("/") {
                return value
            }
        }

        return "/bin/zsh"
    }
}
