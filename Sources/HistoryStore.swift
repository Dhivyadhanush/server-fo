import Foundation
import SQLite3

private let SQLITE_TRANSIENT = unsafeBitCast(-1, to: sqlite3_destructor_type.self)

// MARK: - Records

struct Sample {
    let ts: Date
    let name: String
    let running: Bool
    let health: String
    let restarts: Int
    let cpu: Double
    let memUsed: Int64
    let memLimit: Int64
    let netRx: Int64
    let netTx: Int64
    let blkRead: Int64
    let blkWrite: Int64
    let pids: Int
}

struct ContainerSummary {
    let name: String
    let points: Int
    let avgCPU: Double
    let peakCPU: Double
    let avgMem: Int64
    let peakMem: Int64
    let samplesRunning: Int
}

struct HistoryEvent: Identifiable {
    let id: Int64
    let ts: Date
    let name: String
    let kind: String
    let detail: String
}

struct MaintenanceRun: Identifiable {
    let id: Int64
    let started: Date
    let finished: Date?
    let trigger: String
    let exitCode: Int
    let output: String

    var succeeded: Bool { exitCode == 0 }
}

struct HistoryStats {
    let samples: Int
    let events: Int
    let oldest: Date?
    let bytes: Int64
}

// MARK: - Store

/// Append-only history with a hard 30-day retention. All access is serialised
/// on one queue; SQLite is never touched from the main actor.
final class HistoryStore {
    static let retentionDays = 30

    let path: URL
    private var db: OpaquePointer?
    private let queue = DispatchQueue(label: "dev.dhanuz.sinfo.history")
    private var lastPrune: Date = .distantPast

    init(path: URL? = nil) {
        let support = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/S-Info", isDirectory: true)
        try? FileManager.default.createDirectory(at: support, withIntermediateDirectories: true)
        self.path = path ?? support.appendingPathComponent("history.sqlite")

        queue.sync {
            guard sqlite3_open_v2(
                self.path.path, &self.db,
                SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE | SQLITE_OPEN_FULLMUTEX, nil
            ) == SQLITE_OK else {
                NSLog("S-Info: could not open history at %@", self.path.path)
                return
            }
            sqlite3_exec(self.db, "PRAGMA journal_mode=WAL; PRAGMA synchronous=NORMAL;", nil, nil, nil)
            self.createSchema()
        }
    }

    deinit {
        if let db { sqlite3_close(db) }
    }

    private func createSchema() {
        let sql = """
        CREATE TABLE IF NOT EXISTS samples(
            ts INTEGER NOT NULL,
            name TEXT NOT NULL,
            running INTEGER NOT NULL DEFAULT 0,
            health TEXT NOT NULL DEFAULT '',
            restarts INTEGER NOT NULL DEFAULT 0,
            cpu REAL NOT NULL DEFAULT 0,
            mem INTEGER NOT NULL DEFAULT 0,
            mem_limit INTEGER NOT NULL DEFAULT 0,
            net_rx INTEGER NOT NULL DEFAULT 0,
            net_tx INTEGER NOT NULL DEFAULT 0,
            blk_read INTEGER NOT NULL DEFAULT 0,
            blk_write INTEGER NOT NULL DEFAULT 0,
            pids INTEGER NOT NULL DEFAULT 0
        );
        CREATE INDEX IF NOT EXISTS idx_samples_ts ON samples(ts);
        CREATE INDEX IF NOT EXISTS idx_samples_name_ts ON samples(name, ts);
        CREATE TABLE IF NOT EXISTS events(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            ts INTEGER NOT NULL,
            name TEXT NOT NULL,
            kind TEXT NOT NULL,
            detail TEXT NOT NULL DEFAULT ''
        );
        CREATE INDEX IF NOT EXISTS idx_events_ts ON events(ts);
        CREATE TABLE IF NOT EXISTS maintenance(
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            started INTEGER NOT NULL,
            finished INTEGER NOT NULL DEFAULT 0,
            trigger TEXT NOT NULL,
            exit_code INTEGER NOT NULL DEFAULT -1,
            output TEXT NOT NULL DEFAULT ''
        );
        CREATE INDEX IF NOT EXISTS idx_maintenance_started ON maintenance(started);
        CREATE TABLE IF NOT EXISTS meta(key TEXT PRIMARY KEY, value TEXT NOT NULL);
        """
        sqlite3_exec(db, sql, nil, nil, nil)
    }

    // MARK: Writes

