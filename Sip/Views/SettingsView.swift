//
//  SettingsView.swift
//  Sip
//

import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: IntakeStore
    @State private var startTime: Date = SettingsView.date(hour: 9)
    @State private var endTime: Date = SettingsView.date(hour: 21)

    var body: some View {
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

                Text("仅在未达标且处于活跃时段内发送提醒。")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("关于") {
                LabeledContent("应用", value: "Sip")
                LabeledContent("版本", value: "1.0 MVP")
            }
        }
        .formStyle(.grouped)
        .padding()
        .frame(width: 380, height: 420)
        .onAppear {
            startTime = Self.date(hour: store.settings.activeStartHour)
            endTime = Self.date(hour: store.settings.activeEndHour)
        }
    }

    private static func date(hour: Int) -> Date {
        var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        components.hour = hour
        components.minute = 0
        return Calendar.current.date(from: components) ?? Date()
    }
}

#Preview {
    SettingsView(store: IntakeStore())
}
