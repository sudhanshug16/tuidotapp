import Foundation
import Sparkle

struct AppVersion: Comparable, Equatable, Sendable {
    let components: [Int]

    init?(_ value: String) {
        let normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingPrefix("v")
        let core = normalized.split(separator: "-", maxSplits: 1).first ?? ""
        let parsed = core.split(separator: ".").map { Int($0) }
        guard !parsed.isEmpty, parsed.allSatisfy({ $0 != nil }) else { return nil }
        components = parsed.compactMap { $0 }
    }

    static func < (lhs: AppVersion, rhs: AppVersion) -> Bool {
        let count = max(lhs.components.count, rhs.components.count)
        for index in 0..<count {
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0
            if left != right { return left < right }
        }
        return false
    }

    static func == (lhs: AppVersion, rhs: AppVersion) -> Bool {
        !(lhs < rhs) && !(rhs < lhs)
    }
}

@MainActor
final class UpdateChecker {
    private(set) var controller: SPUStandardUpdaterController?

    init(bundle: Bundle = .main) {
        guard !EmbeddedProfile.isStandaloneProfileApp,
              bundle.object(forInfoDictionaryKey: "SUFeedURL") != nil
        else {
            return
        }
        controller = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
    }

    func checkForUpdates() {
        controller?.checkForUpdates(nil)
    }

    var canCheckForUpdates: Bool {
        controller?.updater.canCheckForUpdates ?? false
    }
}
