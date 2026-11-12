import AppKit
import SwiftUI

/// The app normally lives in the menu bar. On a full menu bar that icon can be
/// hidden, leaving no way to open the panel, so a regular Dock icon and a
/// dashboard window provide a second entry point.
enum DockIcon {
    static let key = "serverfo.showDockIcon"

    static var enabled: Bool {
        UserDefaults.standard.object(forKey: key) as? Bool ?? true
    }

    static func apply() {
        NSApplication.shared.setActivationPolicy(enabled ? .regular : .accessory)
    }
}

@MainActor
final class DashboardWindow: NSObject, NSWindowDelegate {
    static let shared = DashboardWindow()

    private var window: NSWindow?

    func show(store: Store) {
        if window == nil {
            let hosting = NSHostingView(rootView: PanelView(store: store))
            hosting.frame = NSRect(
                x: 0, y: 0,
                width: Theme.panelWidth,
                height: Theme.panelHeight
            )

            let window = NSWindow(
                contentRect: hosting.frame,
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            window.title = "Server-Fo"
            window.isReleasedWhenClosed = false
            window.contentView = hosting
            window.delegate = self
            window.center()
            self.window = window
        }

        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        window = nil
    }
}
