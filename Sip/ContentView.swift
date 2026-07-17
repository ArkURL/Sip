//
//  ContentView.swift
//  Sip
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var store: IntakeStore
    @EnvironmentObject private var scheduler: ReminderScheduler
    @EnvironmentObject private var notificationPermission: NotificationPermissionModel
    @State private var showSettings = false

    /// Fixed window content size — avoids reflow/clip when the list goes from empty → entries.
    private static let contentWidth: CGFloat = 380
    private static let contentHeight: CGFloat = 560

    var body: some View {
        VStack(spacing: 14) {
            ProgressRingView(
                progress: store.progress,
                totalML: store.totalML,
                goalML: store.settings.dailyGoalML,
                isGoalReached: store.isGoalReached,
                statusText: store.statusText,
                nextReminderText: scheduler.nextReminderSummary
            )

            QuickAddBar(amounts: AppSettings.quickAmounts) { amount in
                store.addIntake(amountML: amount)
            }

            IntakeListView(
                entries: store.sortedEntries,
                onUndoLast: { store.undoLast() },
                onDelete: { store.removeEntry(id: $0) }
            )
        }
        .padding(.horizontal, 20)
        .padding(.top, 12)
        .padding(.bottom, 16)
        // Hard size so Window(contentSize) does not jump when children change height.
        .frame(width: Self.contentWidth, height: Self.contentHeight, alignment: .top)
        .background(Color(nsColor: .windowBackgroundColor))
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showSettings = true
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
                .help("Settings")
            }
        }
        .sheet(isPresented: $showSettings) {
            SettingsView(
                store: store,
                notificationPermission: notificationPermission,
                showsDismissButton: true
            )
        }
        .onAppear {
            // Soft only — opening the main window must not delay an already-scheduled reminder.
            store.ensureCurrentDay()
            scheduler.reschedule(force: false)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            store.ensureCurrentDay()
            scheduler.reschedule(force: false)
        }
    }
}

#Preview {
    let store = IntakeStore()
    let scheduler = ReminderScheduler(store: store)
    scheduler.reschedule()
    return ContentView()
        .environmentObject(store)
        .environmentObject(scheduler)
}
