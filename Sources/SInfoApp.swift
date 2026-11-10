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
struct SInfoApp: App {
    @StateObject private var store = Store()
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    init() {
        // Headless modes exist for testing, launch agents and support. They
        // run before any UI is created and exit on their own.
        Headless.handleIfRequested()

        // Launching twice (login item plus a manual open) would show two menu
        // bar items that refresh independently. Only the first instance stays.
        if !InstanceLock.acquire() { exit(0) }

        LoginItem.repair()
    }

    var body: some Scene {
        MenuBarExtra {
            PanelView(store: store)
        } label: {
            MenuBarLabel(store: store)
        }
        .menuBarExtraStyle(.window)
    }
}
