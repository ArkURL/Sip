//
//  AppSettings.swift
//  Sip
//

import Foundation

struct AppSettings: Codable, Equatable {
    var dailyGoalML: Int
    var reminderEnabled: Bool
    var reminderIntervalMinutes: Int
    var activeStartHour: Int
    var activeEndHour: Int
    var hasCompletedOnboarding: Bool

    static let `default` = AppSettings(
        dailyGoalML: 2000,
        reminderEnabled: true,
        reminderIntervalMinutes: 60,
        activeStartHour: 9,
        activeEndHour: 21,
        hasCompletedOnboarding: false
    )

    static let goalRange = 500...5000
    static let intervalOptions = [30, 45, 60, 90, 120]
    static let quickAmounts = [100, 150, 250, 350, 500]

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
    }
}
