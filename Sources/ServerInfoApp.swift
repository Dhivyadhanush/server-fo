import AppKit
import SwiftUI

@MainActor
enum AppState {
    /// The app delegate needs to know whether apt is mid-run when a quit is
    /// requested. There is exactly one Store for the process.
    static weak var store: Store?
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        DockIcon.apply()
        installStatusItemWhenReady(attempts: 20)

        if UserDefaults.standard.bool(forKey: ServerWidgetController.key) {
            showWidgetWhenReady(attempts: 4)
        }
    }

    private func installStatusItemWhenReady(attempts: Int) {
        if let store = AppState.store {
            StatusItemController.shared.install(store: store)
            return
        }
        guard attempts > 0 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
            self.installStatusItemWhenReady(attempts: attempts - 1)
        }
    }

    private func showWidgetWhenReady(attempts: Int) {
        if let store = AppState.store {
            ServerWidgetController.shared.show(store: store)
            return
        }
        guard attempts > 0 else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            self.showWidgetWhenReady(attempts: attempts - 1)
        }
    }

    /// Dock icon click, Launchpad, or opening the app again while it is
    /// already running. There is no main window otherwise, so this is the
    /// fallback when the menu bar icon is hidden.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        guard DockIcon.enabled else { return false }
        showDashboard()
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func showDashboard() {
        if let store = AppState.store {
            DashboardWindow.shared.show(store: store)
            return
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
            if let store = AppState.store {
                DashboardWindow.shared.show(store: store)
            }
        }
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard AppState.store?.isUpgrading == true else { return .terminateNow }
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "An apt upgrade is still running"
        alert.informativeText = "Quitting now would interrupt apt and can leave the package manager in a bad state. Let the upgrade finish first; the log is kept either way."
        alert.addButton(withTitle: "Keep running")
        alert.runModal()
        return .terminateCancel
    }
}

@main
struct ServerInfoApp: App {
    @StateObject private var store: Store
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        let store = Store()
        _store = StateObject(wrappedValue: store)

        // Headless modes exist for testing, launch agents and support. They
        // run before any UI is created and exit on their own.
        Headless.handleIfRequested()

        // Launching twice (login item plus a manual open) would show two menu
        // bar items that refresh independently. Only the first instance stays.
        if !InstanceLock.acquire() { exit(0) }

        AppearanceMode.applyCurrent()
        LoginItem.repair()
        LoginItem.configureOnFirstLaunch()

        // Do not depend on the menu bar label being instantiated: on a full
        // menu bar (or before the status item is inserted) onAppear can be
        // delayed indefinitely, leaving the app alive but idle.
        Task { @MainActor in
            store.start()
        }
    }

    var body: some Scene {
        // The status item and popover are created in AppDelegate; a SwiftUI
        // MenuBarExtra was not reliably inserting on a full menu bar.
        Settings {
            EmptyView()
        }
    }
}
