//
//  Date+Day.swift
//  Sip
//

import Foundation

extension Date {
    /// Local calendar day key, e.g. "2026-07-15"
    var dayKey: String {
        let formatter = Date.dayKeyFormatter
        // Keep timezone current so long-running menu-bar processes survive travel/DST.
        formatter.timeZone = TimeZone.current
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

    /// Minutes from local midnight (0…1439).
    var minutesFromMidnight: Int {
        hourOfDay * 60 + minuteOfHour
    }

    /// `Calendar` weekday: 1 = Sunday … 7 = Saturday.
    var weekday: Int {
        Calendar.current.component(.weekday, from: self)
    }

    func isAllowedWeekday(_ allowed: Set<Int>) -> Bool {
        let days = allowed.isEmpty ? Set(1...7) : allowed
        return days.contains(weekday)
    }

    /// Active window check. End time is **inclusive of that minute**
    /// (e.g. end 21:00 → still active at 21:00, not at 21:01).
    func isInActiveHours(
        startHour: Int,
        startMinute: Int = 0,
        endHour: Int,
        endMinute: Int = 0
    ) -> Bool {
        let now = minutesFromMidnight
        let start = startHour * 60 + startMinute
        let end = endHour * 60 + endMinute
        if start < end {
            return now >= start && now <= end
        } else if start > end {
            // Overnight window, e.g. 22:00–06:30
            return now >= start || now <= end
        } else {
            return false
        }
    }

    /// Convenience using `AppSettings` active window fields.
    func isInActiveHours(settings: AppSettings) -> Bool {
        isInActiveHours(
            startHour: settings.activeStartHour,
            startMinute: settings.activeStartMinute,
            endHour: settings.activeEndHour,
            endMinute: settings.activeEndMinute
        )
    }

    /// Next moment when reminders may fire: an allowed weekday at start time,
    /// or `self` if already inside today's active window on an allowed day.
    func nextReminderOpportunity(
        startHour: Int,
        startMinute: Int = 0,
        endHour: Int,
        endMinute: Int = 0,
        allowedWeekdays: Set<Int>
    ) -> Date {
        let calendar = Calendar.current
        let allowed = allowedWeekdays.isEmpty ? Set(1...7) : allowedWeekdays

        if isAllowedWeekday(allowed),
           isInActiveHours(
            startHour: startHour,
            startMinute: startMinute,
            endHour: endHour,
            endMinute: endMinute
           ) {
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
            components.minute = startMinute
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

        // Fallback: tomorrow at start (should be unreachable if allowed is non-empty).
        return calendar.date(byAdding: .day, value: 1, to: self) ?? self
    }

    private static let dayKeyFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
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
