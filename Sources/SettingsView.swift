import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: Store
    @Environment(\.dismiss) private var dismiss

    @AppStorage("serverfo.ssh.host") private var host = "192.168.1.22"
    @AppStorage("serverfo.ssh.user") private var user = "server1"
    @AppStorage("serverfo.ssh.port") private var port = 22
    @AppStorage("serverfo.ssh.identity") private var identity = ""
    @AppStorage("serverfo.tailscale.host") private var tailscaleHost = "100.117.187.32"
    @AppStorage("serverfo.tailscale.user") private var tailscaleUser = "pi"
    @AppStorage("serverfo.refresh") private var refresh = 30
    @AppStorage("serverfo.sample") private var sample = 5
    @AppStorage("serverfo.autoUpgrade") private var autoUpgrade = true
    @AppStorage("serverfo.checkUpdates") private var checkUpdates = true
    @AppStorage("serverfo.barBadge") private var barBadge = false
    @AppStorage("serverfo.appearance") private var appearance = "system"
    @AppStorage("serverfo.showDockIcon") private var showDockIcon = false
    @ObservedObject private var widget = ServerWidgetController.shared

    @AppStorage("serverfo.showHistoryTab") private var showHistoryTab = true
    @AppStorage("serverfo.showUpdatesTab") private var showUpdatesTab = true
    @AppStorage("serverfo.showStatusPill") private var showStatusPill = true
    @AppStorage("serverfo.showHost") private var showHost = true
    @AppStorage("serverfo.showFooter") private var showFooter = true
    @AppStorage("serverfo.showMenuDot") private var showMenuDot = true
    @AppStorage("serverfo.showRowImage") private var showRowImage = true
    @AppStorage("serverfo.showRowUptime") private var showRowUptime = true
    @AppStorage("serverfo.showRowPorts") private var showRowPorts = true
    @AppStorage("serverfo.showRowHealth") private var showRowHealth = true
    @AppStorage("serverfo.showRowRestarts") private var showRowRestarts = true
    @AppStorage("serverfo.showRowCPU") private var showRowCPU = true
    @AppStorage("serverfo.showRowMemory") private var showRowMemory = true
    @AppStorage("serverfo.showRowStackCounts") private var showRowStackCounts = true
    @AppStorage("serverfo.showDetailMetrics") private var showDetailMetrics = true
    @AppStorage("serverfo.showDetailCharts") private var showDetailCharts = true
    @AppStorage("serverfo.showDetailInspect") private var showDetailInspect = true
    @AppStorage("serverfo.showHistoryEvents") private var showHistoryEvents = true
    @AppStorage("serverfo.showPendingPackages") private var showPendingPackages = true
    @AppStorage("serverfo.showActivityLog") private var showActivityLog = true
    @AppStorage("serverfo.showCacheAction") private var showCacheAction = true

    @State private var loginItem = LoginItem.enabled
    @State private var testing = false
    @State private var testResult: String?
    @State private var testOK = false
    @State private var pruneMessage: String?
    @State private var detectingPi = false
    @State private var piMessage: String?

    var body: some View {
        ZStack {
            AppBackground()

            VStack(spacing: 0) {
                header
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 11) {
                        appearanceCard
                        connectionCard
                        visibilityCard
                        refreshCard
                        historyCard
                        maintenanceCard
                        generalCard
                        aboutCard
                    }
                    .padding(14)
                }
            }
        }
        .frame(width: 470, height: 620)
        .onChange(of: appearance) { _, value in AppearanceMode.apply(value) }
        .onDisappear { store.applySettings() }
    }

    private var header: some View {
        HStack(spacing: 10) {
            if let icon = AppAssets.appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 28, height: 28)
                    .clipShape(RoundedRectangle(cornerRadius: 7, style: .continuous))
            }
            VStack(alignment: .leading, spacing: 1) {
                Text("Settings")
                    .font(.system(size: 15, weight: .heavy, design: .rounded))
                Text("Server-Fo · \(SSHConfig.current().label)")
                    .font(.system(size: 9.5))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button("Done") {
                store.applySettings()
                dismiss()
            }
            .keyboardShortcut(.defaultAction)
            .buttonStyle(.borderedProminent)
            .tint(Theme.accentText)
            .controlSize(.small)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    // MARK: Appearance & visibility

    private var appearanceCard: some View {
        settingsCard(title: "Appearance", icon: "paintpalette.fill") {
            HStack {
                Text("Theme")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("", selection: $appearance) {
                    ForEach(AppearanceMode.allCases) { mode in
                        Text(mode.label).tag(mode.rawValue)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .frame(width: 190)
            }
            Text("System follows macOS. The palette, charts and glows adapt to light and dark.")
                .font(.system(size: 8.5))
                .foregroundStyle(.tertiary)
        }
    }

    private var visibilityCard: some View {
        settingsCard(title: "What is visible", icon: "eye.fill") {
            subLabel("Panel")
            chipGrid([
                ("Status pill", $showStatusPill),
                ("Hostname", $showHost),
                ("Footer", $showFooter),
                ("Menu bar dot", $showMenuDot),
                ("Menu bar count", $barBadge),
            ])

            subLabel("Tabs")
            chipGrid([
                ("History", $showHistoryTab),
                ("Updates", $showUpdatesTab),
            ])

            subLabel("Container rows")
            chipGrid([
                ("Image", $showRowImage),
                ("Uptime", $showRowUptime),
                ("Ports", $showRowPorts),
                ("Health", $showRowHealth),
                ("Restarts", $showRowRestarts),
                ("CPU", $showRowCPU),
                ("Memory", $showRowMemory),
                ("Stack counts", $showRowStackCounts),
            ])

            subLabel("Detail, history and updates")
            chipGrid([
                ("Metrics", $showDetailMetrics),
                ("Charts", $showDetailCharts),
                ("Mounts & logs", $showDetailInspect),
                ("State events", $showHistoryEvents),
                ("Pending packages", $showPendingPackages),
                ("Activity log", $showActivityLog),
                ("RAM cache action", $showCacheAction),
            ])

            HStack {
                Button("Show everything") { resetVisibility() }
                    .controlSize(.small)
                Spacer()
                Text("Hidden items stay in the data; only the UI changes.")
                    .font(.system(size: 8.5))
                    .foregroundStyle(.tertiary)
            }
        }
    }

    private func subLabel(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 8, weight: .bold, design: .rounded))
            .tracking(0.6)
            .foregroundStyle(.tertiary)
            .padding(.top, 2)
    }

    private func chipGrid(_ items: [(String, Binding<Bool>)]) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 5) {
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                VisibilityChip(label: item.0, isOn: item.1)
            }
        }
    }

    private func resetVisibility() {
        let keys = [
            "serverfo.showHistoryTab", "serverfo.showUpdatesTab", "serverfo.showStatusPill",
            "serverfo.showHost", "serverfo.showFooter", "serverfo.showMenuDot",
            "serverfo.showRowImage", "serverfo.showRowUptime", "serverfo.showRowPorts",
            "serverfo.showRowHealth", "serverfo.showRowRestarts", "serverfo.showRowCPU",
            "serverfo.showRowMemory", "serverfo.showRowStackCounts",
            "serverfo.showDetailMetrics", "serverfo.showDetailCharts", "serverfo.showDetailInspect",
            "serverfo.showHistoryEvents", "serverfo.showPendingPackages",
            "serverfo.showActivityLog", "serverfo.showCacheAction",
        ]
        for key in keys { UserDefaults.standard.set(true, forKey: key) }
        barBadge = false
    }

    // MARK: Connection

    private var connectionCard: some View {
        settingsCard(title: "Connection", icon: "network") {
            field("Host", text: $host, placeholder: "192.168.1.22 or host.tailnet.ts.net")
            field("User", text: $user, placeholder: "server1")
            HStack(spacing: 10) {
                Text("Port")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                    .frame(width: 74, alignment: .leading)
                TextField("22", value: $port, format: .number)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 10.5, design: .monospaced))
                    .frame(width: 64)
                Spacer()
            }
            field("Identity", text: $identity, placeholder: "~/.ssh/id_ed25519 (optional)")

            Divider().opacity(0.35)

            HStack(alignment: .top, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Route via Tailscale")
                        .font(.system(size: 10.5, weight: .medium))
                    Text("Mac → Raspberry Pi over Tailscale → server1 on the Pi's LAN.")
                        .font(.system(size: 8.5))
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Toggle("", isOn: Binding(
                    get: { store.tailscaleEnabled },
                    set: { store.setTailscale($0) }
                ))
                .toggleStyle(.switch)
                .tint(Theme.accentText)
                .controlSize(.mini)
                .labelsHidden()
            }

            if store.tailscaleEnabled {
                field("Pi host", text: $tailscaleHost, placeholder: "100.117.187.32")
                field("Pi user", text: $tailscaleUser, placeholder: "pi")

                HStack(spacing: 8) {
                    Button {
                        detectingPi = true
                        piMessage = nil
                        Task {
                            let ip = await store.refreshTailscaleIP()
                            piMessage = ip.map { "Pi at \($0)" }
                                ?? "Tailscale peer not found; using \(tailscaleHost)"
                            detectingPi = false
                            store.refresh()
                        }
                    } label: {
                        HStack(spacing: 4) {
                            if detectingPi { ProgressView().controlSize(.mini) }
                            Text(detectingPi ? "Detecting…" : "Detect Pi IP")
                                .font(.system(size: 10))
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(Theme.violetText)
                    .controlSize(.small)
                    .disabled(detectingPi)

                    if let piMessage {
                        Text(piMessage)
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(piMessage.hasPrefix("Pi at") ? Theme.green : Theme.amber)
                            .lineLimit(1)
                    }
                    Spacer()
                }

                Text("Route: \(SSHConfig.current().label)")
                    .font(.system(size: 8.5, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            HStack(spacing: 8) {
                Button {
                    testing = true
                    testResult = nil
                    Task {
                        let result = await store.testConnection()
                        testResult = result
                        testOK = result.hasPrefix("ok ")
                        testing = false
                    }
                } label: {
                    HStack(spacing: 4) {
                        if testing { ProgressView().controlSize(.mini) }
                        Text(testing ? "Testing…" : "Test connection")
                            .font(.system(size: 10))
                    }
                }
                .buttonStyle(.bordered)
                .tint(Theme.accentText)
                .controlSize(.small)
                .disabled(testing)

                if let testResult {
                    Image(systemName: testOK ? "checkmark.circle.fill" : "xmark.octagon.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(testOK ? Theme.green : Theme.red)
                    Text(testResult)
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(testOK ? Theme.green : Theme.red)
                        .lineLimit(2)
                        .textSelection(.enabled)
                }
                Spacer()
            }

            Text("Key-based SSH only. The app runs /usr/bin/ssh in batch mode, so it never prompts for a password. New host keys are accepted on first use.")
                .font(.system(size: 8.5))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Refresh

    private var refreshCard: some View {
        settingsCard(title: "Refresh", icon: "arrow.clockwise") {
            pickerRow(
                "Containers",
                selection: $refresh,
                options: [(15, "15 seconds"), (30, "30 seconds"), (60, "1 minute"), (120, "2 minutes")],
                note: "How often the panel asks the server for container state."
            )
            pickerRow(
                "History sample",
                selection: $sample,
                options: [(1, "every minute"), (5, "every 5 minutes"), (15, "every 15 minutes"), (30, "every 30 minutes")],
                note: "Written to the local 30-day history while the app is refreshing."
            )
        }
    }

    // MARK: History

    private var historyCard: some View {
        settingsCard(title: "History", icon: "clock.arrow.circlepath") {
            HStack {
                Text("Retention")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("30 days · automatic")
                    .font(.system(size: 10))
                    .foregroundStyle(.primary)
            }
            if let stats = store.historyStats {
                Text("\(stats.samples) samples · \(stats.events) state changes · \(Fmt.bytes(stats.bytes)) on disk")
                    .font(.system(size: 8.5, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
            HStack(spacing: 8) {
                Button("Prune now") {
                    let removed = store.pruneNow()
                    pruneMessage = removed == 0
                        ? "Nothing older than 30 days."
                        : "Removed \(removed) rows older than 30 days."
                }
                .controlSize(.small)
                if let pruneMessage {
                    Text(pruneMessage)
                        .font(.system(size: 9))
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }

    // MARK: Maintenance

    private var maintenanceCard: some View {
        settingsCard(title: "Maintenance", icon: "shippingbox.fill") {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Upgrade every 30 days")
                        .font(.system(size: 10.5, weight: .medium))
                    Text("Runs sudo apt update && sudo apt upgrade -y, logs every line, and retries the next day if it fails.")
                        .font(.system(size: 8.5))
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Toggle("", isOn: $autoUpgrade)
                    .toggleStyle(.switch)
                    .tint(Theme.accentText)
                    .controlSize(.mini)
                    .labelsHidden()
            }
            HStack {
                Text("Next run")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(store.nextUpgrade.map { Fmt.dateTime($0) } ?? "—")
                    .font(.system(size: 10, design: .monospaced))
            }
            Text("The RAM cache action uses sudo sh -c 'echo 3 > /proc/sys/vm/drop_caches'. No dist-upgrade, no autoremove and no reboot are ever issued.")
                .font(.system(size: 8.5))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: General

    private var generalCard: some View {
        settingsCard(title: "General", icon: "gearshape.fill") {
            toggleRow(
                "Launch at login",
                isOn: Binding(
                    get: { loginItem },
                    set: { value in
                        loginItem = value
                        try? LoginItem.set(value)
                        loginItem = LoginItem.enabled
                    }
                ),
                note: "A LaunchAgent in ~/Library/LaunchAgents."
            )
            toggleRow(
                "Show Dock icon",
                isOn: Binding(
                    get: { showDockIcon },
                    set: { value in
                        showDockIcon = value
                        DockIcon.apply()
                    }
                ),
                note: "Off by default. Optional fallback: adds a Dock icon that opens a dashboard window."
            )
            toggleRow(
                "Show server widget",
                isOn: Binding(
                    get: { widget.isVisible },
                    set: { value in
                        if value {
                            ServerWidgetController.shared.show(store: store)
                        } else {
                            ServerWidgetController.shared.hide()
                        }
                    }
                ),
                note: "Floating card with RAM, CPU, disk, uptime, Docker and updates."
            )
            toggleRow("Check GitHub for updates", isOn: $checkUpdates, note: "Once at launch, read-only.")
        }
    }

    private var aboutCard: some View {
        settingsCard(title: "About", icon: "info.circle.fill") {
            HStack {
                Text("Version")
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?")
                    .font(.system(size: 10, design: .monospaced))
                if let latest = store.latestVersion {
                    Pill(text: "\(latest) available", color: Theme.amber)
                }
            }
            HStack(spacing: 8) {
                Button("GitHub repository") {
                    if let url = URL(string: "https://github.com/Dhivyadhanush/server-fo") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .controlSize(.small)
                Button("Check now") {
                    Task { await store.checkForUpdates() }
                }
                .controlSize(.small)
                Spacer()
                Button("Quit Server-Fo") {
                    NSApp.terminate(nil)
                }
                .controlSize(.small)
            }
            Text("Server-Fo is a menu bar viewer for one server over SSH. It shows per-application usage, not host CPU, memory or network totals — the dynamic island already tracks those.")
                .font(.system(size: 8.5))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: Building blocks

    private func settingsCard<Content: View>(
        title: String,
        icon: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(Theme.accentText.opacity(0.9))
                Text(title.uppercased())
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(0.7)
                    .foregroundStyle(.tertiary)
            }
            content()
        }
        .cardStyle(padding: 11)
    }

    private func field(_ label: String, text: Binding<String>, placeholder: String = "") -> some View {
        HStack(spacing: 10) {
            Text(label)
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
                .frame(width: 74, alignment: .leading)
            TextField(placeholder, text: text)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 10.5, design: .monospaced))
        }
    }

    private func pickerRow(
        _ label: String,
        selection: Binding<Int>,
        options: [(Int, String)],
        note: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack {
                Text(label)
                    .font(.system(size: 10.5))
                    .foregroundStyle(.secondary)
                Spacer()
                Picker("", selection: selection) {
                    ForEach(options, id: \.0) { value, text in
                        Text(text).tag(value)
                    }
                }
                .labelsHidden()
                .controlSize(.small)
                .frame(width: 140)
            }
            Text(note)
                .font(.system(size: 8.5))
                .foregroundStyle(.tertiary)
        }
    }

    private func toggleRow(_ label: String, isOn: Binding<Bool>, note: String) -> some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.system(size: 10.5, weight: .medium))
                Text(note)
                    .font(.system(size: 8.5))
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            Toggle("", isOn: isOn)
                .toggleStyle(.switch)
                .tint(Theme.accentText)
                .controlSize(.mini)
                .labelsHidden()
        }
    }
}

struct VisibilityChip: View {
    var label: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            HStack(spacing: 4) {
                Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 9, weight: .semibold))
                Text(label)
                    .font(.system(size: 9.5, weight: .medium))
                    .lineLimit(1)
                Spacer(minLength: 0)
            }
            .foregroundStyle(isOn ? Theme.accentText : Color.secondary)
            .padding(.horizontal, 7)
            .padding(.vertical, 4.5)
            .background(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .fill(isOn ? Theme.accent.opacity(0.10) : Theme.surfaceSunken)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 6, style: .continuous)
                    .strokeBorder(isOn ? Theme.accent.opacity(0.25) : Theme.stroke, lineWidth: 0.8)
            )
        }
        .buttonStyle(.plain)
    }
}
