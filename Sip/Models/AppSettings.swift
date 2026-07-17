//
//  AppSettings.swift
//  Sip
//

import Foundation

struct AppSettings: Equatable {
    var dailyGoalML: Int
    var reminderEnabled: Bool
    var reminderIntervalMinutes: Int
    var activeStartHour: Int
    var activeEndHour: Int
    /// Calendar weekday values: 1 = Sunday … 7 = Saturday (same as `Calendar.Component.weekday`).
    var reminderWeekdays: [Int]
    var hasCompletedOnboarding: Bool

    static let `default` = AppSettings(
        dailyGoalML: 2000,
        reminderEnabled: true,
        reminderIntervalMinutes: 60,
        activeStartHour: 9,
        activeEndHour: 21,
        reminderWeekdays: Array(1...7),
        hasCompletedOnboarding: false
    )

    static let goalRange = 500...5000
    static let intervalOptions = [30, 45, 60, 90, 120]
    static let quickAmounts = [100, 150, 250, 350, 500]

    /// Mon…Fri in `Calendar` weekday numbering.
    static let workweekDays = [2, 3, 4, 5, 6]
    static let weekendDays = [1, 7]
    static let allWeekdays = Array(1...7)

    /// Short weekday labels for Calendar weekday 1…7 (locale-aware).
    static func weekdayShortLabel(for weekday: Int, calendar: Calendar = .current) -> String {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        guard weekday >= 1, weekday <= symbols.count else { return "?" }
        return symbols[weekday - 1]
    }

    var reminderWeekdaySet: Set<Int> {
        Set(reminderWeekdays)
    }

    mutating func clamp() {
        dailyGoalML = min(max(dailyGoalML, Self.goalRange.lowerBound), Self.goalRange.upperBound)
        if !Self.intervalOptions.contains(reminderIntervalMinutes) {
            reminderIntervalMinutes = 60
        }
        activeStartHour = min(max(activeStartHour, 0), 23)
        activeEndHour = min(max(activeEndHour, 0), 23)
        if activeStartHour == activeEndHour {
            activeEndHour = (activeStartHour + 12) % 24
        }

        var days = Set(reminderWeekdays.filter { (1...7).contains($0) })
        if days.isEmpty {
            days = Set(Self.allWeekdays)
        }
        reminderWeekdays = days.sorted()
    }

    func allowsReminder(on date: Date, calendar: Calendar = .current) -> Bool {
        let weekday = calendar.component(.weekday, from: date)
        return reminderWeekdaySet.contains(weekday)
    }
}

// MARK: - Codable (backward compatible with older settings JSON)

extension AppSettings: Codable {
    private enum CodingKeys: String, CodingKey {
        case dailyGoalML
        case reminderEnabled
        case reminderIntervalMinutes
        case activeStartHour
        case activeEndHour
        case reminderWeekdays
        case hasCompletedOnboarding
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        dailyGoalML = try c.decodeIfPresent(Int.self, forKey: .dailyGoalML) ?? Self.default.dailyGoalML
        reminderEnabled = try c.decodeIfPresent(Bool.self, forKey: .reminderEnabled) ?? Self.default.reminderEnabled
        reminderIntervalMinutes = try c.decodeIfPresent(Int.self, forKey: .reminderIntervalMinutes)
            ?? Self.default.reminderIntervalMinutes
        activeStartHour = try c.decodeIfPresent(Int.self, forKey: .activeStartHour) ?? Self.default.activeStartHour
        activeEndHour = try c.decodeIfPresent(Int.self, forKey: .activeEndHour) ?? Self.default.activeEndHour
        // Missing key → all days (preserve previous “every day” behavior for existing users).
        reminderWeekdays = try c.decodeIfPresent([Int].self, forKey: .reminderWeekdays) ?? Self.allWeekdays
        hasCompletedOnboarding = try c.decodeIfPresent(Bool.self, forKey: .hasCompletedOnboarding)
            ?? Self.default.hasCompletedOnboarding
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(dailyGoalML, forKey: .dailyGoalML)
        try c.encode(reminderEnabled, forKey: .reminderEnabled)
        try c.encode(reminderIntervalMinutes, forKey: .reminderIntervalMinutes)
        try c.encode(activeStartHour, forKey: .activeStartHour)
        try c.encode(activeEndHour, forKey: .activeEndHour)
        try c.encode(reminderWeekdays, forKey: .reminderWeekdays)
        try c.encode(hasCompletedOnboarding, forKey: .hasCompletedOnboarding)
    }
}
