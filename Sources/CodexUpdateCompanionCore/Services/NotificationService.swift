import Foundation
import UserNotifications

protocol NotificationSending {
    func requestAuthorization() async -> Bool
    func notifyNewReleases(_ releases: [ReleaseItem], enabled: Bool) async
}

final class NotificationService: NSObject, NotificationSending, UNUserNotificationCenterDelegate {
    private let center: UNUserNotificationCenter

    init(center: UNUserNotificationCenter = .current()) {
        self.center = center
        super.init()
        center.delegate = self
    }

    func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    func notifyNewReleases(_ releases: [ReleaseItem], enabled: Bool) async {
        guard enabled, !releases.isEmpty else {
            return
        }

        let granted = await requestAuthorization()
        guard granted else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = "Codex 업데이트 \(releases.count)개 발견"
        content.body = releases.prefix(2).map(\.version).joined(separator: ", ")
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: "codex-update-\(Date().timeIntervalSince1970)",
            content: content,
            trigger: nil
        )

        await withCheckedContinuation { continuation in
            center.add(request) { _ in
                continuation.resume()
            }
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }
}
