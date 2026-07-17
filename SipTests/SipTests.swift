//
//  SipTests.swift
//  SipTests
//

import XCTest
@testable import Sip

@MainActor
final class SipTests: XCTestCase {

    func testAddIntakeAccumulates() {
        let store = makeIsolatedStore()
        store.addIntake(amountML: 250)
        store.addIntake(amountML: 500)
        XCTAssertEqual(store.totalML, 750)
        XCTAssertEqual(store.entries.count, 2)
        XCTAssertFalse(store.isGoalReached)
    }

    func testGoalReached() {
        let store = makeIsolatedStore()
        store.settings.dailyGoalML = 500
        store.addIntake(amountML: 500)
        XCTAssertTrue(store.isGoalReached)
        XCTAssertEqual(store.remainingML, 0)
        XCTAssertEqual(store.progressPercent, 100)
    }

    func testUndoLast() {
        let store = makeIsolatedStore()
        store.addIntake(amountML: 100)
        store.addIntake(amountML: 250)
        let removed = store.undoLast()
        XCTAssertEqual(removed?.amountML, 250)
        XCTAssertEqual(store.totalML, 100)
    }

    func testIgnoreNonPositiveAmount() {
        let store = makeIsolatedStore()
        XCTAssertNil(store.addIntake(amountML: 0))
        XCTAssertNil(store.addIntake(amountML: -10))
        XCTAssertEqual(store.entries.count, 0)
    }

    func testSettingsClamp() {
        var settings = AppSettings.default
        settings.dailyGoalML = 50
        settings.clamp()
        XCTAssertEqual(settings.dailyGoalML, 500)

        settings.dailyGoalML = 99999
        settings.clamp()
        XCTAssertEqual(settings.dailyGoalML, 5000)
    }

    func testSettingsClampEmptyWeekdaysBecomesAll() {
        var settings = AppSettings.default
        settings.reminderWeekdays = []
        settings.clamp()
        XCTAssertEqual(settings.reminderWeekdays, AppSettings.allWeekdays)
    }

