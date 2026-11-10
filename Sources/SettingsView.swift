import AppKit
import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: Store
    @Environment(\.dismiss) private var dismiss

    @AppStorage("sinfo.ssh.host") private var host = "192.168.1.22"
    @AppStorage("sinfo.ssh.user") private var user = "server1"
    @AppStorage("sinfo.ssh.port") private var port = 22
    @AppStorage("sinfo.ssh.identity") private var identity = ""
    @AppStorage("sinfo.refresh") private var refresh = 30
    @AppStorage("sinfo.sample") private var sample = 5
    @AppStorage("sinfo.autoUpgrade") private var autoUpgrade = true
    @AppStorage("sinfo.checkUpdates") private var checkUpdates = true
    @AppStorage("sinfo.barBadge") private var barBadge = false

    @State private var loginItem = LoginItem.enabled
    @State private var testing = false
    @State private var testResult: String?
    @State private var testOK = false
    @State private var pruneMessage: String?

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("S-Info settings")
                    .font(.system(size: 14, weight: .bold))
                Spacer()
                Button("Done") {
                    store.applySettings()
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Divider()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    connectionCard
                    refreshCard
                    historyCard
                    maintenanceCard
                    generalCard
                    aboutCard
                }
                .padding(14)
            }
        }
        .frame(width: 470, height: 620)
        .onDisappear { store.applySettings() }
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
        settingsCard(title: "Maintenance", icon: "shippingbox") {
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
                    .tint(Theme.accent)
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
            Text("No dist-upgrade, no autoremove and no reboot are ever issued.")
                .font(.system(size: 8.5))
                .foregroundStyle(.tertiary)
        }
    }

    // MARK: General

    private var generalCard: some View {
        settingsCard(title: "General", icon: "gearshape") {
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
            toggleRow("Badge count in menu bar", isOn: $barBadge, note: "Shows unhealthy + stopped containers next to the icon.")
            toggleRow("Check GitHub for updates", isOn: $checkUpdates, note: "Once at launch, read-only.")
        }
    }

    private var aboutCard: some View {
        settingsCard(title: "About", icon: "info.circle") {
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
                    if let url = URL(string: "https://github.com/Dhivyadhanush/s-info") {
                        NSWorkspace.shared.open(url)
                    }
                }
                .controlSize(.small)
                Button("Check now") {
                    Task { await store.checkForUpdates() }
                }
                .controlSize(.small)
                Spacer()
                Button("Quit S-Info") {
                    NSApp.terminate(nil)
                }
                .controlSize(.small)
            }
            Text("S-Info is a menu bar viewer for one server over SSH. It shows per-application usage, not host CPU, memory or network totals — the dynamic island already tracks those.")
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
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.tertiary)
                Text(title.uppercased())
                    .font(.system(size: 9, weight: .semibold))
                    .tracking(0.6)
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
                .tint(Theme.accent)
                .controlSize(.mini)
                .labelsHidden()
        }
    }
}
