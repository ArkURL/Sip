//
//  ReminderScheduler.swift
//  Sip
//

import Foundation
import Combine

@MainActor
final class ReminderScheduler: ObservableObject {
    enum Status: Equatable {
        case disabled
        case goalReached
        case scheduled(Date)
    }

    @Published private(set) var status: Status = .disabled

    private weak var store: IntakeStore?
    private let defaults: UserDefaults
    private let dayStartNotifiedKey = "sip.lastDayStartNotifiedDay"
    /// Persists the committed next fire so soft refreshes (open window / become active)
    /// do not push the reminder later.
    private let nextFireKey = "sip.nextScheduledFire"

    init(store: IntakeStore, defaults: UserDefaults = .standard) {
        self.store = store
        self.defaults = defaults
    }

    /// One-line summary for the main window.
    var nextReminderSummary: String {
        switch status {
        case .disabled:
            return String(localized: "Reminders off")
        case .goalReached:
            return String(localized: "Goal reached — no more reminders today")
        case .scheduled(let date):
            if date.timeIntervalSinceNow <= 5 {
                return String(localized: "Reminding soon")
            }
            return String(localized: "Next \(Self.formatNext(date))")
        }
    }

    /// - Parameter force: When `true` (intake / settings / day roll), recompute from `now`.
    ///   When `false` (open window, become active, lifecycle tick), keep an already-committed
    ///   future fire date so merely looking at the UI does not delay the next reminder.
    /// - Parameter now: Injected for tests; defaults to the current time.
    func reschedule(force: Bool = false, now: Date = Date()) {
        guard let store else {
            status = .disabled
            clearPersistedNextFire()
            return
        }

        let settings = store.settings
        guard settings.reminderEnabled else {
            NotificationService.cancelAllReminders()
            status = .disabled
            clearPersistedNextFire()
            return
        }
        guard !store.isGoalReached else {
            NotificationService.cancelAllReminders()
            status = .goalReached
            clearPersistedNextFire()
            return
        }

        // Soft refresh: keep the previously committed fire time if it is still valid.
        if !force,
           let preserved = preservedFireDate(now: now),
           isValidFireDate(preserved, settings: settings) {
            commitSchedule(next: preserved, now: now, store: store, settings: settings)
            return
        }

        let next = nextFireDate(
            from: now,
            intervalMinutes: settings.reminderIntervalMinutes,
            startHour: settings.activeStartHour,
            endHour: settings.activeEndHour,
            allowedWeekdays: settings.reminderWeekdaySet
        )
        commitSchedule(next: next, now: now, store: store, settings: settings)
    }

    /// Public for unit testing.
    func nextFireDate(
        from now: Date,
        intervalMinutes: Int,
        startHour: Int,
        endHour: Int,
        allowedWeekdays: Set<Int> = Set(1...7)
    ) -> Date {
        let interval = TimeInterval(max(intervalMinutes, 1) * 60)
        let allowed = allowedWeekdays.isEmpty ? Set(1...7) : allowedWeekdays

        let inWindow = now.isAllowedWeekday(allowed)
            && now.isInActiveHours(startHour: startHour, endHour: endHour)

        if inWindow {
            let candidate = now.addingTimeInterval(interval)
            if candidate.isAllowedWeekday(allowed),
               candidate.isInActiveHours(startHour: startHour, endHour: endHour) {
                return candidate
            }
            // Interval landed outside today's window or on a disallowed day.
            return candidate.nextReminderOpportunity(
                startHour: startHour,
                endHour: endHour,
                allowedWeekdays: allowed
            )
        }

        return now.nextReminderOpportunity(
            startHour: startHour,
            endHour: endHour,
            allowedWeekdays: allowed
        )
    }

    /// True when `date` is the start of an active window (hour == startHour, minute/second ≈ 0).
    func isActiveWindowStart(_ date: Date, startHour: Int, calendar: Calendar = .current) -> Bool {
        calendar.component(.hour, from: date) == startHour
            && calendar.component(.minute, from: date) == 0
            && calendar.component(.second, from: date) == 0
    }

