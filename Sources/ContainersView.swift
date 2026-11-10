import SwiftUI

// MARK: - Container list

struct ContainersView: View {
    @ObservedObject var store: Store
    @State private var query = ""
    @State private var sort: SortMode = .cpu
    @State private var selected: String?
    @State private var hovered: String?

    enum SortMode: String, CaseIterable, Identifiable {
        case cpu = "CPU"
        case memory = "Memory"
        case name = "Name"
        case restarts = "Restarts"
        var id: String { rawValue }
    }

    var body: some View {
        Group {
            if let selected {
                ContainerDetailView(store: store, name: selected) {
                    self.selected = nil
                }
            } else {
                list
            }
        }
    }

    private var list: some View {
        VStack(spacing: 8) {
            toolbar
            if store.probe == nil {
                emptyState
            } else if filtered.isEmpty {
                VStack(spacing: 6) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 22))
                        .foregroundStyle(.tertiary)
                    Text(query.isEmpty ? "No containers" : "No containers match “\(query)”")
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                scroll
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 4)
    }

    private var toolbar: some View {
        HStack(spacing: 8) {
            HStack(spacing: 5) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.tertiary)
                TextField("Filter containers", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.primary.opacity(0.05))
            )

            Menu {
                ForEach(SortMode.allCases) { mode in
                    Button {
                        sort = mode
                    } label: {
                        if sort == mode {
                            Label(mode.rawValue, systemImage: "checkmark")
                        } else {
                            Text(mode.rawValue)
                        }
                    }
                }
            } label: {
                HStack(spacing: 3) {
                    Image(systemName: "arrow.up.arrow.down")
                        .font(.system(size: 9, weight: .semibold))
                    Text(sort.rawValue)
                        .font(.system(size: 10))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 7)
                .padding(.vertical, 5)
                .background(
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(Color.primary.opacity(0.05))
                )
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }

    private var scroll: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 12) {
                ForEach(groups, id: \.name) { group in
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 6) {
                            Text(group.name.uppercased())
                                .font(.system(size: 9, weight: .semibold))
                                .tracking(0.7)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                            Spacer()
                            Text("\(group.containers.filter(\.isRunning).count)/\(group.containers.count)")
                                .font(.system(size: 8.5, design: .monospaced))
                                .foregroundStyle(.quaternary)
                        }
                        .padding(.horizontal, 8)
                        .padding(.bottom, 2)

                        VStack(spacing: 1) {
                            ForEach(group.containers) { container in
                                row(container)
                            }
                        }
                        .padding(3)
                        .background(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.primary.opacity(0.035))
                        )
                    }
                }
            }
            .padding(.bottom, 10)
        }
    }

    private func row(_ container: Container) -> some View {
        Button {
            selected = container.name
        } label: {
            HStack(spacing: 8) {
                StatusDot(
                    color: container.isRunning
                        ? (container.healthState == .unhealthy ? Theme.red : Theme.green)
                        : Theme.gray.opacity(0.5),
                    size: 6,
                    glow: container.isRunning
                )

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(container.displayName)
                            .font(.system(size: 11.5, weight: .semibold))
                            .foregroundStyle(container.isRunning ? .primary : .secondary)
                            .lineLimit(1)

                        if !container.isRunning {
                            Pill(text: "stopped", color: Theme.gray)
                        } else if container.healthState == .unhealthy {
                            Pill(text: "unhealthy", color: Theme.red)
                        } else if container.healthState == .starting {
                            Pill(text: "starting", color: Theme.amber)
                        }
                        if container.restarts > 0 {
                            HStack(spacing: 1) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 7, weight: .bold))
                                Text("\(container.restarts)")
                                    .font(.system(size: 8, weight: .semibold, design: .monospaced))
                            }
                            .foregroundStyle(container.restarts > 2 ? Theme.amber : Theme.subtle)
                        }
                    }

                    HStack(spacing: 4) {
                        Text(container.imageShort)
                            .lineLimit(1)
                        if !container.uptime.isEmpty {
                            Text("·")
                            Text(container.uptime)
                        }
                        if !container.shortPorts.isEmpty {
                            Text("· \(container.shortPorts)")
                                .lineLimit(1)
                        }
                    }
                    .font(.system(size: 8.8, design: .monospaced))
                    .foregroundStyle(.tertiary)
                }

                Spacer(minLength: 4)

                VStack(alignment: .trailing, spacing: 2) {
                    Text(container.isRunning ? Fmt.percent(container.cpu) : "—")
                        .font(.system(size: 10.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(container.isRunning ? cpuColor(container.cpu) : Theme.subtle)
                    Text(container.isRunning ? Fmt.bytes(container.memUsed) : "—")
                        .font(.system(size: 9, design: .monospaced))
                        .foregroundStyle(.secondary)
                }
                .frame(width: 58, alignment: .trailing)

                Image(systemName: "chevron.right")
                    .font(.system(size: 7.5, weight: .semibold))
                    .foregroundStyle(.quaternary)
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 6)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(hovered == container.name ? Color.primary.opacity(0.055) : .clear)
            )
        }
        .buttonStyle(.plain)
        .onHover { inside in
            if inside {
                hovered = container.name
            } else if hovered == container.name {
                hovered = nil
            }
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: 10) {
            Spacer()
            Image(systemName: store.connection == .connecting ? "antenna.radiowaves.left.and.right" : "server.rack")
                .font(.system(size: 26))
                .foregroundStyle(.tertiary)
            switch store.connection {
            case .connecting, .idle:
                Text("Contacting \(SSHConfig.current().label)…")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                ProgressView().controlSize(.small)
            case .unreachable(let message):
                Text("Server unreachable")
                    .font(.system(size: 12, weight: .semibold))
                Text(message)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 320)
                Button("Try again") { store.refresh() }
                    .controlSize(.small)
            case .online:
                Text("No containers reported.")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var filtered: [Container] {
        let all = store.probe?.containers ?? []
        guard !query.isEmpty else { return all }
        let needle = query.lowercased()
        return all.filter { container in
            container.name.lowercased().contains(needle)
                || container.displayName.lowercased().contains(needle)
                || container.image.lowercased().contains(needle)
                || container.project.lowercased().contains(needle)
                || container.ports.lowercased().contains(needle)
        }
    }

    private var groups: [(name: String, containers: [Container])] {
        let grouped = Dictionary(grouping: filtered, by: \.stack)
        var result = grouped.map { name, items -> (name: String, containers: [Container]) in
            (name, items.sorted(by: comparator))
        }
        // Stacks keep a stable alphabetical order; the sort menu orders the
        // containers inside each stack.
        result.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        return result
    }

    private func comparator(_ a: Container, _ b: Container) -> Bool {
        switch sort {
        case .cpu: return a.cpu > b.cpu
        case .memory: return a.memUsed > b.memUsed
        case .restarts: return a.restarts > b.restarts
        case .name: return a.displayName.localizedCaseInsensitiveCompare(b.displayName) == .orderedAscending
        }
    }

}

