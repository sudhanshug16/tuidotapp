import AppKit
import OSLog
import UserNotifications

struct DesktopNotificationPayload: Equatable, Sendable {
    let title: String
    let body: String

    init(title: String, body: String, fallbackTitle: String) {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedBody = body.trimmingCharacters(in: .whitespacesAndNewlines)
        self.title = trimmedTitle.isEmpty ? fallbackTitle : trimmedTitle
        self.body = trimmedBody
    }
}

final class DesktopNotificationService: NSObject, @unchecked Sendable {
    static let shared = DesktopNotificationService()

    private let center = UNUserNotificationCenter.current()
    private let logger = Logger(
        subsystem: Bundle.main.bundleIdentifier ?? "app.tui.desktop",
        category: "desktop-notifications"
    )

    func configure() {
        center.delegate = self
        center.requestAuthorization(options: [.alert, .sound]) { [logger] granted, error in
            if let error {
                logger.error("Notification authorization failed: \(error.localizedDescription, privacy: .public)")
            } else if !granted {
                logger.notice("Notification authorization was denied")
            }
        }
    }

    func deliver(title: String, body: String, fallbackTitle: String) {
        let payload = DesktopNotificationPayload(
            title: title,
            body: body,
            fallbackTitle: fallbackTitle
        )
        let content = UNMutableNotificationContent()
        content.title = payload.title
        content.body = payload.body
        content.sound = .default

        center.add(UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )) { [logger] error in
            if let error {
                logger.error("Notification delivery failed: \(error.localizedDescription, privacy: .public)")
            }
        }
    }
}

extension DesktopNotificationService: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _: UNUserNotificationCenter,
        willPresent _: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    func userNotificationCenter(
        _: UNUserNotificationCenter,
        didReceive _: UNNotificationResponse
    ) async {
        await MainActor.run {
            NSApp.activate(ignoringOtherApps: true)
            NSApp.keyWindow?.makeKeyAndOrderFront(nil)
        }
    }
}