    func testSettingsDecodeMissingWeekdaysDefaultsToAll() throws {
        // Legacy payload without reminderWeekdays must not fail decode / wipe settings.
        let json = """
        {
          "dailyGoalML": 1800,
          "reminderEnabled": true,
          "reminderIntervalMinutes": 45,
          "activeStartHour": 8,
          "activeEndHour": 20,
          "hasCompletedOnboarding": true
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AppSettings.self, from: json)
        XCTAssertEqual(decoded.dailyGoalML, 1800)
        XCTAssertEqual(decoded.reminderIntervalMinutes, 45)
        XCTAssertEqual(decoded.reminderWeekdays, AppSettings.allWeekdays)
        XCTAssertTrue(decoded.hasCompletedOnboarding)
    }

    func testActiveHoursSameDay() {
        // 14:00 is in 9–21 (end minute inclusive)
        let date = calendarDate(hour: 14)
        XCTAssertTrue(date.isInActiveHours(startHour: 9, endHour: 21))

        let morning = calendarDate(hour: 7)
        XCTAssertFalse(morning.isInActiveHours(startHour: 9, endHour: 21))

        let night = calendarDate(hour: 22)
        XCTAssertFalse(night.isInActiveHours(startHour: 9, endHour: 21))

        // End time is inclusive of that minute (21:00 yes, 21:01 no).
        let atEnd = calendarDate(hour: 21, minute: 0)
        XCTAssertTrue(atEnd.isInActiveHours(startHour: 9, endHour: 21, endMinute: 0))
        let afterEnd = calendarDate(hour: 21, minute: 1)
        XCTAssertFalse(afterEnd.isInActiveHours(startHour: 9, endHour: 21, endMinute: 0))
    }

    func testActiveHoursWithMinutes() {
        // Window 09:30–17:15
        let before = calendarDate(hour: 9, minute: 29)
        XCTAssertFalse(before.isInActiveHours(
            startHour: 9, startMinute: 30, endHour: 17, endMinute: 15
        ))
        let start = calendarDate(hour: 9, minute: 30)
        XCTAssertTrue(start.isInActiveHours(
            startHour: 9, startMinute: 30, endHour: 17, endMinute: 15
        ))
        let atEnd = calendarDate(hour: 17, minute: 15)
        XCTAssertTrue(atEnd.isInActiveHours(
            startHour: 9, startMinute: 30, endHour: 17, endMinute: 15
        ))
        let after = calendarDate(hour: 17, minute: 16)
        XCTAssertFalse(after.isInActiveHours(
            startHour: 9, startMinute: 30, endHour: 17, endMinute: 15
        ))
    }

    func testNextFireDateWithinActiveWindow() {
        let store = makeIsolatedStore()
        let scheduler = ReminderScheduler(store: store)
        let now = calendarDate(hour: 10, minute: 0)
        let next = scheduler.nextFireDate(
            from: now,
            intervalMinutes: 60,
            startHour: 9,
            endHour: 21
        )
        let expected = now.addingTimeInterval(60 * 60)
        XCTAssertEqual(next.timeIntervalSince1970, expected.timeIntervalSince1970, accuracy: 1)
    }

    func testNextFireDateOutsideActiveWindow() {
        let store = makeIsolatedStore()
        let scheduler = ReminderScheduler(store: store)
        let now = calendarDate(hour: 22, minute: 0)
        let next = scheduler.nextFireDate(
            from: now,
            intervalMinutes: 60,
            startHour: 9,
            endHour: 21
        )
        // Should land at next active window open (09:00)
        let hour = Calendar.current.component(.hour, from: next)
        XCTAssertEqual(hour, 9)
        XCTAssertTrue(next > now)
    }

    func testNextFireDateSkipsDisallowedWeekdays() {
        let store = makeIsolatedStore()
        let scheduler = ReminderScheduler(store: store)
        // 2026-07-18 is a Saturday (Calendar weekday = 7).
        let saturday = makeDate(year: 2026, month: 7, day: 18, hour: 10, minute: 0)
        XCTAssertEqual(Calendar.current.component(.weekday, from: saturday), 7)

        let next = scheduler.nextFireDate(
            from: saturday,
            intervalMinutes: 60,
            startHour: 9,
            endHour: 21,
            allowedWeekdays: Set(AppSettings.workweekDays)
        )

        // Next workday is Monday 2026-07-20 at 09:00.
        let cal = Calendar.current
        XCTAssertEqual(cal.component(.weekday, from: next), 2) // Monday
        XCTAssertEqual(cal.component(.hour, from: next), 9)
        XCTAssertEqual(cal.component(.day, from: next), 20)
        XCTAssertTrue(next > saturday)
    }

    func testNextFireDateFridayEveningJumpsToMonday() {
        let store = makeIsolatedStore()
        let scheduler = ReminderScheduler(store: store)
        // 2026-07-17 Friday 20:30 — still before end hour 21, so in window;
        // interval 60m lands at 21:30 outside window → next workday Monday 09:00.
        let friday = makeDate(year: 2026, month: 7, day: 17, hour: 20, minute: 30)
        XCTAssertEqual(Calendar.current.component(.weekday, from: friday), 6)

        let next = scheduler.nextFireDate(
            from: friday,
            intervalMinutes: 60,
            startHour: 9,
            endHour: 21,
            allowedWeekdays: Set(AppSettings.workweekDays)
        )

        let cal = Calendar.current
        XCTAssertEqual(cal.component(.weekday, from: next), 2)
        XCTAssertEqual(cal.component(.hour, from: next), 9)
        XCTAssertEqual(cal.component(.day, from: next), 20)
    }

    func testPersistenceRoundTripIncludesWeekdays() {
        let suiteName = "SipTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store1 = IntakeStore(defaults: defaults)
        store1.settings.dailyGoalML = 1800
        store1.settings.reminderWeekdays = AppSettings.workweekDays
        store1.addIntake(amountML: 350)

        let store2 = IntakeStore(defaults: defaults)
        XCTAssertEqual(store2.settings.dailyGoalML, 1800)
        XCTAssertEqual(store2.settings.reminderWeekdays, AppSettings.workweekDays)
        XCTAssertEqual(store2.totalML, 350)
        XCTAssertEqual(store2.entries.count, 1)
    }

    func testEnsureCurrentDayNoopSameDay() {
        let store = makeIsolatedStore()
        store.addIntake(amountML: 200)
        XCTAssertFalse(store.ensureCurrentDay())
        XCTAssertEqual(store.totalML, 200)
    }

    func testEnsureCurrentDayRollsWhenLastActiveDayIsYesterday() {
        let suiteName = "SipTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        defaults.set(yesterday.dayKey, forKey: "sip.lastActiveDay")
        let entry = IntakeEntry(amountML: 500, timestamp: yesterday)
        defaults.set(try! JSONEncoder().encode([entry]), forKey: "sip.todayEntries")

        let store = IntakeStore(defaults: defaults)
        // init already calls ensureCurrentDay → should have wiped yesterday.
        XCTAssertEqual(store.totalML, 0)
        XCTAssertEqual(store.entries.count, 0)
        XCTAssertFalse(store.ensureCurrentDay())
    }

    func testIsActiveWindowStartDetection() {
        let store = makeIsolatedStore()
        let scheduler = ReminderScheduler(store: store)
        let atNine = makeDate(year: 2026, month: 7, day: 17, hour: 9, minute: 0)
        XCTAssertTrue(scheduler.isActiveWindowStart(atNine, startHour: 9))

        let atNineOhOne = makeDate(year: 2026, month: 7, day: 17, hour: 9, minute: 1)
        XCTAssertFalse(scheduler.isActiveWindowStart(atNineOhOne, startHour: 9))

        let atTen = makeDate(year: 2026, month: 7, day: 17, hour: 10, minute: 0)
        XCTAssertFalse(scheduler.isActiveWindowStart(atTen, startHour: 9))
    }

    func testNextFireDateOutsideWindowIsWindowStart() {
        let store = makeIsolatedStore()
        let scheduler = ReminderScheduler(store: store)
        let now = calendarDate(hour: 7, minute: 30)
        let next = scheduler.nextFireDate(
            from: now,
            intervalMinutes: 60,
            startHour: 9,
            endHour: 21
        )
        XCTAssertTrue(scheduler.isActiveWindowStart(next, startHour: 9))
        XCTAssertTrue(next > now)
    }

    func testFormatNextReminderTodayAndTomorrow() {
        let today = makeDate(year: 2026, month: 7, day: 17, hour: 14, minute: 30)
        let now = makeDate(year: 2026, month: 7, day: 17, hour: 10, minute: 0)
        let todayText = ReminderScheduler.formatNext(today, now: now)
        // Locale-aware time; must mention the hour somehow.
        XCTAssertFalse(todayText.isEmpty)
        XCTAssertTrue(todayText.contains("14") || todayText.contains("2:30") || todayText.contains("2：30"))

        let tomorrow = makeDate(year: 2026, month: 7, day: 18, hour: 9, minute: 0)
        let tomorrowText = ReminderScheduler.formatNext(tomorrow, now: now)
        XCTAssertTrue(
            tomorrowText.localizedCaseInsensitiveContains("tomorrow")
                || tomorrowText.contains("明天")
        )
        XCTAssertTrue(tomorrowText.contains("9") || tomorrowText.contains("09"))
    }

    func testRescheduleStatusGoalReached() {
        let suiteName = "SipTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = IntakeStore(defaults: defaults)
        store.settings.dailyGoalML = 500
        store.addIntake(amountML: 500)
        let scheduler = ReminderScheduler(store: store, defaults: defaults)
        scheduler.reschedule(force: true)
        XCTAssertEqual(scheduler.status, .goalReached)
        XCTAssertFalse(scheduler.nextReminderSummary.isEmpty)
    }

    func testSoftRescheduleDoesNotPushNextFireLater() {
        // Reopening the main UI must not recompute from "now" and delay the reminder.
        let suiteName = "SipTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = IntakeStore(defaults: defaults)
        store.settings.reminderEnabled = true
        store.settings.reminderIntervalMinutes = 60
        store.settings.activeStartHour = 9
        store.settings.activeEndHour = 21
        store.settings.reminderWeekdays = AppSettings.allWeekdays

        let scheduler = ReminderScheduler(store: store, defaults: defaults)
        let t0 = makeDate(year: 2026, month: 7, day: 17, hour: 10, minute: 0)
        // Avoid day-start catch-up for the simulated calendar day.
        defaults.set(t0.dayKey, forKey: "sip.lastDayStartNotifiedDay")
        scheduler.reschedule(force: true, now: t0)

        guard case .scheduled(let first) = scheduler.status else {
            return XCTFail("expected scheduled after force reschedule")
        }
        let expected = t0.addingTimeInterval(60 * 60)
        XCTAssertEqual(first.timeIntervalSince1970, expected.timeIntervalSince1970, accuracy: 1)

        // 30 minutes later — soft refresh (open window / become active).
        let t1 = makeDate(year: 2026, month: 7, day: 17, hour: 10, minute: 30)
        scheduler.reschedule(force: false, now: t1)

        guard case .scheduled(let soft) = scheduler.status else {
            return XCTFail("expected still scheduled after soft reschedule")
        }
        XCTAssertEqual(soft.timeIntervalSince1970, first.timeIntervalSince1970, accuracy: 1)
        // Must NOT have been pushed to t1 + 60m.
        XCTAssertNotEqual(
            soft.timeIntervalSince1970,
            t1.addingTimeInterval(60 * 60).timeIntervalSince1970,
            accuracy: 1
        )
    }

    func testForceRescheduleRecomputesFromNow() {
        let suiteName = "SipTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = IntakeStore(defaults: defaults)
        store.settings.reminderIntervalMinutes = 60
        store.settings.activeStartHour = 9
        store.settings.activeEndHour = 21

        let scheduler = ReminderScheduler(store: store, defaults: defaults)
        let t0 = makeDate(year: 2026, month: 7, day: 17, hour: 10, minute: 0)
        defaults.set(t0.dayKey, forKey: "sip.lastDayStartNotifiedDay")
        scheduler.reschedule(force: true, now: t0)

        let t1 = makeDate(year: 2026, month: 7, day: 17, hour: 10, minute: 30)
        scheduler.reschedule(force: true, now: t1)

        guard case .scheduled(let forced) = scheduler.status else {
            return XCTFail("expected scheduled after force reschedule")
        }
        let expected = t1.addingTimeInterval(60 * 60)
        XCTAssertEqual(forced.timeIntervalSince1970, expected.timeIntervalSince1970, accuracy: 1)
    }

    func testSoftRescheduleAfterFireRecomputesNextInterval() {
        let suiteName = "SipTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = IntakeStore(defaults: defaults)
        store.settings.reminderIntervalMinutes = 60
        store.settings.activeStartHour = 9
        store.settings.activeEndHour = 21
        defaults.set(makeDate(year: 2026, month: 7, day: 17, hour: 10, minute: 0).dayKey,
                     forKey: "sip.lastDayStartNotifiedDay")

        let scheduler = ReminderScheduler(store: store, defaults: defaults)
        let t0 = makeDate(year: 2026, month: 7, day: 17, hour: 10, minute: 0)
        scheduler.reschedule(force: true, now: t0)

        // Fire time has passed → soft refresh should schedule a new interval from now.
        let afterFire = makeDate(year: 2026, month: 7, day: 17, hour: 11, minute: 0, second: 5)
        scheduler.reschedule(force: false, now: afterFire)

        guard case .scheduled(let next) = scheduler.status else {
            return XCTFail("expected rescheduled after fire")
        }
        let expected = afterFire.addingTimeInterval(60 * 60)
        XCTAssertEqual(next.timeIntervalSince1970, expected.timeIntervalSince1970, accuracy: 1)
    }

    func testIsValidFireDateRejectsDisallowedWeekday() {
        let store = makeIsolatedStore()
        let scheduler = ReminderScheduler(store: store)
        var settings = AppSettings.default
        settings.reminderWeekdays = AppSettings.workweekDays
        settings.activeStartHour = 9
        settings.activeEndHour = 21

        let saturday = makeDate(year: 2026, month: 7, day: 18, hour: 10, minute: 0)
        XCTAssertFalse(scheduler.isValidFireDate(saturday, settings: settings))

        let monday = makeDate(year: 2026, month: 7, day: 20, hour: 10, minute: 0)
        XCTAssertTrue(scheduler.isValidFireDate(monday, settings: settings))
    }

    func testSettingsDecodeMissingMinutesDefaultsToZero() throws {
        let json = """
        {
          "dailyGoalML": 1800,
          "reminderEnabled": true,
          "reminderIntervalMinutes": 45,
          "activeStartHour": 8,
          "activeEndHour": 20,
          "hasCompletedOnboarding": true
        }
        """.data(using: .utf8)!
        let decoded = try JSONDecoder().decode(AppSettings.self, from: json)
        XCTAssertEqual(decoded.activeStartMinute, 0)
        XCTAssertEqual(decoded.activeEndMinute, 0)
        XCTAssertEqual(decoded.activeStartHour, 8)
        XCTAssertEqual(decoded.activeEndHour, 20)
    }

    func testShouldCatchUpDayStartOncePerDay() {
        let suiteName = "SipTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = IntakeStore(defaults: defaults)
        var settings = store.settings
        settings.reminderEnabled = true
        settings.reminderWeekdays = AppSettings.allWeekdays
        settings.activeStartHour = 9
        settings.activeEndHour = 21
        store.settings = settings

        let scheduler = ReminderScheduler(store: store, defaults: defaults)
        let now = makeDate(year: 2026, month: 7, day: 17, hour: 10, minute: 0)

        XCTAssertTrue(scheduler.shouldCatchUpDayStartForTesting(now: now, settings: store.settings, store: store))

        // After a force reschedule that marks day-start (async may mark later; set key for gate).
        defaults.set(now.dayKey, forKey: "sip.lastDayStartNotifiedDay")
        XCTAssertFalse(scheduler.shouldCatchUpDayStartForTesting(now: now, settings: store.settings, store: store))
    }

    func testNextFireDateHonorsStartMinute() {
        let store = makeIsolatedStore()
        let scheduler = ReminderScheduler(store: store)
        let now = makeDate(year: 2026, month: 7, day: 17, hour: 7, minute: 0)
        let next = scheduler.nextFireDate(
            from: now,
            intervalMinutes: 60,
            startHour: 9,
            startMinute: 30,
            endHour: 21,
            endMinute: 0
        )
        let cal = Calendar.current
        XCTAssertEqual(cal.component(.hour, from: next), 9)
        XCTAssertEqual(cal.component(.minute, from: next), 30)
        XCTAssertTrue(scheduler.isActiveWindowStart(next, startHour: 9, startMinute: 30))
    }

    func testPastScheduledSummarySaysRemindingSoon() {
        let suiteName = "SipTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = IntakeStore(defaults: defaults)
        let scheduler = ReminderScheduler(store: store, defaults: defaults)
        // Force a schedule in the past relative to real now by writing status via reschedule
        // with a fire that will be treated as past when summarizing.
        let t0 = Date().addingTimeInterval(-120)
        // Simulate committed past fire.
        defaults.set(t0.timeIntervalSince1970, forKey: "sip.nextScheduledFire")
        // Soft reschedule with now after fire → recomputes forward.
        defaults.set(Date().dayKey, forKey: "sip.lastDayStartNotifiedDay")
        store.settings.activeStartHour = 0
        store.settings.activeEndHour = 23
        store.settings.reminderIntervalMinutes = 60
        scheduler.reschedule(force: false, now: Date())
        // After recompute, status should be future.
        if case .scheduled(let d) = scheduler.status {
            XCTAssertTrue(d > Date().addingTimeInterval(-1))
        } else {
            XCTFail("expected scheduled")
        }
    }

    func testRemoveEntrySoftPreservesNextFire() {
        let suiteName = "SipTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = IntakeStore(defaults: defaults)
        store.settings.reminderIntervalMinutes = 60
        store.settings.activeStartHour = 9
        store.settings.activeEndHour = 21
        let t0 = makeDate(year: 2026, month: 7, day: 17, hour: 10, minute: 0)
        defaults.set(t0.dayKey, forKey: "sip.lastDayStartNotifiedDay")

        let scheduler = ReminderScheduler(store: store, defaults: defaults)
        scheduler.reschedule(force: true, now: t0)
        guard case .scheduled(let first) = scheduler.status else {
            return XCTFail("expected initial schedule")
        }

        let older = store.addIntake(amountML: 100)!
        _ = store.addIntake(amountML: 50)
        // Pin schedule again after adds (add is force with wall clock in production).
        scheduler.reschedule(force: true, now: t0)

        var kind: IntakeStore.ChangeKind?
        store.onStateChanged = { kind = $0 }
        store.removeEntry(id: older.id)
        XCTAssertEqual(kind, .soft)

        // Soft reschedule mid-interval must keep the committed fire.
        let tMid = t0.addingTimeInterval(30 * 60)
        scheduler.reschedule(force: false, now: tMid)
        guard case .scheduled(let after) = scheduler.status else {
            return XCTFail("expected schedule after soft delete")
        }
        XCTAssertEqual(after.timeIntervalSince1970, first.timeIntervalSince1970, accuracy: 1)
    }

    func testRemoveEntryCrossingGoalForcesReschedule() {
        let store = makeIsolatedStore()
        var kinds: [IntakeStore.ChangeKind] = []
        store.onStateChanged = { kinds.append($0) }
        // goalRange lower bound is 500.
        store.settings.dailyGoalML = 500
        let e1 = store.addIntake(amountML: 500)!
        XCTAssertTrue(store.isGoalReached)
        kinds.removeAll()
        // Deleting the only entry un-reaches goal → force.
        store.removeEntry(id: e1.id)
        XCTAssertEqual(kinds.last, .force)
        XCTAssertFalse(store.isGoalReached)
    }

    func testSettingsChangeKindIsSettings() {
        let store = makeIsolatedStore()
        var kinds: [IntakeStore.ChangeKind] = []
        store.onStateChanged = { kinds.append($0) }
        store.settings.dailyGoalML = 1800
        XCTAssertEqual(kinds.last, .settings)
    }

    func testWeekdayShortLabelLocaleAware() {
        let en = Locale(identifier: "en_US")
        var cal = Calendar(identifier: .gregorian)
        cal.locale = en
        // Sunday = 1
        let sunday = AppSettings.weekdayShortLabel(for: 1, calendar: cal)
        XCTAssertFalse(sunday.isEmpty)
        XCTAssertEqual(sunday.count, 1) // very short: "S" etc.
    }

    // MARK: - Helpers

    private func makeIsolatedStore() -> IntakeStore {
        let suiteName = "SipTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return IntakeStore(defaults: defaults)
    }

    private func calendarDate(hour: Int, minute: Int = 0) -> Date {
        makeDate(year: 2026, month: 7, day: 15, hour: hour, minute: minute)
    }

    private func makeDate(year: Int, month: Int, day: Int, hour: Int, minute: Int, second: Int = 0) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second
        return Calendar.current.date(from: components)!
    }
}
