//
//  ReminderScheduler.swift
//  Sip
//

import Foundation

@MainActor
final class ReminderScheduler {
    private weak var store: IntakeStore?

    init(store: IntakeStore) {
        self.store = store
    }

    func reschedule() {
        guard let store else { return }

        NotificationService.cancelReminder()

        let settings = store.settings
        guard settings.reminderEnabled else { return }
        guard !store.isGoalReached else { return }

        let now = Date()
        let next = nextFireDate(
            from: now,
            intervalMinutes: settings.reminderIntervalMinutes,
            startHour: settings.activeStartHour,
            endHour: settings.activeEndHour,
            allowedWeekdays: settings.reminderWeekdaySet
        )

        NotificationService.scheduleReminder(at: next, remainingML: store.remainingML)
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
}
