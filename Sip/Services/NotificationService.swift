//
//  NotificationService.swift
//  Sip
//

import Foundation
import UserNotifications

enum NotificationService {
    static let reminderIdentifier = "sip.water.reminder"
    static let dayStartIdentifier = "sip.water.dayStart"

    enum ReminderKind {
        /// First ping of an active day (window open).
        case dayStart(goalML: Int)
        /// Interval reminder while already in the active window.
        case interval(remainingML: Int)
    }

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

    static func cancelAllReminders() {
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [reminderIdentifier, dayStartIdentifier])
    }

    static func cancelReminder() {
        cancelAllReminders()
    }

    static func scheduleReminder(at date: Date, kind: ReminderKind) {
        let identifier: String
        let content = UNMutableNotificationContent()
        content.sound = .default

        switch kind {
        case .dayStart(let goalML):
            identifier = dayStartIdentifier
            content.title = "今天也记得喝水 💧"
            content.body = "目标 \(goalML) ml，有空就喝两口。"
        case .interval(let remainingML):
            identifier = reminderIdentifier
            content.title = "该喝水了 💧"
            if remainingML > 0 {
                content.body = "还差 \(remainingML) ml，去接杯水吧。"
            } else {
                content.body = "站起来喝一口水，活动一下。"
            }
        }

        // Replace only this kind so day-start + interval can both be pending.
        UNUserNotificationCenter.current()
            .removePendingNotificationRequests(withIdentifiers: [identifier])

        let interval = max(date.timeIntervalSinceNow, 1)
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: trigger
        )

        UNUserNotificationCenter.current().add(request)
    }
}
