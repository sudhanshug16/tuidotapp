import AppKit
import GhosttyTerminal

/// Matches the input details used by Ghostty's native macOS surface.
///
/// libghostty-spm tracks mouse movement, but its AppKit view does not update
/// the pointer on mouse-enter. A trackpad scroll can therefore arrive while
/// Ghostty still considers the pointer outside the surface, causing alternate
/// screen fallback (arrow-key history) instead of TUI mouse reporting.
@MainActor
final class TuiTerminalView: TerminalView {
    var mapCommandToControl = false
    var commandToControlExcludedKeys: Set<String> = ["c", "v"]

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        let shortcutModifiers = event.modifierFlags.intersection([
            .command,
            .control,
            .option,
            .shift,
        ])
        if event.type == .keyDown,
           shortcutModifiers == .command,
           event.charactersIgnoringModifiers?.lowercased() == "q"
        {
            NSApp.terminate(nil)
            return true
        }

        if event.type == .keyDown,
           shouldMapCommandToControl(event),
           let translatedEvent = replacingCommandWithControl(in: event)
        {
            super.keyDown(with: translatedEvent)
            return true
        }

        return super.performKeyEquivalent(with: event)
    }

    override func keyDown(with event: NSEvent) {
        guard shouldMapCommandToControl(event),
              let translatedEvent = replacingCommandWithControl(in: event)
        else {
            super.keyDown(with: event)
            return
        }
        super.keyDown(with: translatedEvent)
    }

    override func keyUp(with event: NSEvent) {
        guard shouldMapCommandToControl(event),
              let translatedEvent = replacingCommandWithControl(in: event)
        else {
            super.keyUp(with: event)
            return
        }
        super.keyUp(with: translatedEvent)
    }

    private func replacingCommandWithControl(in event: NSEvent) -> NSEvent? {
        return NSEvent.keyEvent(
            with: event.type,
            location: event.locationInWindow,
            modifierFlags: Self.replacingCommandWithControl(in: event.modifierFlags),
            timestamp: event.timestamp,
            windowNumber: event.windowNumber,
            context: nil,
            characters: event.characters ?? "",
            charactersIgnoringModifiers: event.charactersIgnoringModifiers ?? "",
            isARepeat: event.isARepeat,
            keyCode: event.keyCode
        )
    }

    static func replacingCommandWithControl(
        in modifiers: NSEvent.ModifierFlags
    ) -> NSEvent.ModifierFlags {
        var translated = modifiers
        translated.remove(.command)
        translated.insert(.control)
        return translated
    }

    private func shouldMapCommandToControl(_ event: NSEvent) -> Bool {
        Self.shouldMapCommandToControl(
            mapEnabled: mapCommandToControl,
            modifiers: event.modifierFlags,
            key: event.charactersIgnoringModifiers,
            excludedKeys: commandToControlExcludedKeys
        )
    }

    static func shouldMapCommandToControl(
        mapEnabled: Bool,
        modifiers: NSEvent.ModifierFlags,
        key: String?,
        excludedKeys: Set<String>
    ) -> Bool {
        guard mapEnabled, modifiers.contains(.command) else { return false }
        guard let key else { return true }
        return !excludedKeys.contains(key.lowercased())
    }

    static func excludedCommandKeys(from value: String) -> Set<String> {
        Set(value
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
            .filter { !$0.isEmpty })
    }


    override func mouseEntered(with event: NSEvent) {
        super.mouseEntered(with: event)
        super.mouseMoved(with: event)
    }

    override func scrollWheel(with event: NSEvent) {
        // Keep the pointer current even when the user scrolls without moving it.
        super.mouseMoved(with: event)
        super.scrollWheel(with: event)

        // Stock Ghostty applies a 2x multiplier to precise trackpad deltas.
        // The wrapper does not expose raw scroll injection, so replaying the
        // event once gives the embedded surface the same effective distance.
        if event.hasPreciseScrollingDeltas,
           event.scrollingDeltaX != 0 || event.scrollingDeltaY != 0
        {
            super.scrollWheel(with: event)
        }
    }
}

/// Native macOS scrollbar host for the embedded Ghostty surface.
///
/// Ghostty reports scrollbar geometry but deliberately leaves drawing and
/// thumb interaction to the host application. This mirrors Ghostty's own
/// SurfaceScrollView architecture: a blank document represents all history,
/// while the Metal terminal view remains exactly viewport-sized.
@MainActor
final class TerminalScrollContainerView: NSView {
    private let scrollView = NSScrollView()
    private let documentView = NSView()
    let terminalView: TuiTerminalView

