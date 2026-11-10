import AppKit
import Foundation

// MARK: - Main store

@MainActor
final class Store: ObservableObject {
    enum Connection: Equatable {
        case idle
        case connecting
        case online
        case unreachable(String)

        var isOnline: Bool { self == .online }
    }

    enum Tab: String, CaseIterable, Identifiable {
        case containers = "Containers"
        case history = "History"
        case updates = "Updates"
        var id: String { rawValue }
    }

    @Published private(set) var probe: Probe?
    @Published private(set) var connection: Connection = .idle
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var isRefreshing = false
    @Published private(set) var lastError: String?

    @Published private(set) var isUpgrading = false
    @Published private(set) var upgradeLines: [String] = []
    @Published private(set) var upgradeExit: Int?
    @Published private(set) var upgradeStarted: Date?
    @Published private(set) var lastUpgrade: Date?
    @Published private(set) var lastAttempt: Date?
    @Published private(set) var firstSeen: Date?
    @Published private(set) var upgradeHistory: [MaintenanceRun] = []
    @Published private(set) var historyStats: HistoryStats?

    @Published private(set) var isClearingCache = false
    @Published private(set) var cacheExit: Int?
    @Published private(set) var lastCacheClear: Date?

    @Published var latestVersion: String?

    let history = HistoryStore()
    static let upgradeInterval: TimeInterval = 30 * 86_400

    enum Keys {
        static let lastUpgrade = "lastUpgrade"
        static let lastAttempt = "lastAttempt"
        static let firstSeen = "firstSeen"
        static let lastCacheClear = "lastCacheClear"
    }

    // Settings, read live so a change in the sheet applies without a restart.
    var refreshInterval: TimeInterval {
        let value = UserDefaults.standard.integer(forKey: "serverfo.refresh")
        return value == 0 ? 30 : TimeInterval(max(10, value))
    }

    /// The setting is in minutes; the timer works in seconds.
    var sampleInterval: TimeInterval {
        SampleCadence.seconds(fromSetting: UserDefaults.standard.integer(forKey: "serverfo.sample"))
    }

    var autoUpgrade: Bool {
        UserDefaults.standard.object(forKey: "serverfo.autoUpgrade") as? Bool ?? true
    }

    var nextUpgrade: Date? {
        UpgradeSchedule.next(
            lastSuccess: lastUpgrade,
            lastAttempt: lastAttempt,
            firstSeen: firstSeen
        )
    }

    var upgradeDueIn: TimeInterval? {
        nextUpgrade.map { $0.timeIntervalSinceNow }
    }

    // MARK: Lifecycle

    private var refreshTimer: Timer?
    private var started = false
    private var lastSampleAt: Date = .distantPast
    private var lastScheduleCheck: Date = .distantPast

    func start() {
        guard !started else { return }
        started = true
        AppState.store = self

        let defaults = UserDefaults.standard
        if let raw = history.meta(Self.Keys.firstSeen), let epoch = Double(raw) {
            firstSeen = Date(timeIntervalSince1970: epoch)
        } else {
            let now = Date()
            firstSeen = now
            history.setMeta(Self.Keys.firstSeen, String(now.timeIntervalSince1970))
        }
        if let raw = history.meta(Self.Keys.lastUpgrade), let epoch = Double(raw) {
            lastUpgrade = Date(timeIntervalSince1970: epoch)
        }
        if let raw = history.meta(Self.Keys.lastAttempt), let epoch = Double(raw) {
            lastAttempt = Date(timeIntervalSince1970: epoch)
        }
        if let raw = history.meta(Self.Keys.lastCacheClear), let epoch = Double(raw) {
            lastCacheClear = Date(timeIntervalSince1970: epoch)
        }

        history.prune()
        lastSampleAt = history.latestSampleDate() ?? .distantPast

        scheduleTimer()
        reloadHistory()
        refresh()

        // @AppStorage shows this as ON by default, so an absent key must mean
        // ON here too; bool(forKey:) would report false.
        if defaults.object(forKey: "serverfo.checkUpdates") as? Bool ?? true {
            Task { await checkForUpdates() }
        }
    }

    func applySettings() {
        scheduleTimer()
    }

