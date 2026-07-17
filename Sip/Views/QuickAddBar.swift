//
//  QuickAddBar.swift
//  Sip
//

import SwiftUI

struct QuickAddBar: View {
    let amounts: [Int]
    let onAdd: (Int) -> Void

    @State private var showCustom = false
    @State private var customAmount = 200

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Log water")
                .font(.headline)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 64), spacing: 8)],
                spacing: 8
            ) {
                ForEach(amounts, id: \.self) { amount in
                    Button {
                        onAdd(amount)
                    } label: {
                        Text("+\(amount)")
                            .font(.callout.weight(.medium))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.large)
                    .tint(amount == 250 ? .cyan : nil)
                }

                Button {
                    showCustom = true
                } label: {
                    Text("Custom")
                        .font(.callout.weight(.medium))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
        }
        .sheet(isPresented: $showCustom) {
            CustomAmountSheet(amount: $customAmount) { value in
                onAdd(value)
                showCustom = false
            }
        }
    }
}

private struct CustomAmountSheet: View {
    @Binding var amount: Int
    let onConfirm: (Int) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("Custom amount")
                .font(.headline)

            Stepper(value: $amount, in: 50...2000, step: 50) {
                Text("\(amount) ml")
                    .font(.title2.monospacedDigit())
                    .frame(minWidth: 100)
            }

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)
                Spacer()
                Button("Add") {
                    onConfirm(amount)
                }
                .buttonStyle(.borderedProminent)
                .tint(.cyan)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(24)
        .frame(width: 280)
    }
}

#Preview {
    QuickAddBar(amounts: AppSettings.quickAmounts) { _ in }
        .padding()
        .frame(width: 360)
}
