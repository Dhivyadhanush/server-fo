import AppKit
import Carbon
import SwiftUI

/// A plain NSStatusItem instead of SwiftUI's MenuBarExtra. The status item is
/// created at launch, independent of any SwiftUI scene, and a Carbon hotkey
/// (⌃⌥⌘S) can open the same popover when the menu bar is full.
@MainActor
final class StatusItemController: NSObject, NSPopoverDelegate {
    static let shared = StatusItemController()

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?
    private var store: Store?
    private var fallbackAnchor: NSWindow?
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    private var installed = false

    func install(store: Store) {
        guard !installed else { return }
        installed = true
        self.store = store

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            if let image = AppAssets.menuBar {
                image.isTemplate = true
                button.image = image
                button.imagePosition = .imageOnly
            } else {
                button.title = "SF"
            }
            button.toolTip = "Server-Fo · click for details · ⌃⌥⌘S"
            button.target = self
            button.action = #selector(handleClick)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        statusItem = item

        let popover = NSPopover()
        popover.behavior = .transient
        popover.animates = true
        popover.delegate = self
        popover.contentSize = NSSize(width: Theme.panelWidth, height: Theme.panelHeight)

        let hosting = NSHostingController(rootView: PanelView(store: store))
        hosting.view.frame = NSRect(
            x: 0, y: 0,
            width: Theme.panelWidth,
            height: Theme.panelHeight
        )
        popover.contentViewController = hosting
        self.popover = popover

        registerHotKey()

        DistributedNotificationCenter.default().addObserver(
            forName: NSNotification.Name("dev.dhanuz.server-fo.toggle"),
            object: nil,
            queue: .main
        ) { _ in
            Task { @MainActor in
                StatusItemController.shared.togglePopover()
            }
        }
    }

    // MARK: Clicking

    @objc private func handleClick() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showContextMenu()
        } else {
            togglePopover()
        }
    }

    private func showContextMenu() {
        guard let button = statusItem?.button else { return }
        let menu = NSMenu()

        let open = NSMenuItem(title: "Open panel", action: #selector(togglePopover), keyEquivalent: "")
        open.target = self
        menu.addItem(open)

        let widget = NSMenuItem(title: "Server widget", action: #selector(toggleWidget), keyEquivalent: "")
        widget.target = self
        widget.state = ServerWidgetController.shared.isVisible ? .on : .off
        menu.addItem(widget)

        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit Server-Fo", action: #selector(quit), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)

        menu.popUp(
            positioning: nil,
            at: NSPoint(x: 0, y: button.bounds.height + 2),
            in: button
        )
    }

    @objc private func toggleWidget() {
        guard let store else { return }
        ServerWidgetController.shared.toggle(store: store)
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    // MARK: Popover

    @objc func togglePopover() {
        guard let popover else { return }
        if popover.isShown {
            popover.performClose(nil)
            return
        }

        NSApp.activate(ignoringOtherApps: true)

        if let button = statusItem?.button,
           let window = button.window,
           isOnScreen(window) {
            popover.show(
                relativeTo: button.bounds,
                of: button,
                preferredEdge: .minY
            )
        } else if let anchor = fallbackAnchorWindow(), let view = anchor.contentView {
            popover.show(
                relativeTo: view.bounds,
                of: view,
                preferredEdge: .minY
            )
        }
    }

    private func isOnScreen(_ window: NSWindow) -> Bool {
        guard window.frame.width > 0, window.frame.height > 0 else { return false }
        return NSScreen.screens.contains { $0.frame.intersects(window.frame) }
    }

    /// A 1×1 transparent window at the top-right, used as the popover anchor
    /// when macOS has moved the status item into the menu-bar overflow.
    private func fallbackAnchorWindow() -> NSWindow? {
        if let fallbackAnchor { return fallbackAnchor }
        guard let screen = NSScreen.main?.visibleFrame else { return nil }

        let window = NSWindow(
            contentRect: NSRect(x: screen.maxX - 24, y: screen.maxY - 1, width: 1, height: 1),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        window.isOpaque = false
        window.backgroundColor = .clear
        window.ignoresMouseEvents = true
        window.level = .statusBar
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.contentView = NSView(frame: NSRect(x: 0, y: 0, width: 1, height: 1))
        window.orderFrontRegardless()
        fallbackAnchor = window
        return window
    }

    func popoverDidClose(_ notification: Notification) {
        fallbackAnchor?.orderOut(nil)
        fallbackAnchor = nil
    }

    // MARK: Hotkey

    private func registerHotKey() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            statusHotKeyHandler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )

        let hotKeyID = EventHotKeyID(signature: OSType(0x53464F21), id: 1) // "SFO!"
        RegisterEventHotKey(
            UInt32(kVK_ANSI_S),
            UInt32(controlKey | optionKey | cmdKey),
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }
}

/// Carbon hotkey callbacks are C function pointers, so this cannot be a method.
private func statusHotKeyHandler(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let userData else { return noErr }
    let controller = Unmanaged<StatusItemController>
        .fromOpaque(userData)
        .takeUnretainedValue()
    Task { @MainActor in
        controller.togglePopover()
    }
    return noErr
}
