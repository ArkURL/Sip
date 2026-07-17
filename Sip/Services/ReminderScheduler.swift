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

    /// Ensures the interval chain continues in menu-bar / accessory mode where
    /// `willPresent` often does not run after a banner is delivered.
    private var chainTimer: Timer?
    /// Drops stale async schedule completions when a newer `reschedule` started.
    private var scheduleGeneration = 0

    init(store: IntakeStore, defaults: UserDefaults = .standard) {
        self.store = store
        self.defaults = defaults
    }

    deinit {
        chainTimer?.invalidate()
    }

    /// One-line summary for the main window.
    var nextReminderSummary: String {
        switch status {
        case .disabled:
            return String(localized: "Reminders off")
        case .goalReached:
            return String(localized: "Goal reached — no more reminders today")
        case .scheduled(let date):
            // Past or imminent → do not show a stale clock time.
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
        scheduleGeneration += 1
        let generation = scheduleGeneration
        cancelChainTimer()

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
        let next: Date
        if !force,
           let preserved = preservedFireDate(now: now),
           isValidFireDate(preserved, settings: settings) {
            next = preserved
        } else {
            next = nextFireDate(
                from: now,
                intervalMinutes: settings.reminderIntervalMinutes,
                startHour: settings.activeStartHour,
                startMinute: settings.activeStartMinute,
                endHour: settings.activeEndHour,
                endMinute: settings.activeEndMinute,
                allowedWeekdays: settings.reminderWeekdaySet
            )
        }

        commitSchedule(
            next: next,
            now: now,
            store: store,
            settings: settings,
            generation: generation
        )
    }

    /// Public for unit testing.
    func nextFireDate(
        from now: Date,
        intervalMinutes: Int,
        startHour: Int,
        startMinute: Int = 0,
        endHour: Int,
        endMinute: Int = 0,
        allowedWeekdays: Set<Int> = Set(1...7)
    ) -> Date {
        let interval = TimeInterval(max(intervalMinutes, 1) * 60)
        let allowed = allowedWeekdays.isEmpty ? Set(1...7) : allowedWeekdays

        let inWindow = now.isAllowedWeekday(allowed)
            && now.isInActiveHours(
                startHour: startHour,
                startMinute: startMinute,
                endHour: endHour,
                endMinute: endMinute
            )

        if inWindow {
            let candidate = now.addingTimeInterval(interval)
            if candidate.isAllowedWeekday(allowed),
               candidate.isInActiveHours(
                startHour: startHour,
                startMinute: startMinute,
                endHour: endHour,
                endMinute: endMinute
               ) {
                return candidate
            }
            // Interval landed outside today's window or on a disallowed day.
            return candidate.nextReminderOpportunity(
                startHour: startHour,
                startMinute: startMinute,
                endHour: endHour,
                endMinute: endMinute,
                allowedWeekdays: allowed
            )
        }

        return now.nextReminderOpportunity(
            startHour: startHour,
            startMinute: startMinute,
            endHour: endHour,
            endMinute: endMinute,
            allowedWeekdays: allowed
        )
    }

    /// True when `date` is the start of an active window (matches start hour/minute, second ≈ 0).
    func isActiveWindowStart(
        _ date: Date,
        startHour: Int,
        startMinute: Int = 0,
        calendar: Calendar = .current
    ) -> Bool {
        calendar.component(.hour, from: date) == startHour
            && calendar.component(.minute, from: date) == startMinute
            && calendar.component(.second, from: date) == 0
    }

    /// Whether a previously committed fire date is still usable under current settings.
    func isValidFireDate(_ date: Date, settings: AppSettings) -> Bool {
        let allowed = settings.reminderWeekdaySet.isEmpty
            ? Set(AppSettings.allWeekdays)
            : settings.reminderWeekdaySet
        guard date.isAllowedWeekday(allowed) else { return false }
        if date.isInActiveHours(settings: settings) {
            return true
        }
        // Day-start pings sit exactly on the window open, which may be the boundary.
        return isActiveWindowStart(
            date,
            startHour: settings.activeStartHour,
            startMinute: settings.activeStartMinute
        )
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

    /// Updates status immediately, arms the chain timer, then schedules system notifications
    /// asynchronously. Day-start “already notified” is only marked after a successful `add`.
    private func commitSchedule(
        next: Date,
        now: Date,
        store: IntakeStore,
        settings: AppSettings,
        generation: Int
    ) {
        NotificationService.cancelAllReminders()

        var catchUp: Date?
        let needsCatchUp = shouldCatchUpDayStart(now: now, settings: settings, store: store)
        if needsCatchUp {
            let candidate = now.addingTimeInterval(1)
            if candidate < next {
                catchUp = candidate
            }
        }

        let display = catchUp.map { min($0, next) } ?? next
        status = .scheduled(display)
        persistNextFire(next)
        armChainTimer(for: display, generation: generation)

        let isWindowStart = isActiveWindowStart(
            next,
            startHour: settings.activeStartHour,
            startMinute: settings.activeStartMinute
        )
        let remaining = store.remainingML
        let goal = settings.dailyGoalML
        let markCatchUpDay = needsCatchUp && catchUp == nil
        if markCatchUpDay {
            // Next fire is soon enough that a separate catch-up is unnecessary.
            markDayStartNotified(for: now)
        }

        Task { @MainActor in
            if let catchUp {
                let ok = await NotificationService.scheduleReminder(
                    at: catchUp,
                    kind: .dayStart(goalML: goal)
                )
                guard generation == self.scheduleGeneration else { return }
                if ok {
                    self.markDayStartNotified(for: now)
                }
            }

            guard generation == self.scheduleGeneration else { return }

            let primaryOK: Bool
            if isWindowStart {
                primaryOK = await NotificationService.scheduleReminder(
                    at: next,
                    kind: .dayStart(goalML: goal)
                )
                if primaryOK {
                    self.markDayStartNotified(for: next)
                }
            } else {
                primaryOK = await NotificationService.scheduleReminder(
                    at: next,
                    kind: .interval(remainingML: remaining)
                )
            }

            #if DEBUG
            if !primaryOK {
                print("Sip: primary reminder schedule failed; chain timer will retry")
            }
            #endif
        }
    }

    // MARK: - Chain timer

    private func armChainTimer(for date: Date, generation: Int) {
        cancelChainTimer()
        // Slightly after the fire so the banner can deliver first, then we plan the next.
        let fireAt = date.addingTimeInterval(1.5)
        let delay = fireAt.timeIntervalSinceNow
        let timer: Timer
        if delay <= 0 {
            timer = Timer(timeInterval: 0.05, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    guard let self, generation == self.scheduleGeneration else { return }
                    self.reschedule(force: false)
                }
            }
        } else {
            timer = Timer(fire: fireAt, interval: 0, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    guard let self, generation == self.scheduleGeneration else { return }
                    self.reschedule(force: false)
                }
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        chainTimer = timer
    }

    private func cancelChainTimer() {
        chainTimer?.invalidate()
        chainTimer = nil
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

    /// Exposed for unit tests (day-start catch-up gate).
    func shouldCatchUpDayStartForTesting(now: Date, settings: AppSettings, store: IntakeStore) -> Bool {
        shouldCatchUpDayStart(now: now, settings: settings, store: store)
    }

    private func shouldCatchUpDayStart(now: Date, settings: AppSettings, store: IntakeStore) -> Bool {
        guard settings.allowsReminder(on: now) else { return false }
        guard now.isInActiveHours(settings: settings) else { return false }
        guard !store.isGoalReached else { return false }

        let today = now.dayKey
        let last = defaults.string(forKey: dayStartNotifiedKey)
        return last != today
    }

    private func markDayStartNotified(for date: Date) {
        defaults.set(date.dayKey, forKey: dayStartNotifiedKey)
    }
}
