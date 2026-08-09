import Foundation
import Testing
@testable import TuiDotApp

@Suite("Profile deep links")
struct ProfileDeepLinkTests {
    @Test("Launch links round-trip a profile UUID")
    func launchRoundTrip() {
        let id = UUID()
        let link = ProfileDeepLink.launch(id)
        #expect(ProfileDeepLink(url: link.url) == link)
    }

    @Test("Links cannot contain commands or unknown actions")
    func rejectsUnsafeLinks() {
        #expect(ProfileDeepLink(url: URL(string: "tuidotapp://run/rm")!) == nil)
        #expect(ProfileDeepLink(url: URL(string: "https://launch/example")!) == nil)
        #expect(ProfileDeepLink(url: URL(string: "tuidotapp://launch/not-a-uuid")!) == nil)
    }
}
