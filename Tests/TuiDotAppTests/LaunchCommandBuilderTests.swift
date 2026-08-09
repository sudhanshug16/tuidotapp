import Foundation
import Testing
@testable import TuiDotApp

@Suite("Launch command builder")
struct LaunchCommandBuilderTests {
    @Test("Local commands replace the login shell")
    func localCommand() throws {
        let profile = TuiProfile(command: "herdr")
        #expect(try LaunchCommandBuilder.startupInput(for: profile) == "exec herdr\n")
    }

    @Test("SSH uses OpenSSH and quotes destination and remote command")
    func sshCommand() throws {
        let profile = TuiProfile(
            kind: .ssh,
            command: "cd ~/work && herdr",
            sshDestination: "work-box",
            sshArguments: "-J bastion"
        )
        #expect(
            try LaunchCommandBuilder.startupInput(for: profile)
                == "exec env TERM=xterm-256color /usr/bin/ssh -tt -J bastion -- 'work-box' 'exec \"$SHELL\" -lc '\\''cd ~/work && herdr'\\'''\n"
        )
    }

    @Test("Single quotes are escaped for the local login shell")
    func quotes() {
        #expect(LaunchCommandBuilder.shellQuote("can' t") == "'can'\\'' t'")
    }

    @Test("Missing launch fields fail visibly")
    func missingFields() {
        #expect(throws: LaunchCommandError.missingCommand) {
            try LaunchCommandBuilder.startupInput(for: TuiProfile(command: ""))
        }
        #expect(throws: LaunchCommandError.missingSSHDestination) {
            try LaunchCommandBuilder.startupInput(for: TuiProfile(kind: .ssh, command: "herdr"))
        }
    }
}