    private var scrollbar: TerminalScrollbar?
    private var cellHeight: CGFloat = 0
    private var isLiveScrolling = false
    private var lastSentRow: UInt?
    nonisolated(unsafe) private var observers: [NSObjectProtocol] = []

    init(terminalView: TuiTerminalView) {
        self.terminalView = terminalView
        super.init(frame: .zero)

        scrollView.hasVerticalScroller = true
        scrollView.hasHorizontalScroller = false
        scrollView.autohidesScrollers = false
        scrollView.usesPredominantAxisScrolling = true
        scrollView.scrollerStyle = .overlay
        scrollView.drawsBackground = false
        scrollView.contentView.clipsToBounds = false
        scrollView.documentView = documentView

        documentView.addSubview(terminalView)
        addSubview(scrollView)

        scrollView.contentView.postsBoundsChangedNotifications = true
        observe(NSView.boundsDidChangeNotification, object: scrollView.contentView) { [weak self] in
            self?.synchronizeTerminalPosition()
        }
        observe(NSScrollView.willStartLiveScrollNotification, object: scrollView) { [weak self] in
            self?.isLiveScrolling = true
        }
        observe(NSScrollView.didLiveScrollNotification, object: scrollView) { [weak self] in
            self?.handleLiveScroll()
        }
        observe(NSScrollView.didEndLiveScrollNotification, object: scrollView) { [weak self] in
            self?.isLiveScrolling = false
            self?.synchronizeScrollView()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    deinit {
        for observer in observers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    override func layout() {
        super.layout()
        scrollView.frame = bounds
        terminalView.frame.size = scrollView.bounds.size
        documentView.frame.size.width = scrollView.bounds.width
        synchronizeScrollView()
        synchronizeTerminalPosition()
    }

    func updateGrid(_ metrics: TerminalGridMetrics) {
        let scale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        cellHeight = CGFloat(metrics.cellHeightPixels) / scale
        synchronizeScrollView()
    }

    func updateScrollbar(_ scrollbar: TerminalScrollbar) {
        self.scrollbar = scrollbar
        synchronizeScrollView()
    }

    private func observe(
        _ name: Notification.Name,
        object: AnyObject,
        handler: @escaping @MainActor () -> Void
    ) {
        observers.append(NotificationCenter.default.addObserver(
            forName: name,
            object: object,
            queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                handler()
            }
        })
    }

    private func synchronizeScrollView() {
        documentView.frame.size.height = documentHeight

        if !isLiveScrolling,
           cellHeight > 0,
           let scrollbar
        {
            let rowsFromBottom = scrollbar.total
                .saturatingSubtracting(scrollbar.offset)
                .saturatingSubtracting(scrollbar.len)
            let y = CGFloat(rowsFromBottom) * cellHeight
            scrollView.contentView.scroll(to: CGPoint(x: 0, y: y))
            lastSentRow = UInt(clamping: scrollbar.offset)
        }

        scrollView.reflectScrolledClipView(scrollView.contentView)
        synchronizeTerminalPosition()
    }

    private var documentHeight: CGFloat {
        let contentHeight = scrollView.contentSize.height
        guard cellHeight > 0, let scrollbar else { return contentHeight }

        let gridHeight = CGFloat(scrollbar.total) * cellHeight
        let padding = max(0, contentHeight - CGFloat(scrollbar.len) * cellHeight)
        return max(contentHeight, gridHeight + padding)
    }

    private func synchronizeTerminalPosition() {
        terminalView.frame.origin = scrollView.contentView.documentVisibleRect.origin
    }

    private func handleLiveScroll() {
        guard cellHeight > 0 else { return }
        let visible = scrollView.contentView.documentVisibleRect
        let offsetFromTop = documentHeight - visible.origin.y - visible.height
        let row = UInt(max(0, offsetFromTop / cellHeight))
        guard row != lastSentRow else { return }
        lastSentRow = row
        terminalView.scrollToRow(row)
    }
}

private extension UInt64 {
    func saturatingSubtracting(_ other: UInt64) -> UInt64 {
        self >= other ? self - other : 0
    }
}
