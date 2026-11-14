import Foundation

// MARK: - Containers

enum HealthState: String {
    case none, starting, healthy, unhealthy

    var label: String {
        switch self {
        case .none: return "no check"
        case .starting: return "starting"
        case .healthy: return "healthy"
        case .unhealthy: return "unhealthy"
        }
    }
}

struct Container: Identifiable, Hashable {
    let name: String
    var image = ""
    var command = ""
    var state = "unknown"
    var status = ""
    var health = ""
    var uptime = ""
    var created = ""
    var ports = ""
    var networks = ""
    var project = ""
    var service = ""
    var workingDir = ""
    var composeFile = ""
    var restartPolicy = ""
    var restarts = 0
    var cpu = 0.0
    var memUsed: Int64 = 0
    var memLimit: Int64 = 0
    var memPerc = 0.0
    var netRx: Int64 = 0
    var netTx: Int64 = 0
    var blkRead: Int64 = 0
    var blkWrite: Int64 = 0
    var pids = 0
    var startedAt = ""

    var id: String { name }
    var isRunning: Bool { state.lowercased() == "running" }

    /// Compose gives every replica a project prefix; the service name is the
    /// part a person recognises.
    var displayName: String { service.isEmpty ? name : service }
    var stack: String { project.isEmpty ? "Standalone" : project }

    var healthState: HealthState {
        switch health.lowercased() {
        case "healthy": return .healthy
        case "unhealthy": return .unhealthy
        case "starting": return .starting
        default: return .none
        }
    }

    var memoryFraction: Double {
        guard memLimit > 0 else { return 0 }
        return min(1, Double(memUsed) / Double(memLimit))
    }

    /// Docker prints every published binding twice, once for IPv4 and once for
    /// IPv6, and prefixes the host address. A compact "host→container" pair is
    /// what belongs in a row this narrow.
    var shortPorts: String {
        guard !ports.isEmpty else { return "" }
        var seen = Set<String>()
        var result: [String] = []

        for piece in ports.split(separator: ",") {
            let trimmed = piece.trimmingCharacters(in: .whitespaces)
            let dedupeKey = trimmed
                .replacingOccurrences(of: "0.0.0.0:", with: "")
                .replacingOccurrences(of: "[::]:", with: "")
            if trimmed.hasPrefix("[::]"), seen.contains(dedupeKey) { continue }
            seen.insert(dedupeKey)

            guard let arrow = trimmed.range(of: "->") else {
                result.append(trimmed)
                continue
            }
            var host = String(trimmed[..<arrow.lowerBound])
            if let colon = host.lastIndex(of: ":") {
                host = String(host[host.index(after: colon)...])
            }
            var container = String(trimmed[arrow.upperBound...])
            if let slash = container.firstIndex(of: "/") {
                container = String(container[..<slash])
            }
            result.append(host == container ? host : "\(host)→\(container)")
        }

        var unique: [String] = []
        for item in result where !unique.contains(item) { unique.append(item) }
        return unique.joined(separator: ", ")
    }

    var imageShort: String {
        // Drop the registry and digest noise, keep the useful tag.
        var value = image
        if let at = value.firstIndex(of: "@") { value = String(value[..<at]) }
        if let slash = value.lastIndex(of: "/") { value = String(value[value.index(after: slash)...]) }
        return value
    }
}

struct Probe {
    var hostname = ""
    var os = ""
    var kernel = ""
    var dockerVersion = ""
    var uptimeSeconds = 0
    var rebootRequired = false
    var aptUpgradable: [String] = []
    var containers: [Container] = []
    var fetchedAt = Date()

    // Host vitals for the floating widget. Kept out of the main panel by
    // design; the dynamic island owns the always-on system view.
    var ramTotal: Int64 = 0
    var ramAvailable: Int64 = 0
    var cpuPercent: Double = 0
    var cpuCores = 0
    var load1: Double = 0
    var load5: Double = 0
    var load15: Double = 0
    var diskTotal: Int64 = 0
    var diskUsed: Int64 = 0

    var ramUsed: Int64 { max(0, ramTotal - ramAvailable) }
    var ramPercent: Double {
        guard ramTotal > 0 else { return 0 }
        return min(100, Double(ramUsed) / Double(ramTotal) * 100)
    }
    var diskPercent: Double {
        guard diskTotal > 0 else { return 0 }
        return min(100, Double(diskUsed) / Double(diskTotal) * 100)
    }

    var running: Int { containers.filter(\.isRunning).count }
    var stopped: Int { containers.filter { !$0.isRunning }.count }
    var unhealthy: Int { containers.filter { $0.isRunning && $0.healthState == .unhealthy }.count }
    var totalRestarts: Int { containers.reduce(0) { $0 + $1.restarts } }

