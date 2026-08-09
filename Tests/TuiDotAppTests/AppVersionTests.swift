import Testing
@testable import TuiDotApp

@Suite("App version comparison")
struct AppVersionTests {
    @Test("Release tags compare numerically")
    func numericComparison() throws {
        let old = try #require(AppVersion("v0.1.5"))
        let current = try #require(AppVersion("0.1.6"))
        let newer = try #require(AppVersion("0.1.7"))

        #expect(old < current)
        #expect(current < newer)
        #expect(AppVersion("0.1.6") == current)
    }

    @Test("Invalid versions are rejected")
    func invalidVersion() {
        #expect(AppVersion("development") == nil)
        #expect(AppVersion("") == nil)
    }
}