    private func scheduleTimer() {
        refreshTimer?.invalidate()
        let timer = Timer(timeInterval: refreshInterval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refresh()
                self?.checkSchedule()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        refreshTimer = timer
    }

    // MARK: Refresh

    func refresh() {
        guard !isRefreshing else { return }
        isRefreshing = true
        if probe == nil { connection = .connecting }

        Task {
            do {
                let raw = try await RemoteProbe.fetch()
                let parsed = ProbeParser.parse(raw)
                probe = parsed
                connection = .online
                lastUpdated = Date()
                lastError = nil
                recordSampleIfDue(parsed)
            } catch {
                let message = error.localizedDescription
                connection = .unreachable(message)
                lastError = message
            }
            isRefreshing = false
        }
    }

    private func recordSampleIfDue(_ probe: Probe) {
        let now = Date()
        guard now.timeIntervalSince(lastSampleAt) >= sampleInterval else { return }
        lastSampleAt = now
        history.record(probe)
        // Give the writer a beat, then refresh the counters the UI shows.
        Task {
            try? await Task.sleep(nanoseconds: 300_000_000)
            reloadHistory()
        }
    }

    // MARK: History

    func reloadHistory() {
        let history = self.history
        Task.detached(priority: .utility) {
            let runs = history.maintenance()
            let stats = history.stats()
            await MainActor.run {
                self.upgradeHistory = runs
                self.historyStats = stats
            }
        }
    }

    func summaries(since: Date) async -> [ContainerSummary] {
        let history = self.history
        return await Task.detached(priority: .userInitiated) {
            history.summaries(since: since)
        }.value
    }

    func series(name: String, since: Date) async -> [Sample] {
        let history = self.history
        return await Task.detached(priority: .userInitiated) {
            history.series(name: name, since: since)
        }.value
    }

    func events(since: Date) async -> [HistoryEvent] {
        let history = self.history
        return await Task.detached(priority: .userInitiated) {
            history.events(since: since)
        }.value
    }

    // MARK: Maintenance

    func checkSchedule() {
        guard autoUpgrade, !isUpgrading, !isClearingCache, connection.isOnline else { return }
        guard Date().timeIntervalSince(lastScheduleCheck) > 30 else { return }
        lastScheduleCheck = Date()
        guard let nextUpgrade, nextUpgrade <= Date() else { return }
        runUpgrade(trigger: "scheduled")
    }

    func runUpgrade(trigger: String) {
        guard !isUpgrading, !isClearingCache else { return }
        let config = SSHConfig.current()
        let isScheduled = trigger == "scheduled"

        isUpgrading = true
        upgradeExit = nil
        upgradeLines = []
        upgradeStarted = Date()

        Task {
            var output: [String] = []
            var code: Int = -1

            do {
                let result = try await SSH.execute(
                    Maintenance.script,
                    config: config,
                    timeout: 3_600
                ) { line in
                    Task { @MainActor in
                        self.appendUpgradeLine(line)
                    }
                }
                code = Int(result.code)
                output = result.output.components(separatedBy: .newlines)
            } catch {
                code = -1
                let line = "error: \(error.localizedDescription)"
                output = [line]
                appendUpgradeLine(line)
            }

            let finished = Date()
            let full = output.joined(separator: "\n")

            history.addMaintenance(
                started: upgradeStarted ?? finished,
                finished: finished,
                trigger: trigger,
                exitCode: code,
                output: full
            )

            history.setMeta(Self.Keys.lastAttempt, String(finished.timeIntervalSince1970))
            if code == 0 {
                history.setMeta(Self.Keys.lastUpgrade, String(finished.timeIntervalSince1970))
                lastUpgrade = finished
            }
            lastAttempt = finished
            history.prune()

            upgradeExit = code
            isUpgrading = false

            if isScheduled, code != 0 {
                appendUpgradeLine("[serverfo] scheduled upgrade failed; retrying in 24h")
            }

            reloadHistory()
            refresh()
        }
    }

    // MARK: RAM cache

    /// Drops Linux page cache, dentries and inodes. This is not "freeing app
    /// memory"; it discards clean caches the kernel will rebuild on demand.
    func runCacheClear() {
        guard !isClearingCache, !isUpgrading else { return }
        isClearingCache = true
        cacheExit = nil
        let started = Date()

        Task {
            var output = ""
            var code = -1

            do {
                let result = try await SSH.execute(
                    Maintenance.cacheScript,
                    config: .current(),
                    timeout: 120
                )
                code = Int(result.code)
                output = result.output
            } catch {
                output = "error: \(error.localizedDescription)"
            }

            let finished = Date()
            history.addMaintenance(
                started: started,
                finished: finished,
                trigger: "cache",
                exitCode: code,
                output: output
            )
            if code == 0 {
                history.setMeta(Self.Keys.lastCacheClear, String(finished.timeIntervalSince1970))
                lastCacheClear = finished
            }
            history.prune()
            reloadHistory()
            cacheExit = code
            isClearingCache = false
        }
    }

    private func appendUpgradeLine(_ line: String) {
        upgradeLines.append(line)
        if upgradeLines.count > 600 {
            upgradeLines.removeFirst(upgradeLines.count - 600)
        }
    }

    func lastUpgradeOutput() -> String? {
        upgradeHistory.first?.output
    }

    @discardableResult
    func pruneNow() -> Int {
        let removed = history.pruneNow()
        reloadHistory()
        return removed
    }

    // MARK: Update check

    func checkForUpdates() async {
        let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
        guard let tag = await UpdateCheck.fetchLatest() else { return }
        if UpdateCheck.newer(latest: tag, current: current) {
            latestVersion = tag
        }
    }

    // MARK: Connection test

    func testConnection() async -> String {
        do {
            let output = try await SSH.run(
                "printf 'ok %s %s\\n' \"$(hostname)\" \"$(uname -r)\"",
                config: .current(),
                timeout: 12
            )
            return output.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            return error.localizedDescription
        }
    }
}

enum SampleCadence {
    /// A zero/absent setting means the five-minute default. Kept separate so
    /// the selftest can pin the unit down.
    static func seconds(fromSetting value: Int) -> TimeInterval {
        TimeInterval((value == 0 ? 5 : max(1, value)) * 60)
    }
}

// MARK: - Schedule

/// One 30-day cadence for the app and the headless helper. A failed attempt
/// retries the next day instead of every tick; a success resets the month.
enum UpgradeSchedule {
    static let interval: TimeInterval = 30 * 86_400

