//
//  IntakeListView.swift
//  Sip
//

import SwiftUI

struct IntakeListView: View {
    let entries: [IntakeEntry]
    let onUndoLast: () -> Void
    let onDelete: (UUID) -> Void

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("今日记录")
                    .font(.headline)
                Spacer()
                if !entries.isEmpty {
                    Button("撤销最近") {
                        onUndoLast()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                    .font(.caption)
                }
            }

            if entries.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "cup.and.saucer")
                            .font(.title2)
                            .foregroundStyle(.tertiary)
                        Text("还没有记录")
                            .font(.callout)
                            .foregroundStyle(.secondary)
                        Text("点上方按钮开始记录吧")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                    .padding(.vertical, 20)
                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .background(Color.primary.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            } else {
                List {
                    ForEach(entries) { entry in
                        HStack {
                            Text(Self.timeFormatter.string(from: entry.timestamp))
                                .font(.body.monospacedDigit())
                                .foregroundStyle(.secondary)
                                .frame(width: 48, alignment: .leading)

                            Text("+\(entry.amountML) ml")
                                .font(.body.weight(.medium))

                            Spacer()
                        }
                        .padding(.vertical, 2)
                        .listRowInsets(EdgeInsets(top: 4, leading: 8, bottom: 4, trailing: 8))
                        .contextMenu {
                            Button("删除", role: .destructive) {
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
                .frame(minHeight: 120, maxHeight: 180)
                .scrollContentBackground(.hidden)
                .background(Color.primary.opacity(0.03))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
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
