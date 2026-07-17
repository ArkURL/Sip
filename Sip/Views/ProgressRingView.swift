//
//  ProgressRingView.swift
//  Sip
//

import SwiftUI

struct ProgressRingView: View {
    let progress: Double
    let totalML: Int
    let goalML: Int
    let isGoalReached: Bool
    let statusText: String
    /// e.g. "Next 14:30" / "Reminders off" — nil hides the row.
    var nextReminderText: String? = nil

    private var ringProgress: CGFloat {
        CGFloat(min(max(progress, 0), 1))
    }

    var body: some View {
        VStack(spacing: 12) {
            ZStack {
                Circle()
                    .stroke(Color.primary.opacity(0.08), lineWidth: 14)

                Circle()
                    .trim(from: 0, to: ringProgress)
                    .stroke(
                        isGoalReached ? Color.green : Color.cyan,
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.35), value: ringProgress)

                VStack(spacing: 4) {
                    if isGoalReached {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(.green)
                    } else {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 22))
                            .foregroundStyle(.cyan)
                    }

                    Text("\(totalML)")
                        .font(.system(size: 36, weight: .semibold, design: .rounded))
                        .monospacedDigit()

                    Text("/ \(goalML) ml")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 180, height: 180)
            .padding(.top, 8)

            VStack(spacing: 6) {
                Text(statusText)
                    .font(.callout)
                    .foregroundStyle(isGoalReached ? Color.green : Color.secondary)
                    .multilineTextAlignment(.center)

                if let nextReminderText {
                    HStack(spacing: 4) {
                        Image(systemName: "bell")
                            .font(.caption2)
                        Text(nextReminderText)
                            .font(.caption)
                            .monospacedDigit()
                    }
                    .foregroundStyle(.tertiary)
                    .accessibilityLabel(nextReminderText)
                }
            }
            // Keep status + next-reminder block height stable when text swaps.
            .frame(minHeight: 40, alignment: .top)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    ProgressRingView(
        progress: 0.62,
        totalML: 1250,
        goalML: 2000,
        isGoalReached: false,
        statusText: "Still 750 ml to go",
        nextReminderText: "Next 14:30"
    )
    .padding()
    .frame(width: 360)
}
