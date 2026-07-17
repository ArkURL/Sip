//
//  DayLifecycleMonitor.swift
//  Sip
//

import Foundation
import AppKit

/// Keeps “today” state fresh while the app is menu-bar-only (often never becomes active).
/// Triggers: calendar day change, system wake from sleep, and a timer at local midnight.
@MainActor
final class DayLifecycleMonitor {
    private let onRefresh: () -> Void
    private var dayChangeObserver: NSObjectProtocol?
    private var wakeObserver: NSObjectProtocol?
    private var externalRefreshObserver: NSObjectProtocol?
    private var midnightTimer: Timer?

    init(onRefresh: @escaping () -> Void) {
        self.onRefresh = onRefresh
        start()
    }

    deinit {
        // Timer invalidation is safe; NotificationCenter tokens need main-thread removal.
        midnightTimer?.invalidate()
    }

    func start() {
        stop()

        dayChangeObserver = NotificationCenter.default.addObserver(
            forName: .NSCalendarDayChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }

        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }

        // In-process (e.g. local notification delegate) can request the same path.
        externalRefreshObserver = NotificationCenter.default.addObserver(
            forName: .sipDayRefreshNeeded,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }

        scheduleMidnightTimer()
    }

    func stop() {
        if let dayChangeObserver {
            NotificationCenter.default.removeObserver(dayChangeObserver)
            self.dayChangeObserver = nil
        }
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
            self.wakeObserver = nil
        }
        if let externalRefreshObserver {
            NotificationCenter.default.removeObserver(externalRefreshObserver)
            self.externalRefreshObserver = nil
        }
        midnightTimer?.invalidate()
        midnightTimer = nil
    }

    private func refresh() {
        onRefresh()
        scheduleMidnightTimer()
    }

    /// Fire shortly after local midnight so menu bar progress rolls over without user interaction.
    private func scheduleMidnightTimer() {
        midnightTimer?.invalidate()

        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: Date())
        guard let startOfTomorrow = calendar.date(byAdding: .day, value: 1, to: startOfToday) else {
            return
        }
        // +1s past midnight avoids edge races with dayKey formatting.
        let fireDate = startOfTomorrow.addingTimeInterval(1)
        let interval = fireDate.timeIntervalSinceNow
        guard interval > 0 else {
            // Clock skew / edge case — try again soon.
            let timer = Timer(timeInterval: 60, repeats: false) { [weak self] _ in
                Task { @MainActor in
                    self?.refresh()
                }
            }
            midnightTimer = timer
            RunLoop.main.add(timer, forMode: .common)
            return
        }

        let timer = Timer(fire: fireDate, interval: 0, repeats: false) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
            }
        }
        midnightTimer = timer
        RunLoop.main.add(timer, forMode: .common)
    }
}

extension Notification.Name {
    /// Posted when something outside DayLifecycleMonitor needs a day/progress refresh
    /// (e.g. a delivered local notification).
    static let sipDayRefreshNeeded = Notification.Name("sip.dayRefreshNeeded")
}
