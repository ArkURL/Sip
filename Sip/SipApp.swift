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
        // `Window` is single-instance (unlike WindowGroup, which can spawn many).
        Window("Sip", id: Self.mainWindowID) {
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
            MenuBarMenuView(store: store)
        } label: {
            menuBarLabel
        }

        Settings {
            SettingsView(store: store)
        }
    }

    static let mainWindowID = "main"

    // MARK: - Menu Bar Label

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
}

// MARK: - Menu Bar Content

private struct MenuBarMenuView: View {
    @ObservedObject var store: IntakeStore
    @Environment(\.openWindow) private var openWindow

    var body: some View {
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

        SettingsLink {
            Text("设置…")
        }

        Divider()

        Button("退出 Sip") {
            NSApplication.shared.terminate(nil)
        }
    }

    private var menuBarSummary: String {
        "\(store.totalML) / \(store.settings.dailyGoalML) ml"
    }

    private func openMainWindow() {
        NSApplication.shared.activate(ignoringOtherApps: true)

        // Prefer focusing an existing main window — never open a second one.
        if let existing = Self.findMainWindow() {
            existing.deminiaturize(nil)
            existing.makeKeyAndOrderFront(nil)
            existing.orderFrontRegardless()
            return
        }

        openWindow(id: SipApp.mainWindowID)

        DispatchQueue.main.async {
            if let window = Self.findMainWindow() {
                window.makeKeyAndOrderFront(nil)
                window.orderFrontRegardless()
            }
        }
    }

    private static func findMainWindow() -> NSWindow? {
        // Main UI is taller than the settings sheet/window (~560 vs ~420).
        NSApp.windows
            .filter { window in
                guard window.canBecomeKey else { return false }
                let name = window.className
                if name.contains("NSStatusBar") || name.contains("NSPopupMenu") || name.contains("NSMenu") {
                    return false
                }
                let size = window.frame.size
                return size.width >= 300 && size.height >= 480
            }
            .sorted { $0.frame.height > $1.frame.height }
            .first
    }
}
