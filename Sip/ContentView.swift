//
//  ContentView.swift
//  Sip
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: IntakeStore
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 20) {
            header

            ProgressRingView(
                progress: store.progress,
                totalML: store.totalML,
                goalML: store.settings.dailyGoalML,
                isGoalReached: store.isGoalReached,
                statusText: store.statusText
            )

            QuickAddBar(amounts: AppSettings.quickAmounts) { amount in
                store.addIntake(amountML: amount)
            }

            IntakeListView(
                entries: store.sortedEntries,
                onUndoLast: { store.undoLast() },
                onDelete: { store.removeEntry(id: $0) }
            )

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(minWidth: 360, idealWidth: 380, minHeight: 520, idealHeight: 560)
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $showSettings) {
            SettingsView(store: store)
        }
        .onAppear {
            store.ensureCurrentDay()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            store.ensureCurrentDay()
        }
    }

    private var header: some View {
        HStack {
            HStack(spacing: 6) {
                Image(systemName: "drop.fill")
                    .foregroundStyle(.cyan)
                Text("Sip")
                    .font(.title2.weight(.semibold))
            }
            Spacer()
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help("设置")
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(IntakeStore())
}
