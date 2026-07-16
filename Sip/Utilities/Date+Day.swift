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

    /// `Calendar` weekday: 1 = Sunday … 7 = Saturday.
    var weekday: Int {
        Calendar.current.component(.weekday, from: self)
    }

    func isAllowedWeekday(_ allowed: Set<Int>) -> Bool {
        let days = allowed.isEmpty ? Set(1...7) : allowed
        return days.contains(weekday)
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

    /// Next moment when reminders may fire: an allowed weekday at `startHour:00`,
    /// or `self` if already inside today's active window on an allowed day.
    func nextReminderOpportunity(
        startHour: Int,
        endHour: Int,
        allowedWeekdays: Set<Int>
    ) -> Date {
        let calendar = Calendar.current
        let allowed = allowedWeekdays.isEmpty ? Set(1...7) : allowedWeekdays

        if isAllowedWeekday(allowed), isInActiveHours(startHour: startHour, endHour: endHour) {
            return self
        }

        // Search today + next 7 days for the next valid window start.
        for dayOffset in 0..<8 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: self)) else {
                continue
            }
            let dayWeekday = calendar.component(.weekday, from: day)
            guard allowed.contains(dayWeekday) else { continue }

            var components = calendar.dateComponents([.year, .month, .day], from: day)
            components.hour = startHour
            components.minute = 0
            components.second = 0
            guard let windowStart = calendar.date(from: components) else { continue }

            if dayOffset == 0 {
                // Today is allowed.
                if self < windowStart {
                    return windowStart
                }
                // After today's window — try later days.
                continue
            }
            return windowStart
        }

        // Fallback: tomorrow at startHour (should be unreachable if allowed is non-empty).
        return calendar.date(byAdding: .day, value: 1, to: self) ?? self
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
