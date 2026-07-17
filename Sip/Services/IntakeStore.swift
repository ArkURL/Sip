//
//  IntakeStore.swift
//  Sip
//

import Foundation
import Combine

@MainActor
final class IntakeStore: ObservableObject {
    /// How reminder scheduling should react to a store mutation.
    enum ChangeKind: Equatable {
        /// Recompute next fire from now (log sip, undo last, day roll).
        case force
        /// Keep existing future fire; refresh notification content if needed (e.g. mid-list delete).
        case soft
        /// Settings changed — AppSession debounces force reschedule so sliders do not thrash.
        case settings
    }

    @Published private(set) var entries: [IntakeEntry] = []
    @Published var settings: AppSettings {
        didSet {
            guard settings != oldValue else { return }
            var clamped = settings
            clamped.clamp()
            if clamped != settings {
                settings = clamped
                return
            }
            persistSettings()
            onStateChanged?(.settings)
        }
    }

    /// Called after intake or settings change so reminders can reschedule.
    var onStateChanged: ((ChangeKind) -> Void)?

    private let defaults: UserDefaults
    private let entriesKey = "sip.todayEntries"
    private let settingsKey = "sip.settings"
    private let dayKeyStorage = "sip.lastActiveDay"

    private var lastActiveDay: String

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: settingsKey),
           let decoded = try? JSONDecoder().decode(AppSettings.self, from: data) {
            var s = decoded
            s.clamp()
            self.settings = s
        } else {
            self.settings = .default
        }
        self.lastActiveDay = defaults.string(forKey: dayKeyStorage) ?? Date().dayKey
        loadEntriesIfSameDay()
        ensureCurrentDay()
    }

    // MARK: - Computed

    var totalML: Int {
        entries.reduce(0) { $0 + $1.amountML }
    }

    var remainingML: Int {
        max(settings.dailyGoalML - totalML, 0)
    }

    var progress: Double {
        guard settings.dailyGoalML > 0 else { return 0 }
        return min(Double(totalML) / Double(settings.dailyGoalML), 1.0)
    }

    var progressPercent: Int {
        Int((progress * 100).rounded())
    }

    var isGoalReached: Bool {
        totalML >= settings.dailyGoalML
    }

    var statusText: String {
        if totalML == 0 {
            return String(localized: "Not started yet")
        } else if isGoalReached {
            return String(localized: "Goal reached 🎉")
        } else {
            return String(localized: "Still \(remainingML) ml to go")
        }
    }

    var sortedEntries: [IntakeEntry] {
        entries.sorted { $0.timestamp > $1.timestamp }
    }

    // MARK: - Actions

    @discardableResult
    func addIntake(amountML: Int) -> IntakeEntry? {
        guard amountML > 0 else { return nil }
        ensureCurrentDay()
        let entry = IntakeEntry(amountML: amountML)
        entries.append(entry)
        persistEntries()
        onStateChanged?(.force)
        return entry
    }

    @discardableResult
    func undoLast() -> IntakeEntry? {
        ensureCurrentDay()
        guard let last = sortedEntries.first,
              let index = entries.firstIndex(where: { $0.id == last.id }) else {
            return nil
        }
        let removed = entries.remove(at: index)
        persistEntries()
        onStateChanged?(.force)
        return removed
    }

    func removeEntry(id: UUID) {
        ensureCurrentDay()
        let beforeGoal = isGoalReached
        entries.removeAll { $0.id == id }
        persistEntries()
        // Editing history should not push the next reminder later.
        // Only force when deleting un-reaches or reaches the goal boundary.
        if beforeGoal != isGoalReached {
            onStateChanged?(.force)
        } else {
            onStateChanged?(.soft)
        }
    }

    /// Clears yesterday’s intake when the local calendar day changes.
    /// - Returns: `true` if the day rolled over and state was reset.
    @discardableResult
    func ensureCurrentDay() -> Bool {
        let today = Date().dayKey
        guard lastActiveDay != today else { return false }
        entries = []
        lastActiveDay = today
        defaults.set(today, forKey: dayKeyStorage)
        persistEntries()
        onStateChanged?(.force)
        return true
    }

    func completeOnboarding() {
        settings.hasCompletedOnboarding = true
    }

    // MARK: - Persistence

    private func loadEntriesIfSameDay() {
        let today = Date().dayKey
        guard lastActiveDay == today,
              let data = defaults.data(forKey: entriesKey),
              let decoded = try? JSONDecoder().decode([IntakeEntry].self, from: data) else {
            entries = []
            return
        }
        entries = decoded
    }

    private func persistEntries() {
        if let data = try? JSONEncoder().encode(entries) {
            defaults.set(data, forKey: entriesKey)
        }
        defaults.set(lastActiveDay, forKey: dayKeyStorage)
    }

    private func persistSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            defaults.set(data, forKey: settingsKey)
        }
    }
}
