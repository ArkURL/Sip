//
//  SipApp.swift
//  Sip
//

import SwiftUI
import AppKit
import Combine
import UserNotifications

@main
struct SipApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var session = AppSession()
    @State private var showOnboarding = false

    private var store: IntakeStore { session.store }

    var body: some Scene {
        // `Window` is single-instance (unlike WindowGroup, which can spawn many).
        Window("Sip", id: Self.mainWindowID) {
            ContentView()
                .environmentObject(store)
                .environmentObject(session.scheduler)
                .onAppear {
                    session.startIfNeeded()
                    showOnboarding = !store.settings.hasCompletedOnboarding
                    // Main window visible → show Dock icon while UI is open.
                    DockPolicy.showInDock()
                }
                .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                    session.refreshDayAndReminders()
                }
                .sheet(isPresented: $showOnboarding) {
                    OnboardingView(store: store) {
                        showOnboarding = false
                        session.scheduler.reschedule()
                    }
                    .interactiveDismissDisabled()
                }
        }
        .defaultSize(width: 380, height: 560)
        // Content view uses a fixed frame; contentSize keeps the chrome stable when list updates.
        .windowResizability(.contentSize)
        .commands {
            CommandGroup(replacing: .newItem) {}
        }

        MenuBarExtra {
            MenuBarMenuView(store: store)
        } label: {
            menuBarLabel
                // Menu bar stays up after the main window closes — ensure lifecycle starts here too.
                .onAppear { session.startIfNeeded() }
        }

        Settings {
            SettingsView(store: store)
                .onAppear {
                    // Settings is also a real window; keep Dock while it is open.
                    DockPolicy.showInDock()
                }
        }
    }

    static let mainWindowID = "main"

    // MARK: - Menu Bar Label

    @ViewBuilder
    private var menuBarLabel: some View {
        // Plain HStack — MenuBarExtra reliably renders SF Symbols this way
        // (Text+Image concatenation can drop the icon in the status item).
        HStack(spacing: 4) {
            Image(systemName: store.isGoalReached ? "checkmark.circle.fill" : "drop.fill")
            Text(menuBarText)
                .monospacedDigit()
                // Nudge digits down a bit so they sit closer to the icon center.
                .offset(y: 1)
        }
    }

    private var menuBarText: String {
        if store.isGoalReached {
            return "完成"
        }
        return "\(store.progressPercent)%"
    }
}

// MARK: - App session (store + reminders + day rollover)

/// Owns long-lived services so menu-bar-only mode still rolls the day and reschedules.
@MainActor
final class AppSession: ObservableObject {
    let store: IntakeStore
    let scheduler: ReminderScheduler
    private var dayMonitor: DayLifecycleMonitor?
    private var storeObservation: AnyCancellable?
    private var schedulerObservation: AnyCancellable?
    private var didStart = false

    init() {
        let store = IntakeStore()
        self.store = store
        let scheduler = ReminderScheduler(store: store)
        self.scheduler = scheduler
        store.onStateChanged = { [weak scheduler] in
            scheduler?.reschedule()
        }
        // Forward store + scheduler updates so MenuBarExtra / main UI re-render.
        storeObservation = store.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        schedulerObservation = scheduler.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    init(store: IntakeStore) {
        self.store = store
        let scheduler = ReminderScheduler(store: store)
        self.scheduler = scheduler
        store.onStateChanged = { [weak scheduler] in
            scheduler?.reschedule()
        }
        storeObservation = store.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        schedulerObservation = scheduler.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    func startIfNeeded() {
        guard !didStart else {
            refreshDayAndReminders()
            return
        }
        didStart = true

        dayMonitor = DayLifecycleMonitor { [weak self] in
            self?.refreshDayAndReminders()
        }

        refreshDayAndReminders()
    }

    func refreshDayAndReminders() {
        store.ensureCurrentDay()
        scheduler.reschedule()
    }
}

// MARK: - Dock / activation policy

/// Menu-bar-first behavior: stay in Dock only while a user-facing window is open.
/// Closing the last window switches to `.accessory` so the Dock slot is freed;
/// the MenuBarExtra keeps the process alive.
@MainActor
enum DockPolicy {
    static func showInDock() {
        guard NSApp.activationPolicy() != .regular else { return }
        NSApp.setActivationPolicy(.regular)
    }

    /// - Parameter excluding: window currently closing (still listed in `NSApp.windows`).
    static func hideFromDockIfNoWindows(excluding closing: NSWindow? = nil) {
        // Defer one run-loop turn so AppKit finishes tearing down the closed window.
        DispatchQueue.main.async {
            if hasUserFacingWindow(excluding: closing) {
                showInDock()
            } else {
                guard NSApp.activationPolicy() != .accessory else { return }
                NSApp.setActivationPolicy(.accessory)
            }
        }
    }

    static func hasUserFacingWindow(excluding closing: NSWindow? = nil) -> Bool {
        NSApp.windows.contains { window in
            if let closing, window === closing { return false }
            return isUserFacingWindow(window)
        }
    }

    static func isUserFacingWindow(_ window: NSWindow) -> Bool {
        // Miniaturized windows still count — user restores them from the Dock tile.
        guard window.isVisible || window.isMiniaturized else { return false }
        guard window.canBecomeKey else { return false }
        let name = window.className
        if name.contains("NSStatusBar")
            || name.contains("NSPopupMenu")
            || name.contains("NSMenu")
            || name.contains("NSStatusItem") {
            return false
        }
        // Tiny transient panels (tooltips, etc.) should not pin the Dock icon.
        let size = window.frame.size
        return size.width >= 200 && size.height >= 120
    }
}

// MARK: - AppDelegate

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        UNUserNotificationCenter.current().delegate = self

        // Do not quit when the last window closes — MenuBarExtra is the persistent UI.
        // Dock icon is managed by DockPolicy based on open windows.
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,
            queue: .main
        ) { notification in
            let closing = notification.object as? NSWindow
            Task { @MainActor in
                DockPolicy.hideFromDockIfNoWindows(excluding: closing)
            }
        }
        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification,
            object: nil,
            queue: .main
        ) { notification in
            guard let window = notification.object as? NSWindow else { return }
            Task { @MainActor in
                guard DockPolicy.isUserFacingWindow(window) else { return }
                DockPolicy.showInDock()
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    // MARK: UNUserNotificationCenterDelegate

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        Task { @MainActor in
            NotificationCenter.default.post(name: .sipDayRefreshNeeded, object: nil)
        }
        completionHandler([.banner, .sound, .list])
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor in
            NotificationCenter.default.post(name: .sipDayRefreshNeeded, object: nil)
        }
        completionHandler()
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
        // Accessory → regular must happen before activate/show, or the window may not front.
        DockPolicy.showInDock()
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
