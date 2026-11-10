import SwiftUI

// MARK: - Container list

struct ContainersView: View {
    @ObservedObject var store: Store
    @State private var query = ""
    @State private var sort: SortMode = .cpu
    @State private var selected: String?
    @State private var hovered: String?

    @AppStorage("serverfo.showRowImage") private var showImage = true
    @AppStorage("serverfo.showRowUptime") private var showUptime = true
    @AppStorage("serverfo.showRowPorts") private var showPorts = true
    @AppStorage("serverfo.showRowHealth") private var showHealth = true
    @AppStorage("serverfo.showRowRestarts") private var showRestarts = true
    @AppStorage("serverfo.showRowCPU") private var showCPU = true
    @AppStorage("serverfo.showRowMemory") private var showMemory = true
    @AppStorage("serverfo.showRowStackCounts") private var showStackCounts = true

    enum SortMode: String, CaseIterable, Identifiable {
        case cpu = "CPU"
        case memory = "Memory"
        case name = "Name"
        case restarts = "Restarts"
        var id: String { rawValue }

        var icon: String {
            switch self {
            case .cpu: return "cpu"
            case .memory: return "memorychip"
            case .name: return "textformat.abc"
            case .restarts: return "arrow.clockwise"
            }
        }
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
                VStack(spacing: 8) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                        .font(.system(size: 24, weight: .light))
                        .foregroundStyle(Theme.accentText.opacity(0.7))
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
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.accentText.opacity(0.85))
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
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Theme.surfaceSunken)
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(Theme.stroke, lineWidth: 0.8)
                    )
            )

            Menu {
                ForEach(SortMode.allCases) { mode in
                    Button {
                        withAnimation(.easeOut(duration: 0.18)) { sort = mode }
                    } label: {
                        if sort == mode {
                            Label(mode.rawValue, systemImage: "checkmark")
                        } else {
                            Label(mode.rawValue, systemImage: mode.icon)
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: sort.icon)
                        .font(.system(size: 9, weight: .semibold))
                    Text(sort.rawValue)
                        .font(.system(size: 10, weight: .medium))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(Theme.surfaceSunken)
                        .overlay(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .strokeBorder(Theme.stroke, lineWidth: 0.8)
                        )
                )
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
        }
    }

    private var scroll: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 13) {
                ForEach(groups, id: \.name) { group in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "shippingbox.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(Theme.accentText.opacity(0.8))
                            Text(group.name.uppercased())
                                .font(.system(size: 9, weight: .bold, design: .rounded))
                                .tracking(0.9)
                                .foregroundStyle(.tertiary)
                                .lineLimit(1)
                            Spacer()
                            if showStackCounts {
                                Text("\(group.containers.filter(\.isRunning).count)/\(group.containers.count)")
                                    .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
                                    .foregroundStyle(.tertiary)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(Capsule().fill(Theme.surfaceSunken))
                            }
                        }
                        .padding(.horizontal, 3)

                        VStack(spacing: 3) {
                            ForEach(group.containers) { container in
                                row(container)
                            }
                        }
                    }
                }
            }
            .padding(.bottom, 10)
        }
    }

    private func row(_ container: Container) -> some View {
        let active = hovered == container.name

        return Button {
            selected = container.name
        } label: {
            HStack(spacing: 9) {
                ZStack {
                    if container.isRunning {
                        Circle()
                            .fill((container.healthState == .unhealthy ? Theme.red : Theme.green).opacity(0.16))
                            .frame(width: 18, height: 18)
                    }
                    StatusDot(
                        color: container.isRunning
                            ? (container.healthState == .unhealthy ? Theme.red : Theme.green)
                            : Theme.gray.opacity(0.55),
                        size: 7,
                        glow: container.isRunning
                    )
                }
                .frame(width: 18)

                VStack(alignment: .leading, spacing: 2.5) {
                    HStack(spacing: 5) {
                        Text(container.displayName)
                            .font(.system(size: 11.8, weight: .semibold))
                            .foregroundStyle(container.isRunning ? .primary : .secondary)
                            .lineLimit(1)

                        if !container.isRunning {
                            Pill(text: "stopped", color: Theme.gray)
                        } else if container.healthState == .unhealthy, showHealth {
                            Pill(text: "unhealthy", color: Theme.red)
                        } else if container.healthState == .starting, showHealth {
                            Pill(text: "starting", color: Theme.amber)
                        }

                        if showRestarts, container.restarts > 0 {
                            HStack(spacing: 1.5) {
                                Image(systemName: "arrow.clockwise")
                                    .font(.system(size: 7, weight: .bold))
                                Text("\(container.restarts)")
                                    .font(.system(size: 8, weight: .bold, design: .monospaced))
                            }
                            .foregroundStyle(container.restarts > 2 ? Theme.amber : Theme.subtle)
                        }
                    }

                    if showImage || showUptime || showPorts {
                        HStack(spacing: 4) {
                            if showImage {
                                Text(container.imageShort)
                                    .lineLimit(1)
                            }
                            if showUptime, !container.uptime.isEmpty {
                                if showImage { Text("·") }
                                Text(container.uptime)
                            }
                            if showPorts, !container.shortPorts.isEmpty {
                                if showImage || showUptime { Text("·") }
                                Text(container.shortPorts)
                                    .lineLimit(1)
                            }
                        }
                        .font(.system(size: 8.8, design: .monospaced))
                        .foregroundStyle(.tertiary)
                    }
                }

                Spacer(minLength: 4)

                if showCPU || showMemory {
                    VStack(alignment: .trailing, spacing: 2.5) {
                        if showCPU {
                            Text(container.isRunning ? Fmt.percent(container.cpu) : "—")
                                .font(.system(size: 10.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(container.isRunning ? cpuColor(container.cpu) : Theme.gray)
                        }
                        if showMemory {
                            Text(container.isRunning ? Fmt.bytes(container.memUsed) : "—")
                                .font(.system(size: 9, design: .monospaced))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(width: 58, alignment: .trailing)
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 7.5, weight: .bold))
                    .foregroundStyle(active ? Theme.accentText : Color.primary.opacity(0.2))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 7)
            .contentShape(Rectangle())
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(active ? Theme.surfaceHigh : Theme.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(
                                active ? Theme.accent.opacity(0.35) : Theme.stroke,
                                lineWidth: active ? 1 : 0.8
                            )
                    )
            )
            .shadow(color: .black.opacity(active ? 0.12 : 0), radius: 8, y: 3)
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
        VStack(spacing: 11) {
            Spacer()
            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.10))
                    .frame(width: 64, height: 64)
                Image(systemName: store.connection == .connecting ? "antenna.radiowaves.left.and.right" : "server.rack")
                    .font(.system(size: 26, weight: .light))
                    .foregroundStyle(Theme.accentText.opacity(0.85))
            }
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
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accentText)
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

    @AppStorage("serverfo.showDetailMetrics") private var showMetrics = true
    @AppStorage("serverfo.showDetailCharts") private var showCharts = true
    @AppStorage("serverfo.showDetailInspect") private var showInspect = true

    private var container: Container? {
        store.probe?.containers.first { $0.name == name }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: 11) {
                    if let container {
                        hero(container)
                        if showMetrics { metrics(container) }
                        if showCharts { history(container) }
                        information(container)
                        if showInspect { tools(container) }
                    } else {
                        Text("This container is no longer in the list.")
                            .font(.system(size: 11))
                            .foregroundStyle(.secondary)
                            .padding(.vertical, 20)
                    }
                }
                .padding(13)
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
            GlassIconButton(icon: "chevron.left", help: "Back to containers", action: onBack)
            Text("Container")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.tertiary)
                .tracking(0.6)
            Spacer()
            if let container {
                Pill(
                    text: container.isRunning ? "running" : "stopped",
                    color: container.isRunning ? Theme.green : Theme.gray,
                    icon: container.isRunning ? "play.fill" : "stop.fill",
                    glass: true
                )
                if container.healthState != .none {
                    Pill(
                        text: container.healthState.label,
                        color: container.healthState == .unhealthy ? Theme.red
                            : container.healthState == .starting ? Theme.amber : Theme.green,
                        icon: "heart.fill",
                        glass: true
                    )
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 4)
    }

    private func hero(_ container: Container) -> some View {
        HStack(spacing: 11) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Theme.accentGradient)
                    .opacity(0.16)
                    .frame(width: 46, height: 46)
                Image(systemName: "shippingbox.fill")
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Theme.accentText)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(container.displayName)
                    .font(.system(size: 16, weight: .heavy, design: .rounded))
                    .lineLimit(1)
                if container.displayName != container.name {
                    Text(container.name)
                        .font(.system(size: 8.8, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                }
                Text(container.imageShort)
                    .font(.system(size: 9.5, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 2) {
                Text(container.uptime.isEmpty ? "—" : container.uptime)
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.secondary)
                Text(container.stack)
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        }
        .cardStyle(padding: 11)
    }

    private func metrics(_ container: Container) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 7) {
            MetricTile(
                label: "CPU",
                value: container.isRunning ? Fmt.percent(container.cpu) : "—",
                detail: "docker stats",
                color: container.isRunning ? cpuColor(container.cpu) : .secondary,
                fraction: nil,
                icon: "cpu"
            )
            MetricTile(
                label: "Memory",
                value: Fmt.bytes(container.memUsed),
                detail: container.memLimit > 0
                    ? "of \(Fmt.bytes(container.memLimit)) · \(Fmt.percent(container.memoryFraction * 100))"
                    : "no limit",
                color: memoryColor(fraction: container.memoryFraction),
                fraction: container.memLimit > 0 ? container.memoryFraction : nil,
                icon: "memorychip"
            )
            MetricTile(
                label: "PIDs",
                value: "\(container.pids)",
                detail: "processes",
                icon: "list.number"
            )
            MetricTile(
                label: "Network",
                value: Fmt.bytes(container.netRx + container.netTx),
                detail: "rx \(Fmt.bytes(container.netRx)) · tx \(Fmt.bytes(container.netTx))",
                icon: "network"
            )
            MetricTile(
                label: "Block I/O",
                value: Fmt.bytes(container.blkRead + container.blkWrite),
                detail: "r \(Fmt.bytes(container.blkRead)) · w \(Fmt.bytes(container.blkWrite))",
                icon: "internaldrive"
            )
            MetricTile(
                label: "Restarts",
                value: "\(container.restarts)",
                detail: container.restartPolicy.isEmpty ? "no policy" : container.restartPolicy,
                color: container.restarts > 2 ? Theme.amber : .primary,
                icon: "arrow.clockwise"
            )
        }
    }

    @ViewBuilder
    private func history(_ container: Container) -> some View {
        let cpu = samples.map(\.cpu)
        let memory = samples.map { Double($0.memUsed) }

        VStack(alignment: .leading, spacing: 8) {
            SectionTitle(
                text: "Last 24 hours",
                trailing: samples.count > 1 ? "\(samples.count) points" : nil
            )
            if samples.count > 1 {
                HStack(spacing: 12) {
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
                            .frame(height: 32)
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
                        Sparkline(values: memory, color: Theme.violetText, zeroBased: false)
                            .frame(height: 32)
                    }
                }
            } else {
                Text("History builds up as Server-Fo samples every \(Int(store.sampleInterval / 60)) min. Nothing older than 30 days is kept.")
                    .font(.system(size: 9.5))
                    .foregroundStyle(.tertiary)
            }
        }
        .cardStyle(padding: 11)
    }

    private func information(_ container: Container) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionTitle(text: "Details")
            KeyValueRow(key: "State", value: container.state)
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
        .cardStyle(padding: 11)
    }

    private func tools(_ container: Container) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                SectionTitle(text: "Inspect")
                Spacer()
                Button {
                    fetchDetail(container)
                } label: {
                    HStack(spacing: 4) {
                        if loadingDetail {
                            ProgressView().controlSize(.mini)
                        } else {
                            Image(systemName: "terminal.fill").font(.system(size: 9))
                        }
                        Text(loadingDetail ? "Fetching…" : "Mounts & logs")
                            .font(.system(size: 10, weight: .semibold))
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(Theme.accentText)
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
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .tracking(0.7)
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
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .tracking(0.7)
                        .foregroundStyle(.tertiary)
                    ScrollView {
                        Text(logs)
                            .font(.system(size: 8.5, design: .monospaced))
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: 150)
                    .padding(6)
                    .background(
                        RoundedRectangle(cornerRadius: 7, style: .continuous)
                            .fill(Theme.surfaceSunken)
                    )
                }
            }

            if mounts.isEmpty, logs.isEmpty, !loadingDetail {
                Text("Pulls the container's mounts and its last 80 log lines from the server on demand.")
                    .font(.system(size: 9.5))
                    .foregroundStyle(.tertiary)
            }
        }
        .cardStyle(padding: 11)
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