    func record(_ probe: Probe) {
        queue.async {
            let now = Int(Date().timeIntervalSince1970)
            sqlite3_exec(self.db, "BEGIN IMMEDIATE", nil, nil, nil)

            for container in probe.containers {
                let previous = self.previousSample(name: container.name)
                self.insert(container: container, ts: now)
                self.detectEvents(container: container, previous: previous, ts: now)
            }

            sqlite3_exec(self.db, "COMMIT", nil, nil, nil)

            if Date().timeIntervalSince(self.lastPrune) > 3_600 {
                self.lastPrune = Date()
                self.pruneLocked()
            }
        }
    }

    /// Test/CLI helper: wait for the write so a headless process can exit.
    func recordAndWait(_ probe: Probe) {
        record(probe)
        queue.sync {}
    }

    private func insert(container: Container, ts: Int) {
        let sql = """
        INSERT INTO samples(ts,name,running,health,restarts,cpu,mem,mem_limit,
                            net_rx,net_tx,blk_read,blk_write,pids)
        VALUES(?,?,?,?,?,?,?,?,?,?,?,?,?)
        """
        guard let statement = prepare(sql) else { return }
        defer { sqlite3_finalize(statement) }

        sqlite3_bind_int64(statement, 1, Int64(ts))
        bind(statement, 2, container.name)
        sqlite3_bind_int(statement, 3, container.isRunning ? 1 : 0)
        bind(statement, 4, container.health)
        sqlite3_bind_int(statement, 5, Int32(container.restarts))
        sqlite3_bind_double(statement, 6, container.cpu)
        sqlite3_bind_int64(statement, 7, container.memUsed)
        sqlite3_bind_int64(statement, 8, container.memLimit)
        sqlite3_bind_int64(statement, 9, container.netRx)
        sqlite3_bind_int64(statement, 10, container.netTx)
        sqlite3_bind_int64(statement, 11, container.blkRead)
        sqlite3_bind_int64(statement, 12, container.blkWrite)
        sqlite3_bind_int(statement, 13, Int32(container.pids))
        sqlite3_step(statement)
    }

    private func previousSample(name: String) -> Sample? {
        let sql = """
        SELECT ts,running,health,restarts,cpu,mem,mem_limit,net_rx,net_tx,
               blk_read,blk_write,pids
        FROM samples WHERE name=? ORDER BY ts DESC LIMIT 1
        """
        guard let statement = prepare(sql) else { return nil }
        defer { sqlite3_finalize(statement) }
        bind(statement, 1, name)
        guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
        return Sample(
            ts: Date(timeIntervalSince1970: Double(sqlite3_column_int64(statement, 0))),
            name: name,
            running: sqlite3_column_int(statement, 1) == 1,
            health: text(statement, 2),
            restarts: Int(sqlite3_column_int(statement, 3)),
            cpu: sqlite3_column_double(statement, 4),
            memUsed: sqlite3_column_int64(statement, 5),
            memLimit: sqlite3_column_int64(statement, 6),
            netRx: sqlite3_column_int64(statement, 7),
            netTx: sqlite3_column_int64(statement, 8),
            blkRead: sqlite3_column_int64(statement, 9),
            blkWrite: sqlite3_column_int64(statement, 10),
            pids: Int(sqlite3_column_int(statement, 11))
        )
    }

    private func detectEvents(container: Container, previous: Sample?, ts: Int) {
        let name = container.name
        // First observation is not a state change worth a timeline entry.
        guard let previous else { return }

        if previous.running != container.isRunning {
            event(
                ts: ts, name: name,
                kind: container.isRunning ? "started" : "stopped",
                detail: container.isRunning ? "Container started" : "Container stopped"
            )
        }
        if container.restarts > previous.restarts {
            let added = container.restarts - previous.restarts
            event(
                ts: ts, name: name, kind: "restart",
                detail: "Restart count \(previous.restarts) → \(container.restarts) (+\(added))"
            )
        }
        if !previous.health.isEmpty, previous.health != container.health,
           container.health != "healthy" {
            event(
                ts: ts, name: name, kind: "health",
                detail: "Health \(previous.health) → \(container.health)"
            )
        }
    }

    private func event(ts: Int, name: String, kind: String, detail: String) {
        guard let statement = prepare(
            "INSERT INTO events(ts,name,kind,detail) VALUES(?,?,?,?)"
        ) else { return }
        defer { sqlite3_finalize(statement) }
        sqlite3_bind_int64(statement, 1, Int64(ts))
        bind(statement, 2, name)
        bind(statement, 3, kind)
        bind(statement, 4, detail)
        sqlite3_step(statement)
    }

