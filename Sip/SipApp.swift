//
//  SipApp.swift
//  Sip
//

import SwiftUI
import AppKit

@main
struct SipApp: App {
    @StateObject private var store = IntakeStore()
    @State private var scheduler: ReminderScheduler?
    @State private var showOnboarding = false

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
                .onAppear {
                    setupIfNeeded()
                    showOnboarding = !store.settings.hasCompletedOnboarding
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                    store.ensureCurrentDay()
                    scheduler?.reschedule()
                }
                .sheet(isPresented: $showOnboarding) {
                    OnboardingView(store: store) {
                        showOnboarding = false
                        scheduler?.reschedule()
                    }
                    .interactiveDismissDisabled()
                }
        }
        .defaultSize(width: 380, height: 560)
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        MenuBarExtra {
            menuBarContent
        } label: {
            menuBarLabel
        }

        Settings {
            SettingsView(store: store)
        }
    }

    // MARK: - Menu Bar

    @ViewBuilder
    private var menuBarLabel: some View {
        HStack(spacing: 4) {
            Image(systemName: store.isGoalReached ? "checkmark.circle.fill" : "drop.fill")
            Text(menuBarText)
                .monospacedDigit()
        }
    }

    private var menuBarText: String {
        if store.isGoalReached {
            return "完成"
        }
        return "\(store.progressPercent)%"
    }

    @ViewBuilder
    private var menuBarContent: some View {
        Text(menuBarSummary)
            .font(.headline)

        Divider()

        Button("记录 +250 ml") {
            store.addIntake(amountML: 250)
        }

        Button("记录 +100 ml") {
            store.addIntake(amountML: 100)
        }

        if !store.entries.isEmpty {
            Button("撤销最近一次") {
                store.undoLast()
            }
        }

        Divider()

        Button("打开 Sip") {
            openMainWindow()
        }

        Button("设置…") {
            openSettings()
        }

        Divider()

        Button("退出 Sip") {
            NSApplication.shared.terminate(nil)
        }
    }

    private var menuBarSummary: String {
        "\(store.totalML) / \(store.settings.dailyGoalML) ml"
    }

    // MARK: - Lifecycle

    private func setupIfNeeded() {
        if scheduler == nil {
            let s = ReminderScheduler(store: store)
            scheduler = s
            store.onStateChanged = { [weak s] in
                s?.reschedule()
            }
            s.reschedule()
        }
        store.ensureCurrentDay()
    }

    private func openMainWindow() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        if let window = NSApplication.shared.windows.first(where: { $0.canBecomeMain }) {
            window.makeKeyAndOrderFront(nil)
        } else {
            // Fallback: open via URL-less show — trigger first WindowGroup
            for window in NSApplication.shared.windows {
                window.makeKeyAndOrderFront(nil)
            }
        }
    }

    private func openSettings() {
        NSApplication.shared.activate(ignoringOtherApps: true)
        if #available(macOS 14.0, *) {
            NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
        } else {
            NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
        }
    }
}
