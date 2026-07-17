//
//  SettingsView.swift
//  Sip
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: IntakeStore
    /// When presented as a sheet from the main window, show an explicit dismiss control.
    var showsDismissButton: Bool = false

    @Environment(\.dismiss) private var dismiss
    @State private var startTime: Date = SettingsView.date(hour: 9)
    @State private var endTime: Date = SettingsView.date(hour: 21)

    var body: some View {
        VStack(spacing: 0) {
            if showsDismissButton {
                HStack {
                    Text("Settings")
                        .font(.headline)
                    Spacer()
                    Button("Done") {
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)
            }

            Form {
                Section("Daily goal") {
                    HStack {
                        Text("Target volume")
                        Spacer()
                        Text("\(store.settings.dailyGoalML) ml")
                            .foregroundStyle(.secondary)
                            .monospacedDigit()
                    }
                    Slider(
                        value: Binding(
                            get: { Double(store.settings.dailyGoalML) },
                            set: { store.settings.dailyGoalML = Int($0 / 50) * 50 }
                        ),
                        in: Double(AppSettings.goalRange.lowerBound)...Double(AppSettings.goalRange.upperBound),
                        step: 50
                    )
                    Stepper(
                        value: Binding(
                            get: { store.settings.dailyGoalML },
                            set: { store.settings.dailyGoalML = $0 }
                        ),
                        in: AppSettings.goalRange,
                        step: 50
                    ) {
                        Text("Fine adjust")
                    }
                }

                Section("Reminders") {
                    Toggle("Enable reminders", isOn: Binding(
                        get: { store.settings.reminderEnabled },
                        set: { store.settings.reminderEnabled = $0 }
                    ))

                    Picker("Interval", selection: Binding(
                        get: { store.settings.reminderIntervalMinutes },
                        set: { store.settings.reminderIntervalMinutes = $0 }
                    )) {
                        ForEach(AppSettings.intervalOptions, id: \.self) { minutes in
                            Text(String(localized: "\(minutes) min")).tag(minutes)
                        }
                    }
                    .disabled(!store.settings.reminderEnabled)

                    DatePicker(
                        "Start time",
                        selection: $startTime,
                        displayedComponents: .hourAndMinute
                    )
                    .disabled(!store.settings.reminderEnabled)
                    .onChange(of: startTime) { _, newValue in
                        store.settings.activeStartHour = Calendar.current.component(.hour, from: newValue)
                    }

                    DatePicker(
                        "End time",
                        selection: $endTime,
                        displayedComponents: .hourAndMinute
                    )
                    .disabled(!store.settings.reminderEnabled)
                    .onChange(of: endTime) { _, newValue in
                        store.settings.activeEndHour = Calendar.current.component(.hour, from: newValue)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("Reminder days")
                            .foregroundStyle(store.settings.reminderEnabled ? Color.primary : Color.secondary)

                        HStack(spacing: 6) {
                            ForEach(1...7, id: \.self) { weekday in
                                weekdayToggle(weekday)
                            }
                        }
                        .disabled(!store.settings.reminderEnabled)
                    }
                    .padding(.vertical, 4)

                    Text("Only on selected days, during active hours, and before you hit the goal.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("About") {
                    LabeledContent("App", value: "Sip")
                    LabeledContent("Version", value: Self.appVersionString)
                }
            }
            .formStyle(.grouped)
            // Keep scrolling; hide the permanent scrollbar chrome.
            .scrollIndicators(.hidden)
        }
        .frame(width: 400, height: showsDismissButton ? 560 : 520)
        .onAppear {
            startTime = Self.date(hour: store.settings.activeStartHour)
            endTime = Self.date(hour: store.settings.activeEndHour)
        }
    }

    // MARK: - Weekday controls

    private func weekdayToggle(_ weekday: Int) -> some View {
        let label = AppSettings.weekdayShortLabel(for: weekday)
        let isOn = store.settings.reminderWeekdaySet.contains(weekday)

        return Button {
            toggleWeekday(weekday)
        } label: {
            Text(label)
                .font(.callout.weight(isOn ? .semibold : .regular))
                .foregroundStyle(isOn ? Color.white : Color.secondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: SipTheme.chipRadius, style: .continuous)
                        .fill(isOn ? SipTheme.accent : Color.primary.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: SipTheme.chipRadius, style: .continuous)
                        .strokeBorder(
                            isOn ? SipTheme.accent.opacity(0.9) : Color.primary.opacity(0.12),
                            lineWidth: isOn ? 0 : 1
                        )
                )
        }
        .buttonStyle(.plain)
        .help(isOn ? String(localized: "Enabled — click to turn off") : String(localized: "Off — click to enable"))
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private func toggleWeekday(_ weekday: Int) {
        var days = store.settings.reminderWeekdaySet
        if days.contains(weekday) {
            // Keep at least one day selected.
            guard days.count > 1 else { return }
            days.remove(weekday)
        } else {
            days.insert(weekday)
        }
        store.settings.reminderWeekdays = days.sorted()
    }

    private static func date(hour: Int) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = 0
        return Calendar.current.date(from: components) ?? Date()
    }

    private static var appVersionString: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String
        if let build, !build.isEmpty {
            return "\(short) (\(build))"
        }
        return short
    }
}

#Preview {
    SettingsView(store: IntakeStore(), showsDismissButton: true)
}
