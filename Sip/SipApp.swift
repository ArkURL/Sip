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
                .background(MainWindowIdentifierBinder())
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
                        session.scheduler.reschedule(force: true)
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
            return String(localized: "Done")
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
    /// Coalesces rapid settings edits (goal slider) into one force reschedule.
    private var settingsRescheduleWork: DispatchWorkItem?
    private static let settingsDebounce: TimeInterval = 0.35

    init() {
        let store = IntakeStore()
        self.store = store
        self.scheduler = ReminderScheduler(store: store)
        wire()
    }

    init(store: IntakeStore) {
        self.store = store
        self.scheduler = ReminderScheduler(store: store)
        wire()
    }

    private func wire() {
        store.onStateChanged = { [weak self] kind in
            self?.handleStoreChange(kind)
        }
        // Forward store + scheduler updates so MenuBarExtra / main UI re-render.
        storeObservation = store.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
        schedulerObservation = scheduler.objectWillChange.sink { [weak self] _ in
            self?.objectWillChange.send()
        }
    }

    private func handleStoreChange(_ kind: IntakeStore.ChangeKind) {
        switch kind {
        case .force:
            settingsRescheduleWork?.cancel()
            settingsRescheduleWork = nil
            scheduler.reschedule(force: true)
        case .soft:
            // Do not cancel a pending settings debounce — slider may still be moving.
            scheduler.reschedule(force: false)
        case .settings:
            settingsRescheduleWork?.cancel()
            let work = DispatchWorkItem { [weak self] in
                self?.scheduler.reschedule(force: true)
                self?.settingsRescheduleWork = nil
            }
            settingsRescheduleWork = work
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.settingsDebounce, execute: work)
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
        // Day roll triggers onStateChanged → force reschedule. Same-day ticks
        // (become active / open window / wake) only soft-refresh so the next
        // reminder is not pushed later just because the UI appeared.
        store.ensureCurrentDay()
        scheduler.reschedule(force: false)
    }
}

// MARK: - Dock / activation policy

/// Menu-bar-first behavior: stay in Dock only while a user-facing window is open.
/// Closing the last window switches to `.accessory` so the Dock slot is freed;
/// the MenuBarExtra keeps the process alive.
@MainActor
enum DockPolicy {
    static func showInDock() {
        if NSApp.activationPolicy() != .regular {
            NSApp.setActivationPolicy(.regular)
        }
        // Permission alerts and Settings deep-links need a key app; accessory → regular
        // alone is not always enough when the user only opened a sheet/menu.
        if !NSApp.isActive {
            NSApp.activate(ignoringOtherApps: true)
        }
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

// MARK: - Main window presentation

@MainActor
enum MainWindowPresenter {
    static let windowID = SipApp.mainWindowID

    /// Focus an existing main window, or ask SwiftUI to open one.
    /// - Parameter openWindow: Optional SwiftUI action; when nil, posts `.sipOpenMainWindow`
    ///   so a scene that holds `@Environment(\.openWindow)` can complete the open.
    static func present(openWindow: OpenWindowAction? = nil) {
        DockPolicy.showInDock()
        NSApplication.shared.activate(ignoringOtherApps: true)

        if let existing = findMainWindow() {
            existing.deminiaturize(nil)
            existing.makeKeyAndOrderFront(nil)
            existing.orderFrontRegardless()
            return
        }

        if let openWindow {
            openWindow(id: windowID)
            DispatchQueue.main.async {
                if let window = findMainWindow() {
                    window.makeKeyAndOrderFront(nil)
                    window.orderFrontRegardless()
                }
            }
        } else {
            NotificationCenter.default.post(name: .sipOpenMainWindow, object: nil)
        }
    }

    static func findMainWindow() -> NSWindow? {
        let id = NSUserInterfaceItemIdentifier(windowID)
        // Prefer explicit identifier set by `MainWindowIdentifierBinder`.
        if let tagged = NSApp.windows.first(where: { $0.identifier == id && $0.canBecomeKey }) {
            return tagged
        }
        // Fallback geometry (main ~560 tall vs settings ~420–520) for first frame before tag applies.
        return NSApp.windows
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

/// Tags the hosting `NSWindow` so menu-bar / notification open paths do not rely on height heuristics.
private struct MainWindowIdentifierBinder: NSViewRepresentable {
    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            view.window?.identifier = NSUserInterfaceItemIdentifier(SipApp.mainWindowID)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        nsView.window?.identifier = NSUserInterfaceItemIdentifier(SipApp.mainWindowID)
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
            // Default / banner click → bring the main UI forward for logging a sip.
            if response.actionIdentifier == UNNotificationDefaultActionIdentifier {
                MainWindowPresenter.present()
            }
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

        Button(String(localized: "Log +250 ml")) {
            store.addIntake(amountML: 250)
        }

        Button(String(localized: "Log +100 ml")) {
            store.addIntake(amountML: 100)
        }

        if !store.entries.isEmpty {
            Button(String(localized: "Undo last")) {
                store.undoLast()
            }
        }

        Divider()

        Button(String(localized: "Open Sip")) {
            MainWindowPresenter.present(openWindow: openWindow)
        }

        SettingsLink {
            Text("Settings…")
        }

        Divider()

        Button(String(localized: "Quit Sip")) {
            NSApplication.shared.terminate(nil)
        }
        .onReceive(NotificationCenter.default.publisher(for: .sipOpenMainWindow)) { _ in
            MainWindowPresenter.present(openWindow: openWindow)
        }
    }

    private var menuBarSummary: String {
        "\(store.totalML) / \(store.settings.dailyGoalML) ml"
    }
}

extension Notification.Name {
    /// Ask a scene that holds `openWindow` to present the main Sip window.
    static let sipOpenMainWindow = Notification.Name("sip.openMainWindow")
}