    func addMaintenance(started: Date, finished: Date?, trigger: String, exitCode: Int, output: String) {
        queue.sync {
            guard let statement = self.prepare(
                "INSERT INTO maintenance(started,finished,trigger,exit_code,output) VALUES(?,?,?,?,?)"
            ) else { return }
            defer { sqlite3_finalize(statement) }

            sqlite3_bind_int64(statement, 1, Int64(started.timeIntervalSince1970))
            sqlite3_bind_int64(statement, 2, Int64((finished ?? started).timeIntervalSince1970))
            self.bind(statement, 3, trigger)
            sqlite3_bind_int(statement, 4, Int32(exitCode))
            // A month of apt output is not worth megabytes.
            self.bind(statement, 5, String(output.suffix(60_000)))
            sqlite3_step(statement)
        }
    }

    // MARK: Reads

    func summaries(since: Date) -> [ContainerSummary] {
        queue.sync {
            let sql = """
            SELECT name, COUNT(*), AVG(cpu), MAX(cpu), AVG(mem), MAX(mem),
                   SUM(running)
            FROM samples WHERE ts >= ? GROUP BY name ORDER BY AVG(cpu) DESC
            """
            guard let statement = prepare(sql) else { return [] }
            defer { sqlite3_finalize(statement) }
            sqlite3_bind_int64(statement, 1, Int64(since.timeIntervalSince1970))

            var result: [ContainerSummary] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                result.append(ContainerSummary(
                    name: text(statement, 0),
                    points: Int(sqlite3_column_int(statement, 1)),
                    avgCPU: sqlite3_column_double(statement, 2),
                    peakCPU: sqlite3_column_double(statement, 3),
                    avgMem: Int64(sqlite3_column_double(statement, 4)),
                    peakMem: sqlite3_column_int64(statement, 5),
                    samplesRunning: Int(sqlite3_column_int(statement, 6))
                ))
            }
            return result
        }
    }

    func series(name: String, since: Date) -> [Sample] {
        queue.sync {
            let sql = """
            SELECT ts,running,health,restarts,cpu,mem,mem_limit,net_rx,net_tx,
                   blk_read,blk_write,pids
            FROM samples WHERE name=? AND ts>=? ORDER BY ts ASC
            """
            guard let statement = prepare(sql) else { return [] }
            defer { sqlite3_finalize(statement) }
            bind(statement, 1, name)
            sqlite3_bind_int64(statement, 2, Int64(since.timeIntervalSince1970))

            var result: [Sample] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                result.append(Sample(
                    ts: Date(timeIntervalSince1970: Double(sqlite3_column_int64(statement, 0))),
                    name: name,
                    running: sqlite3_column_int(statement, 1) == 1,
                    health: text(statement, 2),
                    restarts: Int(sqlite3_column_int(statement, 3)),
                    cpu: sqlite3_column_double(statement, 4),
                    memUsed: sqlite3_column_int64(statement, 5),
                    memLimit: sqlite3_column_int64(statement, 6),
                    netRx: sqlite3_column_int64(statement, 7),
                    netTx: sqlite3_column_int64(statement, 8),
                    blkRead: sqlite3_column_int64(statement, 9),
                    blkWrite: sqlite3_column_int64(statement, 10),
                    pids: Int(sqlite3_column_int(statement, 11))
                ))
            }
            return result
        }
    }

    func events(since: Date, limit: Int = 250) -> [HistoryEvent] {
        queue.sync {
            let sql = "SELECT id,ts,name,kind,detail FROM events WHERE ts>=? ORDER BY ts DESC LIMIT ?"
            guard let statement = prepare(sql) else { return [] }
            defer { sqlite3_finalize(statement) }
            sqlite3_bind_int64(statement, 1, Int64(since.timeIntervalSince1970))
            sqlite3_bind_int(statement, 2, Int32(limit))

            var result: [HistoryEvent] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                result.append(HistoryEvent(
                    id: sqlite3_column_int64(statement, 0),
                    ts: Date(timeIntervalSince1970: Double(sqlite3_column_int64(statement, 1))),
                    name: text(statement, 2),
                    kind: text(statement, 3),
                    detail: text(statement, 4)
                ))
            }
            return result
        }
    }

    func maintenance(limit: Int = 12) -> [MaintenanceRun] {
        queue.sync {
            let sql = "SELECT id,started,finished,trigger,exit_code,output FROM maintenance ORDER BY started DESC LIMIT ?"
            guard let statement = prepare(sql) else { return [] }
            defer { sqlite3_finalize(statement) }
            sqlite3_bind_int(statement, 1, Int32(limit))

            var result: [MaintenanceRun] = []
            while sqlite3_step(statement) == SQLITE_ROW {
                let finished = sqlite3_column_int64(statement, 2)
                result.append(MaintenanceRun(
                    id: sqlite3_column_int64(statement, 0),
                    started: Date(timeIntervalSince1970: Double(sqlite3_column_int64(statement, 1))),
                    finished: finished > 0 ? Date(timeIntervalSince1970: Double(finished)) : nil,
                    trigger: text(statement, 3),
                    exitCode: Int(sqlite3_column_int(statement, 4)),
                    output: text(statement, 5)
                ))
            }
            return result
        }
    }

    func stats() -> HistoryStats {
        queue.sync {
            let samples = scalar("SELECT COUNT(*) FROM samples")
            let events = scalar("SELECT COUNT(*) FROM events")
            let oldest = scalar("SELECT MIN(ts) FROM samples")
            let attributes = try? FileManager.default.attributesOfItem(atPath: path.path)
            let size = (attributes?[.size] as? NSNumber)?.int64Value ?? 0
            return HistoryStats(
                samples: Int(samples),
                events: Int(events),
                oldest: oldest > 0 ? Date(timeIntervalSince1970: Double(oldest)) : nil,
                bytes: size
            )
        }
    }

    func latestSampleDate() -> Date? {
        queue.sync {
            let value = scalar("SELECT MAX(ts) FROM samples")
            return value > 0 ? Date(timeIntervalSince1970: Double(value)) : nil
        }
    }

    // MARK: Meta

    func meta(_ key: String) -> String? {
        queue.sync {
            guard let statement = prepare("SELECT value FROM meta WHERE key=?") else { return nil }
            defer { sqlite3_finalize(statement) }
            bind(statement, 1, key)
            guard sqlite3_step(statement) == SQLITE_ROW else { return nil }
            return text(statement, 0)
        }
    }

    func setMeta(_ key: String, _ value: String?) {
        queue.sync {
            if let value {
                guard let statement = prepare(
                    "INSERT INTO meta(key,value) VALUES(?,?) ON CONFLICT(key) DO UPDATE SET value=excluded.value"
                ) else { return }
                defer { sqlite3_finalize(statement) }
                bind(statement, 1, key)
                bind(statement, 2, value)
                sqlite3_step(statement)
            } else {
                guard let statement = prepare("DELETE FROM meta WHERE key=?") else { return }
                defer { sqlite3_finalize(statement) }
                bind(statement, 1, key)
                sqlite3_step(statement)
            }
        }
    }

    // MARK: Retention

    /// Deletes everything older than 30 days. Called at launch, hourly from
    /// record(), and after every maintenance run.
    func prune(days: Int = HistoryStore.retentionDays) {
        queue.async { self.pruneLocked(days: days) }
    }

    func pruneNow(days: Int = HistoryStore.retentionDays) -> Int {
        queue.sync {
            let cutoff = Int(Date().timeIntervalSince1970) - days * 86_400
            var removed = 0
            for table in ["samples", "events", "maintenance"] {
                let column = table == "maintenance" ? "started" : "ts"
                guard let statement = prepare("DELETE FROM \(table) WHERE \(column) < ?") else { continue }
                sqlite3_bind_int64(statement, 1, Int64(cutoff))
                sqlite3_step(statement)
                sqlite3_finalize(statement)
                removed += Int(sqlite3_changes(db))
            }
            self.optimise()
            return removed
        }
    }

    private func pruneLocked(days: Int = HistoryStore.retentionDays) {
        let cutoff = Int(Date().timeIntervalSince1970) - days * 86_400
        for table in ["samples", "events", "maintenance"] {
            let column = table == "maintenance" ? "started" : "ts"
            guard let statement = prepare("DELETE FROM \(table) WHERE \(column) < ?") else { continue }
            sqlite3_bind_int64(statement, 1, Int64(cutoff))
            sqlite3_step(statement)
            sqlite3_finalize(statement)
        }
        optimise()
    }

    private func optimise() {
        sqlite3_exec(db, "PRAGMA wal_checkpoint(TRUNCATE);", nil, nil, nil)
    }

    // MARK: SQLite helpers

    private func prepare(_ sql: String) -> OpaquePointer? {
        var statement: OpaquePointer?
        guard sqlite3_prepare_v2(db, sql, -1, &statement, nil) == SQLITE_OK else {
            NSLog("S-Info: SQL prepare failed: %@", String(cString: sqlite3_errmsg(db)))
            return nil
        }
        return statement
    }

    private func bind(_ statement: OpaquePointer?, _ index: Int32, _ value: String) {
        sqlite3_bind_text(statement, index, value, -1, SQLITE_TRANSIENT)
    }

    private func text(_ statement: OpaquePointer?, _ index: Int32) -> String {
        guard let pointer = sqlite3_column_text(statement, index) else { return "" }
        return String(cString: pointer)
    }

    private func scalar(_ sql: String) -> Int64 {
        guard let statement = prepare(sql) else { return 0 }
        defer { sqlite3_finalize(statement) }
        guard sqlite3_step(statement) == SQLITE_ROW else { return 0 }
        return sqlite3_column_int64(statement, 0)
    }
}