    var stacks: [(name: String, containers: [Container])] {
        let grouped = Dictionary(grouping: containers, by: \.stack)
        return grouped
            .map { (name: $0.key, containers: $0.value.sorted { $0.displayName < $1.displayName }) }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}

// MARK: - Parsing

enum ProbeParser {
    static func parse(_ text: String) -> Probe {
        var probe = Probe()
        var meta: [String: String] = [:]
        var psLines: [String] = []
        var statLines: [String] = []
        var inspectLines: [String] = []
        var apt: [String] = []
        var section = ""

        for raw in text.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(raw).trimmingCharacters(in: .whitespacesAndNewlines)
            if line.hasPrefix("###") {
                section = String(line.dropFirst(3))
                continue
            }
            guard !line.isEmpty else { continue }
            switch section {
            case "META":
                if let split = line.firstIndex(of: "=") {
                    meta[String(line[..<split])] = String(line[line.index(after: split)...])
                }
            case "APT":
                apt.append(line)
            case "PS":
                psLines.append(line)
            case "STATS":
                statLines.append(line)
            case "INSPECT":
                inspectLines.append(line)
            default:
                break
            }
        }

        probe.hostname = meta["host"] ?? ""
        probe.os = meta["os"] ?? ""
        probe.kernel = meta["kernel"] ?? ""
        probe.dockerVersion = meta["docker"] ?? ""
        probe.uptimeSeconds = Int(meta["uptime"] ?? "") ?? 0
        probe.rebootRequired = meta["reboot"] == "1"
        probe.aptUpgradable = apt

        func kilobytes(_ key: String) -> Int64 {
            (Int64(meta[key] ?? "") ?? 0) * 1_024
        }
        probe.ramTotal = kilobytes("ram_total")
        probe.ramAvailable = kilobytes("ram_available")
        probe.cpuPercent = Double(meta["cpu"] ?? "") ?? 0
        probe.cpuCores = Int(meta["cores"] ?? "") ?? 0
        probe.diskTotal = kilobytes("disk_total")
        probe.diskUsed = kilobytes("disk_used")

        let loads = (meta["load"] ?? "").split(separator: " ").compactMap { Double($0) }
        if loads.count >= 3 {
            probe.load1 = loads[0]
            probe.load5 = loads[1]
            probe.load15 = loads[2]
        }

        var byName: [String: Container] = [:]
        var order: [String] = []

        for line in psLines {
            guard let object = json(line) else { continue }
            let name = string(object["Names"])
            guard !name.isEmpty else { continue }

            var container = Container(name: name)
            container.image = string(object["Image"])
            container.command = string(object["Command"])
            container.state = string(object["State"])
            container.status = string(object["Status"])
            container.health = string(object["HealthStatus"])
            container.uptime = string(object["RunningFor"])
            container.created = string(object["CreatedAt"])
            container.ports = string(object["Ports"])
            container.networks = string(object["Networks"])

            if let labels = object["Labels"] as? String {
                let map = parseLabels(labels)
                container.project = map["com.docker.compose.project"] ?? ""
                container.service = map["com.docker.compose.service"] ?? ""
                container.workingDir = map["com.docker.compose.project.working_dir"] ?? ""
                container.composeFile = map["com.docker.compose.project.config_files"] ?? ""
            }

            byName[name] = container
            order.append(name)
        }

        for line in statLines {
            guard let object = json(line) else { continue }
            let name = string(object["Name"])
            guard var container = byName[name] else { continue }

            container.cpu = percent(string(object["CPUPerc"]))
            container.memPerc = percent(string(object["MemPerc"]))
            container.pids = Int(string(object["PIDs"])) ?? 0

            // Only the used figure belongs to the container. The second half
            // of MemUsage is host RAM, which this app deliberately does not
            // show; a real per-container limit comes from docker inspect.
            container.memUsed = pair(string(object["MemUsage"])).0

            let network = pair(string(object["NetIO"]))
            container.netRx = network.0
            container.netTx = network.1

            let block = pair(string(object["BlockIO"]))
            container.blkRead = block.0
            container.blkWrite = block.1

            byName[name] = container
        }

        for line in inspectLines {
            let parts = line.split(separator: "|", omittingEmptySubsequences: false).map(String.init)
            guard parts.count >= 5 else { continue }
            var name = parts[0]
            if name.hasPrefix("/") { name.removeFirst() }
            guard var container = byName[name] else { continue }
            container.restarts = Int(parts[1]) ?? 0
            container.restartPolicy = parts[2]
            container.startedAt = parts[4]
            if container.memLimit == 0 {
                container.memLimit = Int64(parts[3]) ?? 0
            }
            byName[name] = container
        }

        probe.containers = order.compactMap { byName[$0] }
        probe.fetchedAt = Date()
        return probe
    }

