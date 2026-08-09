import Testing
@testable import TuiDotApp

@Suite("Profile validation")
struct ProfileValidationTests {
    @Test("Launch requires a command")
    func commandRequired() {
        let profile = TuiProfile(name: "Example", command: "  ")
        #expect(profile.launchValidationMessage != nil)
        #expect(profile.exportValidationMessage != nil)
    }

    @Test("SSH launch also requires a destination")
    func sshDestinationRequired() {
        let profile = TuiProfile(kind: .ssh, command: "herdr", sshDestination: "")
        #expect(profile.launchValidationMessage == "Enter an SSH host or ~/.ssh/config alias.")
    }

    @Test("Export requires an app name")
    func appNameRequired() {
        let profile = TuiProfile(name: "", command: "herdr")
        #expect(profile.launchValidationMessage == nil)
        #expect(profile.exportValidationMessage == "Enter an app name before creating it.")
    }
}
