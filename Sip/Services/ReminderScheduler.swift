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
            endHour: settings.activeEndHour
        )

        NotificationService.scheduleReminder(at: next, remainingML: store.remainingML)
    }

    /// Public for unit testing.
    func nextFireDate(
        from now: Date,
        intervalMinutes: Int,
        startHour: Int,
        endHour: Int
    ) -> Date {
        let interval = TimeInterval(max(intervalMinutes, 1) * 60)

        if now.isInActiveHours(startHour: startHour, endHour: endHour) {
            var candidate = now.addingTimeInterval(interval)
            // If next interval falls outside today's active window, push to next active start.
            if !candidate.isInActiveHours(startHour: startHour, endHour: endHour) {
                candidate = candidate.nextActiveStart(startHour: startHour, endHour: endHour)
            }
            return candidate
        }

        // Outside active hours → fire when the next active window opens.
        return now.nextActiveStart(startHour: startHour, endHour: endHour)
    }
}
