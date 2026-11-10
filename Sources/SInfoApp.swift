import AppKit
import SwiftUI

@main
struct SInfoApp: App {
    @StateObject private var store = Store()

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