// MARK: - Container detail

struct ContainerDetailView: View {
    @ObservedObject var store: Store
    let name: String
    var onBack: () -> Void

    @State private var samples: [Sample] = []
    @State private var mounts = ""
    @State private var logs = ""
    @State private var loadingDetail = false
    @State private var detailError: String?

    private var container: Container? {
        store.probe?.containers.first { $0.name == name }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.4)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if let container {
                        metrics(container)
                        history(container)
                        information(container)
                        tools(container)
                    } else {
                        Text("This container is no longer in the list.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 20)
                    }
                }
                .padding(14)
            }
        }
        .task(id: name) {
            samples = await store.series(
                name: name,
                since: Date().addingTimeInterval(-86_400)
            )
        }
    }

    private var header: some View {
        HStack(spacing: 8) {
            Button(action: onBack) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 11, weight: .semibold))
                    .frame(width: 18, height: 18)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 1) {
                Text(container?.displayName ?? name)
                    .font(.system(size: 13, weight: .bold))
                    .lineLimit(1)
                if let container, container.displayName != container.name {
                    Text(container.name)
                        .font(.system(size: 8.5, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if let container {
                Pill(
                    text: container.isRunning ? container.state : "stopped",
                    color: container.isRunning ? Theme.green : Theme.gray,
                    icon: container.isRunning ? "play.fill" : "stop.fill"
                )
                if container.healthState != .none {
                    Pill(
                        text: container.healthState.label,
                        color: container.healthState == .unhealthy ? Theme.red
                            : container.healthState == .starting ? Theme.amber : Theme.green,
                        icon: "heart.fill"
                    )
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 9)
    }

    private func metrics(_ container: Container) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 7) {
            MetricTile(
                label: "CPU",
                value: container.isRunning ? Fmt.percent(container.cpu) : "—",
                detail: "docker stats",
                color: container.isRunning ? cpuColor(container.cpu) : .secondary,
                fraction: nil
            )
            MetricTile(
                label: "Memory",
                value: Fmt.bytes(container.memUsed),
                detail: container.memLimit > 0
                    ? "of \(Fmt.bytes(container.memLimit)) · \(Fmt.percent(container.memoryFraction * 100))"
                    : "no limit",
                color: memoryColor(fraction: container.memoryFraction),
                fraction: container.memLimit > 0 ? container.memoryFraction : nil
            )
            MetricTile(
                label: "PIDs",
                value: "\(container.pids)",
                detail: "processes"
            )
            MetricTile(
                label: "Network",
                value: Fmt.bytes(container.netRx + container.netTx),
                detail: "rx \(Fmt.bytes(container.netRx)) · tx \(Fmt.bytes(container.netTx))"
            )
            MetricTile(
                label: "Block I/O",
                value: Fmt.bytes(container.blkRead + container.blkWrite),
                detail: "r \(Fmt.bytes(container.blkRead)) · w \(Fmt.bytes(container.blkWrite))"
            )
            MetricTile(
                label: "Restarts",
                value: "\(container.restarts)",
                detail: container.restartPolicy.isEmpty ? "no policy" : container.restartPolicy,
                color: container.restarts > 2 ? Theme.amber : .primary
            )
        }
    }

    @ViewBuilder
    private func history(_ container: Container) -> some View {
        let cpu = samples.map(\.cpu)
        let memory = samples.map { Double($0.memUsed) }

        VStack(alignment: .leading, spacing: 7) {
            SectionTitle(
                text: "Last 24 hours",
                trailing: samples.count > 1 ? "\(samples.count) points" : nil
            )
            if samples.count > 1 {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 4) {
                            Text("CPU")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("peak \(Fmt.percent(cpu.max() ?? 0))")
                                .font(.system(size: 8.5, design: .monospaced))
                                .foregroundStyle(.tertiary)
                        }
                        Sparkline(values: cpu, color: cpuColor(container.cpu))
                            .frame(height: 30)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 4) {
                            Text("Memory")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("peak \(Fmt.bytes(Int64(memory.max() ?? 0)))")
                                .font(.system(size: 8.5, design: .monospaced))
                                .foregroundStyle(.tertiary)
                        }
                        Sparkline(values: memory, color: Theme.blue, zeroBased: false)
                            .frame(height: 30)
                    }
                }
            } else {
                Text("History builds up as S-Info samples every \(Int(store.sampleInterval)) min. Nothing older than 30 days is kept.")
                    .font(.system(size: 9.5))
                    .foregroundStyle(.tertiary)
            }
        }
        .cardStyle(padding: 10)
    }

    private func information(_ container: Container) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionTitle(text: "Details")
            KeyValueRow(key: "Image", value: container.image, mono: true)
            KeyValueRow(key: "Command", value: container.command, mono: true)
            KeyValueRow(key: "Created", value: container.created)
            KeyValueRow(key: "Started", value: Fmt.dockerTime(container.startedAt))
            KeyValueRow(key: "Uptime", value: container.uptime)
            KeyValueRow(key: "Ports", value: container.shortPorts.isEmpty ? "none published" : container.shortPorts, mono: true)
            KeyValueRow(key: "Stack", value: container.stack)
            KeyValueRow(key: "Working dir", value: container.workingDir, mono: true)
            KeyValueRow(key: "Compose file", value: container.composeFile, mono: true)
            KeyValueRow(key: "Networks", value: container.networks, mono: true)
            KeyValueRow(
                key: "Restart",
                value: "\(container.restartPolicy.isEmpty ? "no" : container.restartPolicy) · \(container.restarts) restart\(container.restarts == 1 ? "" : "s")"
            )
        }
        .cardStyle(padding: 10)
    }

    private func tools(_ container: Container) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionTitle(text: "Inspect")
                Spacer()
                Button {
                    fetchDetail(container)
                } label: {
                    HStack(spacing: 3) {
                        if loadingDetail {
                            ProgressView().controlSize(.mini)
                        } else {
                            Image(systemName: "terminal").font(.system(size: 9))
                        }
                        Text(loadingDetail ? "Fetching…" : "Mounts & logs")
                            .font(.system(size: 10, weight: .medium))
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
                .disabled(loadingDetail)
            }

            if let detailError {
                Text(detailError)
                    .font(.system(size: 9.5))
                    .foregroundStyle(Theme.red)
                    .textSelection(.enabled)
            }

            if !mounts.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    Text("MOUNTS")
                        .font(.system(size: 8, weight: .semibold))
                        .tracking(0.6)
                        .foregroundStyle(.tertiary)
                    ForEach(Array(mounts.split(separator: "\n").enumerated()), id: \.offset) { _, line in
                        Text(String(line))
                            .font(.system(size: 8.8, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                    }
                }
            }

            if !logs.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    Text("LAST 80 LOG LINES")
                        .font(.system(size: 8, weight: .semibold))
                        .tracking(0.6)
                        .foregroundStyle(.tertiary)
                    ScrollView {
                        Text(logs)
                            .font(.system(size: 8.5, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 150)
                }
            }

            if mounts.isEmpty, logs.isEmpty, !loadingDetail {
                Text("Pulls the container's mounts and its last 80 log lines from the server on demand.")
                    .font(.system(size: 9.5))
                    .foregroundStyle(.tertiary)
            }
        }
        .cardStyle(padding: 10)
    }

    private func fetchDetail(_ container: Container) {
        loadingDetail = true
        detailError = nil
        let quoted = shellQuote(container.name)
        let script = """
        echo '###MOUNTS'
        docker inspect -f '{{range .Mounts}}{{.Type}}  {{.Source}} -> {{.Destination}}  (rw={{.RW}}){{"\\n"}}{{end}}' \(quoted) 2>&1
        echo '###LOGS'
        docker logs --tail 80 --timestamps \(quoted) 2>&1
        """

        Task {
            do {
                let output = try await SSH.run(script, timeout: 30)
                let lines = output.components(separatedBy: .newlines)
                var section = ""
                var mountLines: [String] = []
                var logLines: [String] = []
                for line in lines {
                    if line == "###MOUNTS" { section = "mounts"; continue }
                    if line == "###LOGS" { section = "logs"; continue }
                    if section == "mounts" { mountLines.append(line) }
                    if section == "logs" { logLines.append(stripANSI(line)) }
                }
                mounts = mountLines.filter { !$0.isEmpty }.joined(separator: "\n")
                logs = logLines.suffix(80).joined(separator: "\n")
            } catch {
                detailError = error.localizedDescription
            }
            loadingDetail = false
        }
    }
}

// MARK: - Helpers

func shellQuote(_ value: String) -> String {
    "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
}

func stripANSI(_ value: String) -> String {
    value.replacingOccurrences(
        of: "\u{001B}\\[[0-9;]*[A-Za-z]",
        with: "",
        options: .regularExpression
    )
}
