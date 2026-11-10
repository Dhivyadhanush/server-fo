import AppKit
import SwiftUI

struct UpdatesView: View {
    @ObservedObject var store: Store
    @AppStorage("sinfo.autoUpgrade") private var autoUpgrade = true

    @State private var confirming = false
    @State private var expandedRun: Int64?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                scheduleCard
                pendingCard
                if store.isUpgrading || !store.upgradeLines.isEmpty {
                    logCard
                }
                historyCard
                footnote
            }
            .padding(12)
        }
        .alert("Run apt update && apt upgrade?", isPresented: $confirming) {
            Button("Cancel", role: .cancel) {}
            Button("Update server") {
                store.runUpgrade(trigger: "manual")
            }
        } message: {
            Text("This runs on \(SSHConfig.current().label) now. It can take several minutes, and it does not reboot the server if a reboot is required.")
        }
        .onChange(of: autoUpgrade) { _, enabled in
            if enabled { store.checkSchedule() }
        }
    }

    // MARK: Schedule

    private var scheduleCard: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 6) {
                Image(systemName: "shippingbox.and.arrow.backward")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Theme.accent)
                Text("System updates")
                    .font(.system(size: 12, weight: .semibold))
                Spacer()
                Toggle("", isOn: $autoUpgrade)
                    .toggleStyle(.switch)
                    .tint(Theme.accent)
                    .controlSize(.mini)
                    .labelsHidden()
                    .disabled(store.isUpgrading)
            }

            HStack(alignment: .top, spacing: 18) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("LAST UPGRADE")
                        .font(.system(size: 8, weight: .semibold))
                        .tracking(0.5)
                        .foregroundStyle(.tertiary)
                    Text(store.lastUpgrade.map { Fmt.dateTime($0) } ?? "never")
                        .font(.system(size: 10, design: .monospaced))
                    Text(Fmt.relative(store.lastUpgrade))
                        .font(.system(size: 8.5))
                        .foregroundStyle(.tertiary)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("NEXT RUN")
                        .font(.system(size: 8, weight: .semibold))
                        .tracking(0.5)
                        .foregroundStyle(.tertiary)
                    Text(store.nextUpgrade.map { Fmt.dateTime($0) } ?? "—")
                        .font(.system(size: 10, design: .monospaced))
                    Text(autoUpgrade ? remaining : "automatic runs are off")
                        .font(.system(size: 8.5))
                        .foregroundStyle(
                            autoUpgrade && (store.upgradeDueIn ?? 1) <= 0 ? Theme.amber : Theme.subtle
                        )
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 6) {
                Button {
                    confirming = true
                } label: {
                    HStack(spacing: 4) {
                        if store.isUpgrading {
                            ProgressView().controlSize(.mini)
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 9, weight: .semibold))
                        }
                        Text(store.isUpgrading ? "Updating…" : "Run update now")
                            .font(.system(size: 10.5, weight: .semibold))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 2)
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accent)
                .disabled(store.isUpgrading || !store.connection.isOnline)

                if let exit = store.upgradeExit, !store.isUpgrading {
                    Pill(
                        text: exit == 0 ? "completed" : "exit \(exit)",
                        color: exit == 0 ? Theme.green : Theme.red,
                        icon: exit == 0 ? "checkmark.circle.fill" : "xmark.octagon.fill"
                    )
                }
            }

            Text("Runs exactly sudo apt update && sudo apt upgrade -y every 30 days. No dist-upgrade, no autoremove, no reboot.")
                .font(.system(size: 8.5))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .cardStyle(padding: 11)
    }

    private var remaining: String {
        guard let interval = store.upgradeDueIn else { return "waiting for first run" }
        if interval <= 0 { return "due now" }
        return "in \(Fmt.days(interval))"
    }

    // MARK: Pending packages

    private var pendingCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(spacing: 6) {
                SectionTitle(
                    text: "Pending packages",
                    trailing: "\(store.probe?.aptUpgradable.count ?? 0)"
                )
                if store.probe?.rebootRequired == true {
                    Pill(text: "reboot required", color: Theme.amber, icon: "power")
                }
            }

            let packages = store.probe?.aptUpgradable ?? []
            if packages.isEmpty {
                Text(store.connection.isOnline
                     ? "The package index is current. Nothing is waiting."
                     : "Waiting for the server.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            } else {
                Text(packages.prefix(12).joined(separator: "  ·  "))
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if packages.count > 12 {
                    Text("+ \(packages.count - 12) more")
                        .font(.system(size: 8.5, weight: .medium))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .cardStyle(padding: 11)
    }

    // MARK: Live log

    private var logCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                if store.isUpgrading {
                    ProgressView().controlSize(.mini)
                    Text("apt is running")
                        .font(.system(size: 10, weight: .semibold))
                    if let started = store.upgradeStarted {
                        Text(Fmt.duration(Date().timeIntervalSince(started)))
                            .font(.system(size: 9, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                } else if let exit = store.upgradeExit {
                    Image(systemName: exit == 0 ? "checkmark.circle.fill" : "xmark.octagon.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(exit == 0 ? Theme.green : Theme.red)
                    Text(exit == 0 ? "Upgrade finished" : "Upgrade failed · exit \(exit)")
                        .font(.system(size: 10, weight: .semibold))
                }
                Spacer()
                Button {
                    let text = store.upgradeLines.joined(separator: "\n")
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
                } label: {
                    Image(systemName: "doc.on.doc")
                        .font(.system(size: 9))
                }
                .buttonStyle(.borderless)
                .help("Copy log")
            }

            logConsole
        }
        .cardStyle(padding: 10)
    }

    private var logConsole: some View {
        let lines = Array(store.upgradeLines.suffix(400)) + [""]
        return ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(lines.enumerated()), id: \.offset) { _, line in
                        Text(line.isEmpty ? " " : line)
                            .font(.system(size: 8.3, design: .monospaced))
                            .foregroundStyle(logColor(line))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .textSelection(.enabled)
                    }
                    Color.clear.frame(height: 1).id("end")
                }
                .padding(6)
            }
            .frame(height: 170)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.black.opacity(0.18))
            )
            .onChange(of: store.upgradeLines.count) { _, _ in
                proxy.scrollTo("end", anchor: .bottom)
            }
        }
    }

    private func logColor(_ line: String) -> Color {
        if line.hasPrefix("[sinfo]") { return Theme.accent }
        let lower = line.lowercased()
        if lower.contains("error") || lower.contains("failed") || lower.contains("warning") {
            return Theme.amber
        }
        return Color.primary.opacity(0.72)
    }

    // MARK: History

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionTitle(text: "Upgrade log", trailing: "30 days")

            if store.upgradeHistory.isEmpty {
                Text("No upgrade runs recorded yet.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ForEach(store.upgradeHistory) { run in
                        runRow(run)
                    }
                }
            }
        }
        .cardStyle(padding: 10)
    }

    private func runRow(_ run: MaintenanceRun) -> some View {
        let open = expandedRun == run.id
        return VStack(spacing: 0) {
            Button {
                expandedRun = open ? nil : run.id
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: run.succeeded ? "checkmark.circle.fill" : "xmark.octagon.fill")
                        .font(.system(size: 9))
                        .foregroundStyle(run.succeeded ? Theme.green : Theme.red)
                    Text(Fmt.dateTime(run.started))
                        .font(.system(size: 9.5, design: .monospaced))
                    Text(run.trigger)
                        .font(.system(size: 8))
                        .foregroundStyle(.tertiary)
                    Spacer()
                    if let finished = run.finished {
                        Text(Fmt.duration(finished.timeIntervalSince(run.started)))
                            .font(.system(size: 8.5, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                    Image(systemName: open ? "chevron.down" : "chevron.right")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.quaternary)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 5)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if open {
                ScrollView {
                    Text(run.output.isEmpty ? "(no output)" : run.output)
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(6)
                }
                .frame(height: 140)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.black.opacity(0.14))
                )
                .padding(.bottom, 5)
            }

            if run.id != store.upgradeHistory.last?.id {
                Divider().opacity(0.25)
            }
        }
    }

    private var footnote: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "lock.shield")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
            Text("Commands run over SSH with your key, using passwordless sudo. Only the output of apt is stored, on this Mac, and it is deleted after 30 days.")
                .font(.system(size: 8.5))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 2)
    }
}
