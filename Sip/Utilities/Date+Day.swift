//
//  Date+Day.swift
//  Sip
//

import Foundation

extension Date {
    /// Local calendar day key, e.g. "2026-07-15"
    var dayKey: String {
        let formatter = Date.dayKeyFormatter
        return formatter.string(from: self)
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    /// Hour component in local timezone (0–23).
    var hourOfDay: Int {
        Calendar.current.component(.hour, from: self)
    }

    /// Minute component in local timezone (0–59).
    var minuteOfHour: Int {
        Calendar.current.component(.minute, from: self)
    }

    func isInActiveHours(startHour: Int, endHour: Int) -> Bool {
        let hour = hourOfDay
        if startHour < endHour {
            return hour >= startHour && hour < endHour
        } else if startHour > endHour {
            // Overnight window, e.g. 22–6
            return hour >= startHour || hour < endHour
        } else {
            return false
        }
    }

    /// Next date when active window starts at `startHour:00` local time.
    func nextActiveStart(startHour: Int, endHour: Int) -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.year, .month, .day], from: self)
        components.hour = startHour
        components.minute = 0
        components.second = 0

        guard var candidate = calendar.date(from: components) else { return self }

        if isInActiveHours(startHour: startHour, endHour: endHour) {
            return self
        }

        if candidate <= self {
            candidate = calendar.date(byAdding: .day, value: 1, to: candidate) ?? candidate
        }
        return candidate
    }

    private static let dayKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar.current
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()
}

extension Int {
    /// Format milliliters for display, e.g. 1250 → "1250 ml", 2000 → "2000 ml"
    var mlDisplay: String {
        "\(self) ml"
    }

    /// Compact progress for menu bar, prefer L when >= 1000
    var compactVolumeDisplay: String {
        if self >= 1000 {
            let liters = Double(self) / 1000.0
            if self % 1000 == 0 {
                return String(format: "%.0fL", liters)
            }
            return String(format: "%.1fL", liters)
        }
        return "\(self)ml"
    }
}
