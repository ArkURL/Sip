//
//  OnboardingView.swift
//  Sip
//

import SwiftUI

struct OnboardingView: View {
    @ObservedObject var store: IntakeStore
    let onFinish: () -> Void

    @State private var goal: Double = 2000
    @State private var permissionNote: String?

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "drop.fill")
                .font(.system(size: 48))
                .foregroundStyle(.cyan)
                .padding(.top, 12)

            Text("欢迎使用 Sip")
                .font(.title.weight(.semibold))

            Text("设定每日目标，轻松记录喝水，到点温柔提醒。")
                .font(.callout)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 280)

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("每日目标")
                        .font(.headline)
                    Spacer()
                    Text("\(Int(goal)) ml")
                        .foregroundStyle(.secondary)
                        .monospacedDigit()
                }
                Slider(value: $goal, in: 500...5000, step: 50)
                    .tint(.cyan)
            }
            .padding(.horizontal, 8)

            if let permissionNote {
                Text(permissionNote)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                Task { await finish() }
            } label: {
                Text("开始使用")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.cyan)
            .controlSize(.large)
        }
        .padding(28)
        .frame(width: 360)
    }

    private func finish() async {
        store.settings.dailyGoalML = Int(goal)
        let granted = await NotificationService.requestAuthorization()
        permissionNote = granted ? nil : "未开启通知时仍可手动记录，稍后可在系统设置中允许通知。"
        store.completeOnboarding()
        // Brief pause so user can see the note if denied; always finish.
        if !granted {
            try? await Task.sleep(nanoseconds: 800_000_000)
        }
        onFinish()
    }
}

#Preview {
    OnboardingView(store: IntakeStore(), onFinish: {})
}
