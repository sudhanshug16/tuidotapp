import AppKit
import Foundation

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
enum UpdateChecker {
    private struct GitHubRelease: Decodable, Sendable {
        let tagName: String
        let htmlURL: URL

        enum CodingKeys: String, CodingKey {
            case tagName = "tag_name"
            case htmlURL = "html_url"
        }
    }

    static func checkForUpdates() {
        Task {
            do {
                var request = URLRequest(
                    url: URL(string: "https://api.github.com/repos/sudhanshug16/tuidotapp/releases/latest")!
                )
                request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
                request.setValue("TuiDotApp", forHTTPHeaderField: "User-Agent")
                let (data, response) = try await URLSession.shared.data(for: request)
                guard let http = response as? HTTPURLResponse,
                      (200..<300).contains(http.statusCode)
                else {
                    throw URLError(.badServerResponse)
                }
                let release = try JSONDecoder().decode(GitHubRelease.self, from: data)
                showResult(release)
            } catch {
                showAlert(
                    title: "Could not check for updates",
                    message: "TuiDotApp could not reach GitHub. \(error.localizedDescription)"
                )
            }
        }
    }

    private static func showResult(_ release: GitHubRelease) {
        let currentString = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "development"
        let current = AppVersion(currentString)
        let latest = AppVersion(release.tagName)
        let updateAvailable = current.map { current in
            latest.map { $0 > current } ?? false
        } ?? true

        let alert = NSAlert()
        alert.messageText = updateAvailable ? "A TuiDotApp update is available" : "TuiDotApp is up to date"
        alert.informativeText = updateAvailable
            ? "Version \(release.tagName) is available. You are running \(currentString)."
            : "You are running the latest release (\(currentString))."
        if updateAvailable {
            alert.addButton(withTitle: "View Download")
            alert.addButton(withTitle: "Later")
            if alert.runModal() == .alertFirstButtonReturn {
                NSWorkspace.shared.open(release.htmlURL)
            }
        } else {
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    private static func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}
