import AppKit
import SwiftUI

struct UpdatesView: View {
    @ObservedObject var store: Store
    @AppStorage("serverfo.autoUpgrade") private var autoUpgrade = true
    @AppStorage("serverfo.showPendingPackages") private var showPending = true
    @AppStorage("serverfo.showActivityLog") private var showActivity = true
    @AppStorage("serverfo.showCacheAction") private var showCache = true

    private enum Confirmation: Int, Identifiable {
        case upgrade, cache
        var id: Int { rawValue }
    }

    @State private var confirmation: Confirmation?
    @State private var expandedRun: Int64?

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 11) {
                scheduleCard
                if showCache { cacheCard }
                if showPending { pendingCard }
                if store.isUpgrading || !store.upgradeLines.isEmpty {
                    logCard
                }
                if showActivity { historyCard }
                footnote
            }
            .padding(12)
        }
        .alert(item: $confirmation) { item in
            switch item {
            case .upgrade:
                return Alert(
                    title: Text("Run apt update && apt upgrade?"),
                    message: Text("This runs on \(SSHConfig.current().label) now. It can take several minutes and does not reboot the server if a reboot is required."),
                    primaryButton: .cancel(),
                    secondaryButton: .default(Text("Update server")) {
                        store.runUpgrade(trigger: "manual")
                    }
                )
            case .cache:
                return Alert(
                    title: Text("Clear RAM cache?"),
                    message: Text("Drops clean page cache, dentries and inodes with sudo sh -c 'echo 3 > /proc/sys/vm/drop_caches'. Applications keep their memory and nothing restarts. Disk reads may be briefly slower while caches refill."),
                    primaryButton: .cancel(),
                    secondaryButton: .destructive(Text("Clear cache")) {
                        store.runCacheClear()
                    }
                )
            }
        }
        .onChange(of: autoUpgrade) { _, enabled in
            if enabled { store.checkSchedule() }
        }
    }

    // MARK: Schedule

    private var scheduleCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Theme.accentGradient)
                        .opacity(0.18)
                        .frame(width: 26, height: 26)
                    Image(systemName: "shippingbox.and.arrow.backward.fill")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Theme.accentText)
                }
                Text("System updates")
                    .font(.system(size: 12.5, weight: .bold, design: .rounded))
                Spacer()
                Toggle("", isOn: $autoUpgrade)
                    .toggleStyle(.switch)
                    .tint(Theme.accentText)
                    .controlSize(.mini)
                    .labelsHidden()
                    .disabled(store.isUpgrading)
            }

            HStack(alignment: .center, spacing: 14) {
                VStack(alignment: .leading, spacing: 7) {
                    timeBlock("LAST UPGRADE", store.lastUpgrade.map(Fmt.dateTime) ?? "never", Fmt.relative(store.lastUpgrade))
                    timeBlock("NEXT RUN", store.nextUpgrade.map(Fmt.dateTime) ?? "—", autoUpgrade ? remaining : "automatic runs are off")
                }
                Spacer(minLength: 0)
                countdownRing
            }

            Button {
                confirmation = .upgrade
            } label: {
                HStack(spacing: 5) {
                    if store.isUpgrading {
                        ProgressView().controlSize(.mini)
                    } else {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 9, weight: .bold))
                    }
                    Text(store.isUpgrading ? "Updating…" : "Run update now")
                        .font(.system(size: 10.5, weight: .bold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 3)
            }
            .buttonStyle(.borderedProminent)
            .tint(Theme.accentText)
            .disabled(store.isUpgrading || !store.connection.isOnline)

            HStack(spacing: 6) {
                Text("sudo apt update && sudo apt upgrade -y · every 30 days")
                    .font(.system(size: 8.3, design: .monospaced))
                    .foregroundStyle(.tertiary)
                Spacer()
                if let exit = store.upgradeExit, !store.isUpgrading {
                    Pill(
                        text: exit == 0 ? "completed" : "exit \(exit)",
                        color: exit == 0 ? Theme.green : Theme.red,
                        icon: exit == 0 ? "checkmark.circle.fill" : "xmark.octagon.fill"
                    )
                }
            }
        }
        .cardStyle(padding: 11)
    }

    private func timeBlock(_ label: String, _ value: String, _ note: String) -> some View {
        VStack(alignment: .leading, spacing: 1.5) {
            Text(label)
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .tracking(0.6)
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .lineLimit(1)
            Text(note)
                .font(.system(size: 8.3))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
        }
    }

    private var countdownRing: some View {
        let interval = store.upgradeDueIn ?? UpgradeSchedule.interval
        let progress = min(1, max(0, 1 - interval / UpgradeSchedule.interval))
        let days = max(0, Int(ceil(interval / 86_400)))

        return ZStack {
            Circle()
                .stroke(Theme.stroke, lineWidth: 4)
            Circle()
                .trim(from: 0, to: max(0.02, progress))
                .stroke(
                    Theme.accentGradient,
                    style: StrokeStyle(lineWidth: 4, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: Theme.accent.opacity(0.4), radius: 3)
            VStack(spacing: -1) {
                Text(interval <= 0 ? "now" : "\(days)")
                    .font(.system(size: interval <= 0 ? 12 : 16, weight: .heavy, design: .rounded))
                    .foregroundStyle(interval <= 0 ? Theme.amber : Color.primary)
                if interval > 0 {
                    Text(days == 1 ? "day" : "days")
                        .font(.system(size: 7.5, weight: .semibold))
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .frame(width: 58, height: 58)
    }

    private var remaining: String {
        guard let interval = store.upgradeDueIn else { return "waiting for first run" }
        if interval <= 0 { return "due now" }
        return "in \(Fmt.days(interval))"
    }

    // MARK: RAM cache

    private var cacheCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Theme.violetGradient)
                        .opacity(0.18)
                        .frame(width: 26, height: 26)
                    Image(systemName: "memorychip.fill")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Theme.violetText)
                }
                Text("RAM cache")
                    .font(.system(size: 12.5, weight: .bold, design: .rounded))
                Spacer()
                if let exit = store.cacheExit, !store.isClearingCache {
                    Pill(
                        text: exit == 0 ? "cleared" : "exit \(exit)",
                        color: exit == 0 ? Theme.green : Theme.red,
                        icon: exit == 0 ? "checkmark.circle.fill" : "xmark.octagon.fill"
                    )
                }
            }

            Text("Drops clean page cache, dentries and inodes. Running applications keep their memory; the kernel simply rebuilds caches as needed. Nothing restarts.")
                .font(.system(size: 9.2))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 1) {
                    Text("LAST CLEARED")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .tracking(0.5)
                        .foregroundStyle(.tertiary)
                    Text(store.lastCacheClear.map(Fmt.dateTime) ?? "never")
                        .font(.system(size: 9.5, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    confirmation = .cache
                } label: {
                    HStack(spacing: 4) {
                        if store.isClearingCache {
                            ProgressView().controlSize(.mini)
                        } else {
                            Image(systemName: "sparkles")
                                .font(.system(size: 9, weight: .bold))
                        }
                        Text(store.isClearingCache ? "Clearing…" : "Clear cache")
                            .font(.system(size: 10, weight: .semibold))
                    }
                }
                .buttonStyle(.bordered)
                .tint(Theme.violetText)
                .controlSize(.small)
                .disabled(store.isClearingCache || store.isUpgrading || !store.connection.isOnline)
            }
        }
        .cardStyle(padding: 11)
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
                    .padding(7)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Theme.surfaceSunken)
                    )
                if packages.count > 12 {
                    Text("+ \(packages.count - 12) more")
                        .font(.system(size: 8.5, weight: .semibold))
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
                    .fill(Theme.surfaceSunken)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .strokeBorder(Theme.stroke, lineWidth: 0.8)
                    )
            )
            .onChange(of: store.upgradeLines.count) { _, _ in
                proxy.scrollTo("end", anchor: .bottom)
            }
        }
    }

    private func logColor(_ line: String) -> Color {
        if line.hasPrefix("[serverfo]") { return Theme.accent }
        let lower = line.lowercased()
        if lower.contains("error") || lower.contains("failed") || lower.contains("warning") {
            return Theme.amber
        }
        return Color.primary.opacity(0.72)
    }

    // MARK: Activity

    private var historyCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionTitle(text: "Activity log", trailing: "30 days")

            if store.upgradeHistory.isEmpty {
                Text("No upgrade or cache runs recorded yet.")
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
        .cardStyle(padding: 11)
    }

    private func runRow(_ run: MaintenanceRun) -> some View {
        let open = expandedRun == run.id
        let cache = run.trigger == "cache"
        return VStack(spacing: 0) {
            Button {
                withAnimation(.easeOut(duration: 0.15)) {
                    expandedRun = open ? nil : run.id
                }
            } label: {
                HStack(spacing: 6) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 5, style: .continuous)
                            .fill((cache ? Theme.violetText : Theme.accentText).opacity(0.12))
                            .frame(width: 18, height: 18)
                        Image(systemName: cache ? "memorychip.fill" : "shippingbox.fill")
                            .font(.system(size: 7.5, weight: .bold))
                            .foregroundStyle(cache ? Theme.violetText : Theme.accentText)
                    }
                    Text(cache ? "RAM cache" : "Packages")
                        .font(.system(size: 9.5, weight: .medium))
                    Text(Fmt.dateTime(run.started))
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Image(systemName: run.succeeded ? "checkmark.circle.fill" : "xmark.octagon.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(run.succeeded ? Theme.green : Theme.red)
                    if let finished = run.finished {
                        Text(Fmt.duration(finished.timeIntervalSince(run.started)))
                            .font(.system(size: 8.3, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                    Image(systemName: open ? "chevron.down" : "chevron.right")
                        .font(.system(size: 7, weight: .bold))
                        .foregroundStyle(.quaternary)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 5.5)
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
                .frame(height: 130)
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Theme.surfaceSunken)
                )
                .padding(.bottom, 5)
            }

            if run.id != store.upgradeHistory.last?.id {
                Divider().opacity(0.2).padding(.leading, 24)
            }
        }
    }

    private var footnote: some View {
        HStack(alignment: .top, spacing: 6) {
            Image(systemName: "lock.shield.fill")
                .font(.system(size: 9))
                .foregroundStyle(Theme.accentText.opacity(0.8))
            Text("Commands run over SSH with your key and passwordless sudo. Output is stored on this Mac and deleted after 30 days. Server-Fo never reboots the server.")
                .font(.system(size: 8.5))
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.horizontal, 2)
    }
}
