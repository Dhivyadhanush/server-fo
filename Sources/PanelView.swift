import AppKit
import SwiftUI

// MARK: - Assets

enum AppAssets {
    static let menuBar: NSImage? = {
        let bundle = Bundle.main
        guard let url = bundle.url(forResource: "MenuBarIcon", withExtension: "png"),
              let data = try? Data(contentsOf: url),
              let rep = NSBitmapImageRep(data: data) else { return nil }

        let image = NSImage(size: NSSize(width: 18, height: 18))
        rep.size = NSSize(width: 18, height: 18)
        image.addRepresentation(rep)

        if let twoX = bundle.url(forResource: "MenuBarIcon@2x", withExtension: "png"),
           let data = try? Data(contentsOf: twoX),
           let retina = NSBitmapImageRep(data: data) {
            retina.size = NSSize(width: 18, height: 18)
            image.addRepresentation(retina)
        }
        image.isTemplate = true
        return image
    }()

    static let appIcon: NSImage? = {
        if let url = Bundle.main.url(forResource: "AppIcon", withExtension: "icns"),
           let image = NSImage(contentsOf: url) {
            return image
        }
        return NSApp.applicationIconImage
    }()
}

// MARK: - Panel

struct PanelView: View {
    @ObservedObject var store: Store
    var initialTab: Store.Tab

    @State private var tab: Store.Tab
    @State private var showSettings = false

    init(store: Store, initialTab: Store.Tab = .containers) {
        self.store = store
        self.initialTab = initialTab
        _tab = State(initialValue: initialTab)
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            tabBar
            Divider().opacity(0.4)
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            Divider().opacity(0.4)
            footer
        }
        .frame(
            width: Theme.panelWidth,
            height: min(Theme.panelHeight, (NSScreen.main?.visibleFrame.height ?? 700) - 40)
        )
        .onAppear { store.start() }
        .sheet(isPresented: $showSettings) {
            SettingsView(store: store)
        }
    }

    private var header: some View {
        HStack(spacing: 10) {
            if let icon = AppAssets.appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 30, height: 30)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            } else {
                Image(systemName: "server.rack")
                    .font(.system(size: 22))
            }

            VStack(alignment: .leading, spacing: 2) {
                Text("S-Info")
                    .font(.system(size: 15, weight: .bold))
                HStack(spacing: 5) {
                    if let probe = store.probe {
                        Text(probe.hostname.isEmpty ? "server" : probe.hostname)
                        Text("·")
                        Text(shortOS(probe.os))
                    } else {
                        Text("Server details")
                    }
                }
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            }

            Spacer(minLength: 4)

            statusPill

            Button {
                store.refresh()
            } label: {
                if store.isRefreshing {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "arrow.clockwise").font(.system(size: 11, weight: .semibold))
                }
            }
            .buttonStyle(.borderless)
            .disabled(store.isRefreshing)
            .help("Refresh now")

            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape").font(.system(size: 12))
            }
            .buttonStyle(.borderless)
            .help("Settings")

            Button {
                NSApp.terminate(nil)
            } label: {
                Image(systemName: "power").font(.system(size: 11, weight: .medium))
            }
            .buttonStyle(.borderless)
            .help("Quit S-Info")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var statusPill: some View {
        switch store.connection {
        case .online:
            Pill(text: "Online", color: Theme.green, icon: "checkmark.circle.fill")
        case .connecting:
            Pill(text: "Connecting", color: Theme.blue, icon: "ellipsis")
        case .unreachable:
            Pill(text: "Offline", color: Theme.red, icon: "exclamationmark.triangle.fill")
        case .idle:
            Pill(text: "Idle", color: Theme.gray, icon: nil)
        }
    }

    private var tabBar: some View {
        HStack(spacing: 2) {
            ForEach(Store.Tab.allCases) { item in
                Button {
                    tab = item
                } label: {
                    HStack(spacing: 4) {
                        Text(item.rawValue)
                            .font(.system(size: 11, weight: tab == item ? .semibold : .regular))
                        if item == .updates, let count = store.probe?.aptUpgradable.count, count > 0 {
                            Text("\(count)")
                                .font(.system(size: 8.5, weight: .bold, design: .rounded))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(Theme.amber.opacity(0.22)))
                                .foregroundStyle(Theme.amber)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(tab == item ? .primary : .secondary)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(tab == item ? Color.primary.opacity(0.09) : .clear)
                )
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.045))
        )
        .padding(.horizontal, 14)
        .padding(.bottom, 10)
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .containers:
            ContainersView(store: store)
        case .history:
            HistoryView(store: store)
        case .updates:
            UpdatesView(store: store)
        }
    }

    private var footer: some View {
        HStack(spacing: 6) {
            if case .unreachable = store.connection, let error = store.lastError {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(Theme.red)
                Text(error)
                    .lineLimit(1)
                    .truncationMode(.tail)
            } else {
                Text("Updated \(Fmt.relative(store.lastUpdated))")
            }
            Spacer(minLength: 8)
            if let probe = store.probe {
                Text("\(probe.running) running")
                if probe.stopped > 0 { Text("· \(probe.stopped) stopped") }
                if probe.unhealthy > 0 { Text("· \(probe.unhealthy) unhealthy") }
            }
            Text("· 30-day history")
        }
        .font(.system(size: 9))
        .foregroundStyle(.tertiary)
        .padding(.horizontal, 14)
        .padding(.vertical, 7)
    }

    private func shortOS(_ value: String) -> String {
        value
            .replacingOccurrences(of: "GNU/Linux", with: "")
            .replacingOccurrences(of: " LTS", with: "")
            .trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Menu bar label

struct MenuBarLabel: View {
    @ObservedObject var store: Store

    var body: some View {
        HStack(spacing: 2) {
            if let icon = AppAssets.menuBar {
                Image(nsImage: icon)
                    .renderingMode(.template)
                    .frame(width: 18, height: 18)
            } else {
                Image(systemName: "server.rack")
            }
            if let count = badge {
                Text("\(count)")
                    .font(.system(size: 9, weight: .semibold, design: .rounded))
            }
        }
        .overlay(alignment: .bottomTrailing) {
            if let color = statusColor {
                Circle()
                    .fill(color)
                    .frame(width: 4, height: 4)
                    .offset(x: 1, y: 1)
            }
        }
        // The label is installed at launch and stays alive for the whole
        // session, so this is what starts background sampling and the 30-day
        // upgrade timer even when the panel has never been opened.
        .onAppear { store.start() }
        .help(helpText)
    }

    private var helpText: String {
        let target = SSHConfig.current().label
        guard let probe = store.probe else { return "S-Info · \(target)" }
        return "S-Info · \(probe.hostname) · \(probe.running) running, \(probe.stopped) stopped · \(probe.aptUpgradable.count) updates"
    }

    private var badge: Int? {
        guard UserDefaults.standard.bool(forKey: "sinfo.barBadge") else { return nil }
        guard let probe = store.probe else { return nil }
        let attention = probe.unhealthy + probe.stopped
        return attention > 0 ? attention : nil
    }

    private var statusColor: Color? {
        switch store.connection {
        case .online:
            guard let probe = store.probe else { return Theme.green }
            if probe.unhealthy > 0 { return Theme.red }
            if probe.stopped > 0 { return Theme.amber }
            return nil
        case .unreachable:
            return Theme.red
        case .connecting:
            return Theme.blue
        case .idle:
            return nil
        }
    }
}