    static func json(_ line: String) -> [String: Any]? {
        guard let data = line.data(using: .utf8),
              let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any]
        else { return nil }
        return object
    }

    static func string(_ value: Any?) -> String {
        if let value = value as? String { return value }
        if let value = value as? NSNumber { return value.stringValue }
        return ""
    }

    static func parseLabels(_ raw: String) -> [String: String] {
        var map: [String: String] = [:]
        for piece in raw.split(separator: ",") {
            let text = String(piece)
            guard let equals = text.firstIndex(of: "=") else { continue }
            map[String(text[..<equals])] = String(text[text.index(after: equals)...])
        }
        return map
    }

    static func percent(_ raw: String) -> Double {
        Double(raw.replacingOccurrences(of: "%", with: "").trimmingCharacters(in: .whitespaces)) ?? 0
    }

    /// "12.3MiB / 6.7GiB" → (12.3 MiB, 6.7 GiB) in bytes.
    static func pair(_ raw: String) -> (Int64, Int64) {
        let pieces = raw.split(separator: "/").map { $0.trimmingCharacters(in: .whitespaces) }
        guard pieces.count == 2 else { return (0, 0) }
        return (bytes(pieces[0]), bytes(pieces[1]))
    }

    static func bytes(_ raw: String) -> Int64 {
        let text = raw.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return 0 }

        var number = ""
        var unit = ""
        for character in text {
            if character.isNumber || character == "." {
                if unit.isEmpty {
                    number.append(character)
                    continue
                }
            }
            unit.append(character)
        }
        guard let value = Double(number) else { return 0 }

        let multiplier: Double
        switch unit.lowercased() {
        case "", "b": multiplier = 1
        case "kb": multiplier = 1_000
        case "kib": multiplier = 1_024
        case "mb": multiplier = 1_000_000
        case "mib": multiplier = 1_048_576
        case "gb": multiplier = 1_000_000_000
        case "gib": multiplier = 1_073_741_824
        case "tb": multiplier = 1_000_000_000_000
        case "tib": multiplier = 1_099_511_627_776
        default: multiplier = 1
        }
        return Int64(value * multiplier)
    }
}

// MARK: - Formatting

enum Fmt {
    static func bytes(_ value: Int64) -> String {
        if value <= 0 { return "0 B" }
        let units: [(String, Double)] = [
            ("TiB", 1_099_511_627_776), ("GiB", 1_073_741_824),
            ("MiB", 1_048_576), ("KiB", 1_024),
        ]
        for (name, size) in units where Double(value) >= size {
            return String(format: "%.1f %@", Double(value) / size, name)
        }
        return "\(value) B"
    }

    static func percent(_ value: Double) -> String {
        if value <= 0 { return "0%" }
        if value < 0.1 { return String(format: "%.2f%%", value) }
        if value < 10 { return String(format: "%.1f%%", value) }
        return String(format: "%.0f%%", value)
    }

    static func uptime(_ seconds: Int) -> String {
        guard seconds > 0 else { return "—" }
        let days = seconds / 86_400
        let hours = (seconds % 86_400) / 3_600
        if days > 0 { return "\(days)d \(hours)h" }
        let minutes = (seconds % 3_600) / 60
        return hours > 0 ? "\(hours)h \(minutes)m" : "\(minutes)m"
    }

    static func relative(_ date: Date?) -> String {
        guard let date else { return "never" }
        let seconds = Int(Date().timeIntervalSince(date))
        if seconds < 5 { return "just now" }
        if seconds < 60 { return "\(seconds)s ago" }
        if seconds < 3_600 { return "\(seconds / 60)m ago" }
        if seconds < 86_400 { return "\(seconds / 3_600)h ago" }
        return "\(seconds / 86_400)d ago"
    }

    static func dockerTime(_ raw: String) -> String {
        guard !raw.isEmpty, !raw.hasPrefix("0001") else { return "—" }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: raw) { return dateTime(date) }
        formatter.formatOptions = [.withInternetDateTime]
        if let date = formatter.date(from: raw) { return dateTime(date) }
        return raw
    }

    static func dateTime(_ date: Date?) -> String {
        guard let date else { return "never" }
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM yyyy, HH:mm"
        return formatter.string(from: date)
    }

    static func shortDate(_ date: Date?) -> String {
        guard let date else { return "—" }
        let formatter = DateFormatter()
        formatter.dateFormat = "d MMM, HH:mm"
        return formatter.string(from: date)
    }

    static func duration(_ seconds: TimeInterval) -> String {
        let total = Int(seconds.rounded())
        if total < 60 { return "\(total)s" }
        return "\(total / 60)m \(total % 60)s"
    }

    static func days(_ interval: TimeInterval) -> String {
        let days = interval / 86_400
        if days < 1 { return "\(max(0, Int((interval / 3_600).rounded())))h" }
        return String(format: "%.0fd", days)
    }
}
