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
    @AppStorage("serverfo.showDockIcon") private var showDockIcon = false
    @AppStorage("serverfo.appearance") private var appearance = "system"

    @AppStorage("serverfo.showHistoryTab") private var showHistoryTab = true
    @AppStorage("serverfo.showUpdatesTab") private var showUpdatesTab = true
    @AppStorage("serverfo.showStatusPill") private var showStatusPill = true
    @AppStorage("serverfo.showHost") private var showHost = true
    @AppStorage("serverfo.showFooter") private var showFooter = true
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

    @ObservedObject private var widget = ServerWidgetController.shared

    @State private var loginItem = LoginItem.enabled
    @State private var testing = false
    @State private var testResult: String?
    @State private var testOK = false
    @State private var detectingPi = false
    @State private var piMessage: String?
    @State private var pruneMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Server-Fo Settings")
                    .font(.headline)
                Spacer()
                Button("Done") {
                    store.applySettings()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)

            Divider()

            Form {
                connectionSection
                appearanceSection
                refreshSection
                historySection
                maintenanceSection
                visibilitySections
                generalSection
                aboutSection
            }
            .formStyle(.grouped)
        }
        .frame(width: 490, height: 640)
        .onChange(of: appearance) { _, value in AppearanceMode.apply(value) }
        .onDisappear { store.applySettings() }
    }

    // MARK: Connection

    private var connectionSection: some View {
        Section {
            Toggle("Use Tailscale jump host", isOn: Binding(
                get: { store.tailscaleEnabled },
                set: { store.setTailscale($0) }
            ))

            TextField("Server host", text: $host)
                .disabled(store.tailscaleEnabled)
                .foregroundStyle(store.tailscaleEnabled ? .secondary : .primary)

            TextField("Tailscale IP", text: $tailscaleHost)
                .disabled(!store.tailscaleEnabled)
                .foregroundStyle(store.tailscaleEnabled ? .primary : .secondary)

            TextField("Pi user", text: $tailscaleUser)
                .disabled(!store.tailscaleEnabled)
                .foregroundStyle(store.tailscaleEnabled ? .primary : .secondary)

            TextField("Server user", text: $user)

            TextField("Port", value: $port, format: .number)

            TextField("Identity (optional)", text: $identity)

            if store.tailscaleEnabled {
                HStack {
                    Button {
                        detectingPi = true
                        piMessage = nil
                        Task {
                            let ip = await store.refreshTailscaleIP()
                            piMessage = ip.map { "Pi at \($0)" }
                                ?? "No Tailscale peer found"
                            detectingPi = false
                            store.refresh()
                        }
                    } label: {
                        if detectingPi {
                            ProgressView().controlSize(.small)
                        } else {
                            Text("Detect Pi IP")
                        }
                    }
                    .disabled(detectingPi)

                    if let piMessage {
                        Text(piMessage)
                            .font(.caption)
                            .foregroundStyle(piMessage.hasPrefix("Pi at") ? .green : .orange)
                    }
                }
            }

            HStack {
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
                    if testing {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Test connection")
                    }
                }
                .disabled(testing)

                if let testResult {
                    Text(testResult)
                        .font(.caption.monospaced())
                        .foregroundStyle(testOK ? .green : .red)
                        .lineLimit(2)
                }
            }

            LabeledContent("Active route", value: SSHConfig.current().label)
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            Text("Connection")
        } footer: {
            Text(store.tailscaleEnabled
                 ? "Tailscale is on. Only the Tailscale IP is editable; turn it off to edit the server host."
                 : "Direct LAN is on. Only the server host is editable; turn on Tailscale to edit the Tailscale IP.")
        }
    }

    // MARK: Appearance

    private var appearanceSection: some View {
        Section("Appearance") {
            Picker("Theme", selection: $appearance) {
                ForEach(AppearanceMode.allCases) { mode in
                    Text(mode.label).tag(mode.rawValue)
                }
            }
            .pickerStyle(.segmented)

            Text("System follows macOS. Light and Dark override it.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Refresh

    private var refreshSection: some View {
        Section("Refresh") {
            Picker("Containers", selection: $refresh) {
                Text("15 seconds").tag(15)
                Text("30 seconds").tag(30)
                Text("1 minute").tag(60)
                Text("2 minutes").tag(120)
            }

            Picker("History sample", selection: $sample) {
                Text("Every minute").tag(1)
                Text("Every 5 minutes").tag(5)
                Text("Every 15 minutes").tag(15)
                Text("Every 30 minutes").tag(30)
            }
        }
    }

    // MARK: History

    private var historySection: some View {
        Section("History") {
            LabeledContent("Retention", value: "30 days, automatic")
            if let stats = store.historyStats {
                LabeledContent(
                    "On disk",
                    value: "\(stats.samples) samples · \(stats.events) events · \(Fmt.bytes(stats.bytes))"
                )
            }
            HStack {
                Button("Prune now") {
                    let removed = store.pruneNow()
                    pruneMessage = removed == 0
                        ? "Nothing older than 30 days."
                        : "Removed \(removed) rows."
                }
                if let pruneMessage {
                    Text(pruneMessage)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: Maintenance

    private var maintenanceSection: some View {
        Section("Maintenance") {
            Toggle("Upgrade every 30 days", isOn: $autoUpgrade)
            LabeledContent(
                "Next run",
                value: store.nextUpgrade.map { Fmt.dateTime($0) } ?? "—"
            )
            Text("Runs sudo apt update && sudo apt upgrade -y. No dist-upgrade, no autoremove, no reboot. The RAM cache action is in the Updates tab.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: Visibility

    @ViewBuilder
    private var visibilitySections: some View {
        Section("Panel") {
            Toggle("Status pill", isOn: $showStatusPill)
            Toggle("Hostname", isOn: $showHost)
            Toggle("Footer", isOn: $showFooter)
            Toggle("History tab", isOn: $showHistoryTab)
            Toggle("Updates tab", isOn: $showUpdatesTab)
        }

        Section("Container rows") {
            Toggle("Image", isOn: $showRowImage)
            Toggle("Uptime", isOn: $showRowUptime)
            Toggle("Ports", isOn: $showRowPorts)
            Toggle("Health", isOn: $showRowHealth)
            Toggle("Restarts", isOn: $showRowRestarts)
            Toggle("CPU", isOn: $showRowCPU)
            Toggle("Memory", isOn: $showRowMemory)
            Toggle("Stack counts", isOn: $showRowStackCounts)
        }

        Section("Detail, history and updates") {
            Toggle("Metrics", isOn: $showDetailMetrics)
            Toggle("Charts", isOn: $showDetailCharts)
            Toggle("Mounts & logs", isOn: $showDetailInspect)
            Toggle("State events", isOn: $showHistoryEvents)
            Toggle("Pending packages", isOn: $showPendingPackages)
            Toggle("Activity log", isOn: $showActivityLog)
            Toggle("RAM cache action", isOn: $showCacheAction)
        }
    }

    // MARK: General

    private var generalSection: some View {
        Section("General") {
            Toggle("Launch at login", isOn: Binding(
                get: { loginItem },
                set: { value in
                    loginItem = value
                    try? LoginItem.set(value)
                    loginItem = LoginItem.enabled
                }
            ))

            Toggle("Show Dock icon", isOn: Binding(
                get: { showDockIcon },
                set: { value in
                    showDockIcon = value
                    DockIcon.apply()
                }
            ))

            Toggle("Show server widget", isOn: Binding(
                get: { widget.isVisible },
                set: { value in
                    if value {
                        ServerWidgetController.shared.show(store: store)
                    } else {
                        ServerWidgetController.shared.hide()
                    }
                }
            ))

            Toggle("Check GitHub for updates", isOn: $checkUpdates)
        }
    }

    // MARK: About

    private var aboutSection: some View {
        Section("About") {
            LabeledContent(
                "Version",
                value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
            )

            if let latest = store.latestVersion {
                LabeledContent("Update", value: "\(latest) available")
            }

            HStack {
                Button("GitHub repository") {
                    if let url = URL(string: "https://github.com/Dhivyadhanush/server-fo") {
                        NSWorkspace.shared.open(url)
                    }
                }

                Button("Check now") {
                    Task { await store.checkForUpdates() }
                }

                Spacer()

                Button("Quit Server-Fo") {
                    NSApp.terminate(nil)
                }
            }
        }
    }
}
