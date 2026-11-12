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
    @Namespace private var tabNamespace

    @AppStorage("serverfo.showHistoryTab") private var showHistoryTab = true
    @AppStorage("serverfo.showUpdatesTab") private var showUpdatesTab = true
    @AppStorage("serverfo.showStatusPill") private var showStatusPill = true
    @AppStorage("serverfo.showHost") private var showHost = true
    @AppStorage("serverfo.showFooter") private var showFooter = true

    init(store: Store, initialTab: Store.Tab = .containers) {
        self.store = store
        self.initialTab = initialTab
        _tab = State(initialValue: initialTab)
    }

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                header
                if visibleTabs.count > 1 { tabBar }
                content
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                if showFooter {
                    Divider().opacity(0.25)
                    footer
                }
            }
        }
        .frame(
            width: Theme.panelWidth,
            height: min(Theme.panelHeight, (NSScreen.main?.visibleFrame.height ?? 700) - 40)
        )
        .onAppear {
            store.start()
            if !visibleTabs.contains(tab) { tab = .containers }
        }
        .onChange(of: showHistoryTab) { _, _ in repairTab() }
        .onChange(of: showUpdatesTab) { _, _ in repairTab() }
        .sheet(isPresented: $showSettings) {
            SettingsView(store: store)
        }
    }

    private var visibleTabs: [Store.Tab] {
        var result: [Store.Tab] = [.containers]
        if showHistoryTab { result.append(.history) }
        if showUpdatesTab { result.append(.updates) }
        return result
    }

    private func repairTab() {
        if !visibleTabs.contains(tab) { tab = .containers }
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 11) {
            iconBadge

            VStack(alignment: .leading, spacing: 2) {
                Text("Server-Fo")
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .tracking(-0.2)

                if showHost {
                    HStack(spacing: 5) {
                        Circle()
                            .fill(store.connection.isOnline ? Theme.green : Theme.gray.opacity(0.5))
                            .frame(width: 4, height: 4)
                        Text(hostLine)
                            .font(.system(size: 10))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }

            Spacer(minLength: 4)

            if showStatusPill { statusPill }

            GlassIconButton(
                icon: "network",
                help: store.tailscaleEnabled
                    ? "Tailscale via \(store.tailscalePiIP ?? SSHConfig.current().jumpHost) · click for direct LAN"
                    : "Route through Tailscale (Pi \(SSHConfig.current().jumpHost))",
                active: store.tailscaleEnabled
            ) {
                store.setTailscale(!store.tailscaleEnabled)
            }

            GlassIconButton(
                icon: "arrow.clockwise",
                help: "Refresh now",
                spinning: store.isRefreshing
            ) {
                store.refresh()
            }
            .disabled(store.isRefreshing)

            GlassIconButton(icon: "slider.horizontal.3", help: "Settings") {
                showSettings = true
            }

            GlassIconButton(icon: "power", help: "Quit Server-Fo") {
                NSApp.terminate(nil)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 13)
        .padding(.bottom, 11)
    }

    private var iconBadge: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Theme.accent.opacity(0.18))
                .blur(radius: 7)
                .frame(width: 36, height: 36)

            if let icon = AppAssets.appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 34, height: 34)
                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(.white.opacity(0.14), lineWidth: 0.8)
                    )
            } else {
                Image(systemName: "server.rack")
                    .font(.system(size: 22))
                    .foregroundStyle(Theme.accentText)
            }
        }
        .frame(width: 34, height: 34)
    }

    private var hostLine: String {
        guard let probe = store.probe else { return "Connecting to \(SSHConfig.current().label)" }
        let os = shortOS(probe.os)
        return os.isEmpty ? probe.hostname : "\(probe.hostname) · \(os)"
    }

    @ViewBuilder
    private var statusPill: some View {
        switch store.connection {
        case .online:
            Pill(text: "Online", color: Theme.green, icon: "checkmark.circle.fill", glass: true)
        case .connecting:
            Pill(text: "Linking", color: Theme.accentDeep, icon: "ellipsis", glass: true)
        case .unreachable:
            Pill(text: "Offline", color: Theme.red, icon: "exclamationmark.triangle.fill", glass: true)
        case .idle:
            Pill(text: "Idle", color: Theme.gray, icon: nil, glass: true)
        }
    }

    // MARK: Tabs

    private var tabBar: some View {
        HStack(spacing: 3) {
            ForEach(visibleTabs) { item in
                Button {
                    withAnimation(.spring(response: 0.28, dampingFraction: 0.82)) {
                        tab = item
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: item.icon)
                            .font(.system(size: 9, weight: .semibold))
                        Text(item.rawValue)
                            .font(.system(size: 10.5, weight: .semibold))
                        if item == .updates, let count = store.probe?.aptUpgradable.count, count > 0 {
                            Text("\(count)")
                                .font(.system(size: 8, weight: .bold, design: .rounded))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 1)
                                .background(Capsule().fill(Color.black.opacity(tab == item ? 0.18 : 0.35)))
                                .foregroundStyle(tab == item ? Color.black.opacity(0.75) : Theme.amber)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 5.5)
                    .contentShape(Rectangle())
                    .foregroundStyle(tab == item ? Color.black.opacity(0.86) : Color.secondary)
                    .background {
                        if tab == item {
                            RoundedRectangle(cornerRadius: 7, style: .continuous)
                                .fill(Theme.accentGradient)
                                .shadow(color: Theme.accent.opacity(0.35), radius: 6, y: 2)
                                .matchedGeometryEffect(id: "tab", in: tabNamespace)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Theme.surfaceSunken)
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Theme.stroke, lineWidth: 0.8)
                )
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

    // MARK: Footer

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
                Circle()
                    .fill(Theme.accent.opacity(0.7))
                    .frame(width: 4, height: 4)
                Text("Updated \(Fmt.relative(store.lastUpdated))")
            }
            Spacer(minLength: 8)
            if store.tailscaleEnabled {
                Text("via Tailscale")
                    .foregroundStyle(Theme.accentText)
                    .help("Via Tailscale \(store.tailscalePiIP ?? SSHConfig.current().jumpHost)")
                Text("·")
            }
            if let probe = store.probe {
                Text("\(probe.running) running")
                if probe.stopped > 0 { Text("· \(probe.stopped) stopped") }
                if probe.unhealthy > 0 { Text("· \(probe.unhealthy) unhealthy") }
            }
            Text("· 30-day history")
        }
        .font(.system(size: 9, design: .monospaced))
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

