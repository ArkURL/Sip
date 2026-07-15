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

            Text(statusText)
                .font(.callout)
                .foregroundStyle(isGoalReached ? Color.green : Color.secondary)
                .multilineTextAlignment(.center)
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
        statusText: "还需 750 ml"
    )
    .padding()
    .frame(width: 360)
}
