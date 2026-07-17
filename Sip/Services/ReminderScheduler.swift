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

    init(store: IntakeStore, defaults: UserDefaults = .standard) {
        self.store = store
        self.defaults = defaults
    }

    /// One-line summary for the main window.
    var nextReminderSummary: String {
        switch status {
        case .disabled:
            return "提醒已关闭"
        case .goalReached:
            return "今日已达标，提醒已暂停"
        case .scheduled(let date):
            if date.timeIntervalSinceNow <= 5 {
                return "即将提醒"
            }
            return "下次提醒 \(Self.formatNext(date))"
        }
    }

    func reschedule() {
        guard let store else {
            status = .disabled
            return
        }

        NotificationService.cancelAllReminders()

        let settings = store.settings
        guard settings.reminderEnabled else {
            status = .disabled
            return
        }
        guard !store.isGoalReached else {
            status = .goalReached
            return
        }

        let now = Date()
        let allowed = settings.reminderWeekdaySet
        let startHour = settings.activeStartHour
        let endHour = settings.activeEndHour

        var earliest: Date?

        // If we already entered today's active window and never sent the day-start
        // ping (e.g. Mac slept through 09:00), catch up once then schedule intervals.
        if shouldCatchUpDayStart(now: now, settings: settings, store: store) {
            let catchUp = now.addingTimeInterval(1)
            NotificationService.scheduleReminder(
                at: catchUp,
                kind: .dayStart(goalML: settings.dailyGoalML)
            )
            markDayStartNotified(for: now)
            earliest = catchUp
        }

        let next = nextFireDate(
            from: now,
            intervalMinutes: settings.reminderIntervalMinutes,
            startHour: startHour,
            endHour: endHour,
            allowedWeekdays: allowed
        )

        if isActiveWindowStart(next, startHour: startHour) {
            // First opportunity of a future (or upcoming) active day.
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

        if let earliest {
            status = .scheduled(min(earliest, next))
        } else {
            status = .scheduled(next)
        }
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

    // MARK: - Formatting

    static func formatNext(_ date: Date, now: Date = Date(), calendar: Calendar = .current) -> String {
        let time = DateFormatter()
        time.locale = Locale(identifier: "zh_CN")
        time.dateFormat = "HH:mm"

        if calendar.isDateInToday(date) {
            return time.string(from: date)
        }
        if calendar.isDateInTomorrow(date) {
            return "明天 \(time.string(from: date))"
        }
        let dayAndTime = DateFormatter()
        dayAndTime.locale = Locale(identifier: "zh_CN")
        dayAndTime.dateFormat = "M月d日 HH:mm"
        return dayAndTime.string(from: date)
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
