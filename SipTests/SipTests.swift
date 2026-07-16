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
        // 14:00 is in 9–21
        let date = calendarDate(hour: 14)
        XCTAssertTrue(date.isInActiveHours(startHour: 9, endHour: 21))

        let morning = calendarDate(hour: 7)
        XCTAssertFalse(morning.isInActiveHours(startHour: 9, endHour: 21))

        let night = calendarDate(hour: 22)
        XCTAssertFalse(night.isInActiveHours(startHour: 9, endHour: 21))
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

    // MARK: - Helpers

    private func makeIsolatedStore() -> IntakeStore {
        let suiteName = "SipTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        return IntakeStore(defaults: defaults)
    }

    private func calendarDate(hour: Int, minute: Int = 0) -> Date {
        makeDate(year: 2026, month: 7, day: 15, hour: hour, minute: minute)
    }

    private func makeDate(year: Int, month: Int, day: Int, hour: Int, minute: Int) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components)!
    }
}
