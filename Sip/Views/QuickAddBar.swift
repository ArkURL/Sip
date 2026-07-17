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

            // ~3 columns in the fixed 380pt window → wider, taller hit targets.
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 100), spacing: 10)],
                spacing: 10
            ) {
                ForEach(amounts, id: \.self) { amount in
                    Button {
                        onAdd(amount)
                    } label: {
                        Text("+\(amount)")
                            .font(.body.weight(.semibold).monospacedDigit())
                            .frame(maxWidth: .infinity)
                            .frame(minHeight: 36)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(SipAmountButtonStyle())
                }

                Button {
                    showCustom = true
                } label: {
                    Text("Custom")
                        .font(.body.weight(.medium))
                        .frame(maxWidth: .infinity)
                        .frame(minHeight: 36)
                        .padding(.vertical, 6)
                }
                .buttonStyle(SipAmountButtonStyle())
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

/// Soft filled chips — same look for fixed amounts and Custom.
private struct SipAmountButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(SipTheme.accentDeep)
            .background(
                SipTheme.accent.opacity(configuration.isPressed ? 0.18 : 0.12)
            )
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .animation(.easeOut(duration: 0.12), value: configuration.isPressed)
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
                .tint(SipTheme.accent)
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