    /// Whether a previously committed fire date is still usable under current settings.
    func isValidFireDate(_ date: Date, settings: AppSettings) -> Bool {
        let allowed = settings.reminderWeekdaySet.isEmpty
            ? Set(AppSettings.allWeekdays)
            : settings.reminderWeekdaySet
        guard date.isAllowedWeekday(allowed) else { return false }
        if date.isInActiveHours(startHour: settings.activeStartHour, endHour: settings.activeEndHour) {
            return true
        }
        // Day-start pings sit exactly on the window open, which may be the boundary.
        return isActiveWindowStart(date, startHour: settings.activeStartHour)
    }

    // MARK: - Formatting

    static func formatNext(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        let time = DateFormatter()
        time.locale = .autoupdatingCurrent
        time.setLocalizedDateFormatFromTemplate("HHmm")

        if calendar.isDateInToday(date) {
            return time.string(from: date)
        }
        if calendar.isDateInTomorrow(date) {
            return String(localized: "Tomorrow \(time.string(from: date))")
        }
        let dayAndTime = DateFormatter()
        dayAndTime.locale = .autoupdatingCurrent
        dayAndTime.setLocalizedDateFormatFromTemplate("MMMd HHmm")
        return dayAndTime.string(from: date)
    }

    // MARK: - Commit schedule

    /// Cancels pending requests, optionally schedules a one-shot day-start catch-up,
    /// then schedules `next` and updates `status` + persistence.
    private func commitSchedule(
        next: Date,
        now: Date,
        store: IntakeStore,
        settings: AppSettings
    ) {
        NotificationService.cancelAllReminders()

        var earliest: Date?

        // If we already entered today's active window and never sent the day-start
        // ping (e.g. Mac slept through 09:00), catch up once (separate identifier).
        if shouldCatchUpDayStart(now: now, settings: settings, store: store) {
            let catchUp = now.addingTimeInterval(1)
            if catchUp < next {
                NotificationService.scheduleReminder(
                    at: catchUp,
                    kind: .dayStart(goalML: settings.dailyGoalML)
                )
                earliest = catchUp
            }
            markDayStartNotified(for: now)
        }

        if isActiveWindowStart(next, startHour: settings.activeStartHour) {
            NotificationService.scheduleReminder(
                at: next,
                kind: .dayStart(goalML: settings.dailyGoalML)
            )
            markDayStartNotified(for: next)
        } else {
            NotificationService.scheduleReminder(
                at: next,
                kind: .interval(remainingML: store.remainingML)
            )
        }

        // UI shows the soonest pending ping (catch-up may be earlier).
        // Soft-preserve anchors on the primary `next` slot so a day-start catch-up
        // does not erase the interval fire when the catch-up is delivered.
        let display = earliest.map { min($0, next) } ?? next
        status = .scheduled(display)
        persistNextFire(next)
    }

    private func preservedFireDate(now: Date) -> Date? {
        // Prefer the persisted primary fire over in-memory status (status may be a
        // one-shot day-start catch-up that is earlier than the interval).
        let candidate: Date?
        if let ts = defaults.object(forKey: nextFireKey) as? Double {
            candidate = Date(timeIntervalSince1970: ts)
        } else if case .scheduled(let date) = status {
            candidate = date
        } else {
            candidate = nil
        }
        // Must still be meaningfully in the future (past/now → recompute next interval).
        guard let date = candidate, date.timeIntervalSince(now) > 1 else { return nil }
        return date
    }

    private func persistNextFire(_ date: Date) {
        defaults.set(date.timeIntervalSince1970, forKey: nextFireKey)
    }

    private func clearPersistedNextFire() {
        defaults.removeObject(forKey: nextFireKey)
    }

    // MARK: - Day-start catch-up

    private func shouldCatchUpDayStart(now: Date, settings: AppSettings, store: IntakeStore) -> Bool {
        guard settings.allowsReminder(on: now) else { return false }
        guard now.isInActiveHours(
            startHour: settings.activeStartHour,
            endHour: settings.activeEndHour
        ) else { return false }
        guard !store.isGoalReached else { return false }

        let today = now.dayKey
        let last = defaults.string(forKey: dayStartNotifiedKey)
        return last != today
    }

    private func markDayStartNotified(for date: Date) {
        defaults.set(date.dayKey, forKey: dayStartNotifiedKey)
    }
}