extension Store.Tab {
    var icon: String {
        switch self {
        case .containers: return "square.stack.3d.up.fill"
        case .history: return "chart.xyaxis.line"
        case .updates: return "bolt.badge.clock.fill"
        }
    }
}

// MARK: - Menu bar label

struct MenuBarLabel: View {
    @ObservedObject var store: Store
    @AppStorage("serverfo.showMenuDot") private var showDot = true

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
            if showDot, let color = statusColor {
                Circle()
                    .fill(color)
                    .frame(width: 4, height: 4)
                    .offset(x: 1, y: 1)
            }
        }
        // The label is installed at launch and stays alive for the whole
        // session, so this is what starts background sampling and the 30-day
        // upgrade timer even when the panel has never been opened.
        .onAppear {
            store.start()
            AppearanceMode.applyCurrent()
        }
        .help(helpText)
    }

    private var helpText: String {
        let target = SSHConfig.current().label
        guard let probe = store.probe else { return "Server-Fo · \(target)" }
        return "Server-Fo · \(probe.hostname) · \(probe.running) running, \(probe.stopped) stopped · \(probe.aptUpgradable.count) updates"
    }

    private var badge: Int? {
        guard UserDefaults.standard.bool(forKey: "serverfo.barBadge") else { return nil }
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
