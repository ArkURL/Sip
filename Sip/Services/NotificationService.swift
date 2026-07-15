//
//  NotificationService.swift
//  Sip
//

import Foundation
import UserNotifications

enum NotificationService {
    static let reminderIdentifier = "sip.water.reminder"

    static func requestAuthorization() async -> Bool {
        do {
            return try await UNUserNotificationCenter.current()
                .requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    static func authorizationStatus() async -> UNAuthorizationStatus {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        return settings.authorizationStatus
    }

    static func cancelReminder() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [reminderIdentifier])
    }

    static func scheduleReminder(at date: Date, remainingML: Int) {
        cancelReminder()

        let content = UNMutableNotificationContent()
        content.title = "该喝水啦 💧"
        if remainingML > 0 {
            content.body = "今日还有 \(remainingML) ml 就达标了，起来喝一口吧。"
        } else {
            content.body = "记得补充水分，保持好状态。"
        }
        content.sound = .default

        let interval = max(date.timeIntervalSinceNow, 1)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(
            identifier: reminderIdentifier,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }
}
