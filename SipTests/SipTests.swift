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

    func testPersistenceRoundTrip() {
        let suiteName = "SipTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store1 = IntakeStore(defaults: defaults)
        store1.settings.dailyGoalML = 1800
        store1.addIntake(amountML: 350)

        let store2 = IntakeStore(defaults: defaults)
        XCTAssertEqual(store2.settings.dailyGoalML, 1800)
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
        var components = DateComponents()
        components.year = 2026
        components.month = 7
        components.day = 15
        components.hour = hour
        components.minute = minute
        return Calendar.current.date(from: components)!
    }
}
