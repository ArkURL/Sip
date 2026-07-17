//
//  NotificationService.swift
//  Sip
//

import Foundation
import AppKit
import Combine
import UserNotifications

/// Long-lived mirror of `UNUserNotificationCenter` auth so Settings UI does not
/// get stuck on the `@State` default (`.notDetermined`) when the view tree is rebuilt.
@MainActor
final class NotificationPermissionModel: ObservableObject {
    @Published private(set) var status: UNAuthorizationStatus = .notDetermined

    var isAllowed: Bool {
        switch status {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied, .notDetermined:
            return false
        @unknown default:
            return false
        }
    }

    var statusLabel: String {
        switch status {
        case .authorized, .provisional, .ephemeral:
            return String(localized: "Allowed")
        case .denied:
            return String(localized: "Denied")
        case .notDetermined:
            return String(localized: "Not set")
        @unknown default:
            return String(localized: "Unknown")
        }
    }

    func refresh() async {
        let latest = await NotificationService.authorizationStatus()
        #if DEBUG
        if latest != status {
            print("Sip: notification auth \(status.rawValue) → \(latest.rawValue)")
        }
        #endif
        // Always assign so first refresh after launch publishes even when still notDetermined
        // is rare; more importantly, authorized/denied always replace the default.
        status = latest
    }
}

enum NotificationService {
    static let reminderIdentifier = "sip.water.reminder"
    static let dayStartIdentifier = "sip.water.dayStart"

    enum ReminderKind {
        /// First ping of an active day (window open).
        case dayStart(goalML: Int)
        /// Interval reminder while already in the active window.
        case interval(remainingML: Int)
    }

    /// Prompts for notification permission when still `.notDetermined`.
    ///
    /// Menu-bar-first apps often sit in `.accessory` activation policy; without bringing the
    /// app to the foreground first, macOS may silently skip the permission alert — the button
    /// appears to do nothing. Always activate before requesting.
    @MainActor
    @discardableResult
    static func requestAuthorization() async -> Bool {
        prepareForSystemPermissionUI()

        let center = UNUserNotificationCenter.current()
        let current = await authorizationStatus()
        switch current {
        case .authorized, .provisional, .ephemeral:
            return true
        case .denied:
            return false
        case .notDetermined:
            break
        @unknown default:
            break
        }

        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            #if DEBUG
            print("Sip: requestAuthorization failed: \(error.localizedDescription)")
            #endif
            return false
        }
    }

    /// Uses the completion-handler API (more reliable on macOS than the async property
    /// in some menu-bar / accessory activation states).
    static func authorizationStatus() async -> UNAuthorizationStatus {
        let settings = await notificationSettings()
        return settings.authorizationStatus
    }

    static func notificationSettings() async -> UNNotificationSettings {
        await withCheckedContinuation { continuation in
            UNUserNotificationCenter.current().getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }
    }

    /// Ensures Dock presence + key app status so system sheets/alerts can appear.
    @MainActor
    private static func prepareForSystemPermissionUI() {
        DockPolicy.showInDock()
        NSApp.activate(ignoringOtherApps: true)
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
        prepareForSystemPermissionUI()

        let bundleID = Bundle.main.bundleIdentifier ?? "com.liao.Sip"
        let candidates = [
            // Ventura+ Notifications pane
            "x-apple.systempreferences:com.apple.Notifications-Settings.extension",
            "x-apple.systempreferences:com.apple.Notifications-Settings.extension?id=\(bundleID)",
            // Older preference-pane deep links
            "x-apple.systempreferences:com.apple.preference.notifications",
            "x-apple.systempreferences:com.apple.preference.notifications?id=\(bundleID)",
            "x-apple.systempreferences:com.apple.settings.Notifications",
        ]
        for raw in candidates {
            if let url = URL(string: raw), NSWorkspace.shared.open(url) {
                return
            }
        }

        // Last resort: open System Settings / System Preferences app.
        let appIDs = ["com.apple.SystemSettings", "com.apple.systempreferences"]
        for appID in appIDs {
            if let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: appID) {
                NSWorkspace.shared.openApplication(at: url, configuration: NSWorkspace.OpenConfiguration())
                return
            }
        }
    }
}
