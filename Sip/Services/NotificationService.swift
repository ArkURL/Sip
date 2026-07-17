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
            content.title = "今日喝水提醒开始 💧"
            content.body = "新的一天目标 \(goalML) ml，从现在开始保持补水节奏吧。"
        case .interval(let remainingML):
            identifier = reminderIdentifier
            content.title = "该喝水啦 💧"
            if remainingML > 0 {
                content.body = "今日还有 \(remainingML) ml 就达标了，起来喝一口吧。"
            } else {
                content.body = "记得补充水分，保持好状态。"
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