    static func next(lastSuccess: Date?, lastAttempt: Date?, firstSeen: Date?) -> Date? {
        if let lastSuccess {
            if let lastAttempt, lastAttempt > lastSuccess {
                return lastAttempt.addingTimeInterval(86_400)
            }
            return lastSuccess.addingTimeInterval(interval)
        }
        if let lastAttempt {
            return lastAttempt.addingTimeInterval(86_400)
        }
        return firstSeen?.addingTimeInterval(interval)
    }
}

// MARK: - Remote maintenance

enum Maintenance {
    /// Deliberately nothing more than the two commands the app promises:
    /// `apt update` followed by `apt upgrade -y`. No dist-upgrade, no
    /// autoremove, no reboot.
    static let script = """
    export LC_ALL=C
    export DEBIAN_FRONTEND=noninteractive
    echo "[serverfo] $(date -Is) apt update"
    sudo -n apt update
    rc=$?
    if [ $rc -ne 0 ]; then
      echo "[serverfo] apt update failed with exit $rc"
      exit $rc
    fi
    echo "[serverfo] $(date -Is) apt upgrade"
    sudo -n env DEBIAN_FRONTEND=noninteractive apt upgrade -y
    rc=$?
    echo "[serverfo] $(date -Is) apt upgrade exited $rc"
    if [ -f /var/run/reboot-required ]; then
      echo "[serverfo] reboot required: $(cat /var/run/reboot-required 2>/dev/null)"
    fi
    exit $rc
    """

    /// Linux page cache, dentries and inodes. Only clean caches are dropped;
    /// running applications are not touched and nothing is restarted.
    static let cacheScript = """
    export LC_ALL=C
    echo "[serverfo] $(date -Is) sync"
    sync
    echo "[serverfo] $(date -Is) dropping page cache, dentries and inodes"
    sudo -n sh -c 'echo 3 > /proc/sys/vm/drop_caches'
    rc=$?
    echo "[serverfo] cache clear exited $rc"
    if [ $rc -ne 0 ]; then
      echo "[serverfo] passwordless sudo for sh is required to drop caches"
    fi
    exit $rc
    """
}
