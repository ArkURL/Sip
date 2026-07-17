//
//  NotificationService.swift
//  Sip
//

import Foundation
import AppKit
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

    /// Schedules a one-shot local notification.
    /// - Returns: `true` when the request was accepted by the system.
    @discardableResult
    static func scheduleReminder(at date: Date, kind: ReminderKind) async -> Bool {
        let identifier: String
        let content = UNMutableNotificationContent()
        content.sound = .default

        switch kind {
        case .dayStart(let goalML):
            identifier = dayStartIdentifier
            content.title = String(localized: "Don't forget water today 💧")
            content.body = String(localized: "Goal \(goalML) ml — sip when you can.")
        case .interval(let remainingML):
            identifier = reminderIdentifier
            content.title = String(localized: "Time for water 💧")
            if remainingML > 0 {
                content.body = String(localized: "\(remainingML) ml left — grab a cup.")
            } else {
                content.body = String(localized: "Stand up and have a sip.")
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

        return await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().add(request) { error in
                if let error {
                    #if DEBUG
                    print("Sip: failed to schedule notification \(identifier): \(error.localizedDescription)")
                    #endif
                    continuation.resume(returning: false)
                } else {
                    continuation.resume(returning: true)
                }
            }
        }
    }

    /// Opens System Settings → Notifications (best-effort across macOS versions).
    @MainActor
    static func openSystemNotificationSettings() {
        let candidates = [
            "x-apple.systempreferences:com.apple.Notifications-Settings.extension",
            "x-apple.systempreferences:com.apple.preference.notifications",
            "x-apple.systempreferences:com.apple.preference.notifications?id=\(Bundle.main.bundleIdentifier ?? "com.liao.Sip")"
        ]
        for raw in candidates {
            if let url = URL(string: raw), NSWorkspace.shared.open(url) {
                return
            }
        }
    }
}
