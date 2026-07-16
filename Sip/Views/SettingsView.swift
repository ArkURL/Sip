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
                    Text("设置")
                        .font(.headline)
                    Spacer()
                    Button("完成") {
                        dismiss()
                    }
                    .keyboardShortcut(.defaultAction)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)
            }

            Form {
                Section("每日目标") {
                    HStack {
                        Text("目标水量")
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
                        Text("精细调节")
                    }
                }

                Section("提醒") {
                    Toggle("开启提醒", isOn: Binding(
                        get: { store.settings.reminderEnabled },
                        set: { store.settings.reminderEnabled = $0 }
                    ))

                    Picker("提醒间隔", selection: Binding(
                        get: { store.settings.reminderIntervalMinutes },
                        set: { store.settings.reminderIntervalMinutes = $0 }
                    )) {
                        ForEach(AppSettings.intervalOptions, id: \.self) { minutes in
                            Text("\(minutes) 分钟").tag(minutes)
                        }
                    }
                    .disabled(!store.settings.reminderEnabled)

                    DatePicker(
                        "开始时间",
                        selection: $startTime,
                        displayedComponents: .hourAndMinute
                    )
                    .disabled(!store.settings.reminderEnabled)
                    .onChange(of: startTime) { _, newValue in
                        store.settings.activeStartHour = Calendar.current.component(.hour, from: newValue)
                    }

                    DatePicker(
                        "结束时间",
                        selection: $endTime,
                        displayedComponents: .hourAndMinute
                    )
                    .disabled(!store.settings.reminderEnabled)
                    .onChange(of: endTime) { _, newValue in
                        store.settings.activeEndHour = Calendar.current.component(.hour, from: newValue)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        Text("提醒日期")
                            .foregroundStyle(store.settings.reminderEnabled ? Color.primary : Color.secondary)

                        HStack(spacing: 6) {
                            ForEach(1...7, id: \.self) { weekday in
                                weekdayToggle(weekday)
                            }
                        }
                        .disabled(!store.settings.reminderEnabled)
                    }
                    .padding(.vertical, 4)

                    Text("仅在选中的日期、活跃时段内，且未达标时发送提醒。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section("关于") {
                    LabeledContent("应用", value: "Sip")
                    LabeledContent("版本", value: "1.0 MVP")
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
        let label = AppSettings.weekdayShortLabels[weekday - 1]
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
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(isOn ? Color.cyan : Color.primary.opacity(0.06))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .strokeBorder(
                            isOn ? Color.cyan.opacity(0.9) : Color.primary.opacity(0.12),
                            lineWidth: isOn ? 0 : 1
                        )
                )
        }
        .buttonStyle(.plain)
        .help(isOn ? "已启用，点击关闭" : "已关闭，点击启用")
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
}

#Preview {
    SettingsView(store: IntakeStore(), showsDismissButton: true)
}
