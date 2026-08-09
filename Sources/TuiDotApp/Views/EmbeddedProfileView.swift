import AppKit
import SwiftUI

struct EmbeddedProfileView: View {
    @EnvironmentObject private var store: ProfileStore
    let profileID: UUID

    var body: some View {
        if let profile = store.profile(withID: profileID) {
            EmbeddedTerminalView(profile: profile)
                .frame(minWidth: 480, minHeight: 320)
        } else {
            ContentUnavailableView(
                "Profile unavailable",
                systemImage: "terminal",
                description: Text("Open TuiDotApp and recreate or re-export this profile app.")
            )
            .frame(minWidth: 520, minHeight: 320)
        }
    }
}

private struct EmbeddedTerminalView: NSViewControllerRepresentable {
    let profile: TuiProfile

    func makeNSViewController(context _: Context) -> NSViewController {
        do {
            let startupInput = try LaunchCommandBuilder.startupInput(for: profile)
            let input = try LaunchInputStore.create(contents: startupInput)
            return TerminalHostViewController(profile: profile, launchInput: input)
        } catch {
            return NSHostingController(rootView: ContentUnavailableView(
                "Could not launch \(profile.name)",
                systemImage: "exclamationmark.triangle",
                description: Text(error.localizedDescription)
            ))
        }
    }

    func updateNSViewController(_: NSViewController, context _: Context) {}
}
