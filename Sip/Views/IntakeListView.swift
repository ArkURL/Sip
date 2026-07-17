//
//  IntakeListView.swift
//  Sip
//

import SwiftUI

struct IntakeListView: View {
    let entries: [IntakeEntry]
    let onUndoLast: () -> Void
    let onDelete: (UUID) -> Void

    /// Shared height for empty + list states so adding the first entry does not reflow the window.
    private static let panelHeight: CGFloat = 148

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = .autoupdatingCurrent
        f.setLocalizedDateFormatFromTemplate("HHmm")
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Today's log")
                    .font(.headline)
                Spacer()
                // Reserve space so the header height does not jump when undo appears.
                Button("Undo recent") {
                    onUndoLast()
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .font(.caption)
                .opacity(entries.isEmpty ? 0 : 1)
                .disabled(entries.isEmpty)
                .accessibilityHidden(entries.isEmpty)
            }

            Group {
                if entries.isEmpty {
                    emptyState
                } else {
                    entryList
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .frame(height: Self.panelHeight)
            .background(
                RoundedRectangle(cornerRadius: SipTheme.cornerRadius, style: .continuous)
                    .fill(Color.primary.opacity(0.035))
            )
            .overlay(
                RoundedRectangle(cornerRadius: SipTheme.cornerRadius, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.06), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: SipTheme.cornerRadius, style: .continuous))
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "drop")
                .font(.system(size: 26, weight: .light))
                .foregroundStyle(SipTheme.accent.opacity(0.55))
                .symbolRenderingMode(.hierarchical)
            Text("No entries yet")
                .font(.callout)
                .foregroundStyle(.secondary)
            Text("Tap above to start logging")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var entryList: some View {
        List {
            ForEach(entries) { entry in
                HStack(spacing: 10) {
                    // Accent tick — ties rows to the water theme without clutter.
                    RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                        .fill(SipTheme.accent.opacity(0.55))
                        .frame(width: 3, height: 22)

                    Text(Self.timeFormatter.string(from: entry.timestamp))
                        .font(.body.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 52, alignment: .leading)

                    Text("+\(entry.amountML) ml")
                        .font(.body.weight(.semibold).monospacedDigit())
                        .foregroundStyle(SipTheme.accentDeep)

                    Spacer(minLength: 0)
                }
                .padding(.vertical, 3)
                .listRowInsets(EdgeInsets(top: 3, leading: 10, bottom: 3, trailing: 10))
                .listRowBackground(Color.clear)
                .contextMenu {
                    Button("Delete", role: .destructive) {
                        onDelete(entry.id)
                    }
                }
            }
            .onDelete { indexSet in
                for index in indexSet {
                    onDelete(entries[index].id)
                }
            }
        }
        .listStyle(.inset)
        .scrollContentBackground(.hidden)
    }
}

#Preview {
    IntakeListView(
        entries: [
            IntakeEntry(amountML: 250, timestamp: Date()),
            IntakeEntry(amountML: 500, timestamp: Date().addingTimeInterval(-3600))
        ],
        onUndoLast: {},
        onDelete: { _ in }
    )
    .padding()
    .frame(width: 360)
}
