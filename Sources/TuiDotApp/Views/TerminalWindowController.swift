import AppKit
import GhosttyTerminal

@MainActor
final class TerminalWindowController: NSWindowController, NSWindowDelegate {
    private let launchInput: LaunchInput
    private let onClose: () -> Void

    init(
        profile: TuiProfile,
        launchInput: LaunchInput,
        onClose: @escaping () -> Void
    ) {
        self.launchInput = launchInput
        self.onClose = onClose

        let content = TerminalHostViewController(
            profile: profile,
            launchInput: launchInput
        )
        let window = NSWindow(contentViewController: content)
        window.title = profile.name
        window.setContentSize(NSSize(width: 1000, height: 680))
        window.minSize = NSSize(width: 480, height: 320)
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
        window.titlebarAppearsTransparent = true

        super.init(window: window)
        window.delegate = self
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    func windowWillClose(_ notification: Notification) {
        LaunchInputStore.remove(launchInput)
        onClose()
    }
}

@MainActor
final class TerminalHostViewController: NSViewController {
    private let profile: TuiProfile
    private let launchInput: LaunchInput
    private let terminalView = TerminalView(frame: .zero)
    private let controller: TerminalController
    private var didConsumeLaunchInput = false

    init(profile: TuiProfile, launchInput: LaunchInput) {
        self.profile = profile
        self.launchInput = launchInput
        controller = TerminalController(
            configSource: GhosttyConfiguration.source(
                for: profile,
                shell: ShellResolver.loginShell(),
                input: launchInput
            ),
            theme: GhosttyConfiguration.theme(for: profile)
        )
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func loadView() {
        view = NSView()
        view.wantsLayer = true
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        terminalView.delegate = self
        terminalView.controller = controller
        terminalView.configuration = TerminalSurfaceOptions(
            backend: .exec,
            workingDirectory: expandedWorkingDirectory(profile.workingDirectory)
        )
        terminalView.translatesAutoresizingMaskIntoConstraints = false
        terminalView.setAccessibilityElement(true)
        terminalView.setAccessibilityLabel("\(profile.name) terminal")
        view.addSubview(terminalView)
        NSLayoutConstraint.activate([
            terminalView.topAnchor.constraint(equalTo: view.topAnchor),
            terminalView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            terminalView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            terminalView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    override func viewDidAppear() {
        super.viewDidAppear()
        view.window?.makeFirstResponder(terminalView)
    }

    override func viewDidLayout() {
        super.viewDidLayout()
        terminalView.fitToSize()
    }

    private func expandedWorkingDirectory(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return NSString(string: trimmed).expandingTildeInPath
    }
}

extension TerminalHostViewController:
    TerminalSurfaceCloseDelegate,
    TerminalSurfaceResizeDelegate
{
    func terminalDidResize(columns _: Int, rows _: Int) {
        guard !didConsumeLaunchInput else { return }
        didConsumeLaunchInput = true
        LaunchInputStore.remove(launchInput)
    }

    func terminalDidClose(processAlive _: Bool) {
        view.window?.close()
    }
}
