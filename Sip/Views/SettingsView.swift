//
//  SettingsView.swift
//  Sip
//

import SwiftUI
import UserNotifications

struct SettingsView: View {
    @ObservedObject var store: IntakeStore
    /// When presented as a sheet from the main window, show an explicit dismiss control.
    var showsDismissButton: Bool = false

    @EnvironmentObject private var notificationPermission: NotificationPermissionModel
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    @State private var startTime: Date = SettingsView.date(hour: 9, minute: 0)
    @State private var endTime: Date = SettingsView.date(hour: 21, minute: 0)

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

                    notificationPermissionRow

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
                        applyStartTime(newValue)
                    }

                    DatePicker(
                        "End time",
                        selection: $endTime,
                        displayedComponents: .hourAndMinute
                    )
                    .disabled(!store.settings.reminderEnabled)
                    .onChange(of: endTime) { _, newValue in
                        applyEndTime(newValue)
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

                    Text("Only on selected days, from start through end (inclusive), and before you hit the goal.")
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
        .frame(width: 400, height: showsDismissButton ? 620 : 580)
        .onAppear {
            startTime = Self.date(
                hour: store.settings.activeStartHour,
                minute: store.settings.activeStartMinute
            )
            endTime = Self.date(
                hour: store.settings.activeEndHour,
                minute: store.settings.activeEndMinute
            )
        }
        // Prefer `.task` over onAppear+Task so refresh is tied to view lifetime and
        // always re-runs when Settings is re-opened.
        .task {
            await notificationPermission.refresh()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task { await notificationPermission.refresh() }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await notificationPermission.refresh() }
        }
    }

    // MARK: - Notification permission

    @ViewBuilder
    private var notificationPermissionRow: some View {
        // Keep rows flat for macOS Form hit-testing; nested VStack + Button can swallow clicks.
        HStack {
            Text("Notifications")
            Spacer()
            Text(notificationPermission.statusLabel)
                .foregroundStyle(.secondary)
                .font(.callout)
                // Force Text identity to follow status so Form rows do not keep a stale label.
                .id(notificationPermission.status.rawValue)
        }

        switch notificationPermission.status {
        case .denied:
            Text("Notifications are off in System Settings, so reminders will not appear.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Button("Open System Settings…") {
                NotificationService.openSystemNotificationSettings()
            }
        case .notDetermined:
            Button("Allow Notifications…") {
                Task { await allowNotificationsTapped() }
            }
        default:
            EmptyView()
        }
    }

    @MainActor
    private func allowNotificationsTapped() async {
        let previous = notificationPermission.status
        let granted = await NotificationService.requestAuthorization()
        await notificationPermission.refresh()

        if granted {
            // Permission may have been missing when earlier schedules were attempted.
            store.refreshRemindersAfterPermissionChange()
            return
        }

        // If the system alert never appeared, status stays `.notDetermined` — open
        // Settings so the click always has a visible result. Do not bounce the user
        // into Settings immediately after they explicitly tapped Don't Allow.
        if notificationPermission.status == .notDetermined || previous == .denied {
            NotificationService.openSystemNotificationSettings()
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

    private func applyStartTime(_ date: Date) {
        let cal = Calendar.current
        var s = store.settings
        s.activeStartHour = cal.component(.hour, from: date)
        s.activeStartMinute = cal.component(.minute, from: date)
        store.settings = s
    }

    private func applyEndTime(_ date: Date) {
        let cal = Calendar.current
        var s = store.settings
        s.activeEndHour = cal.component(.hour, from: date)
        s.activeEndMinute = cal.component(.minute, from: date)
        store.settings = s
    }

    private static func date(hour: Int, minute: Int) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = minute
        components.second = 0
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
        .environmentObject(NotificationPermissionModel())
}
