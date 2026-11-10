import SwiftUI

struct HistoryView: View {
    @ObservedObject var store: Store

    enum Window: String, CaseIterable, Identifiable {
        case day = "24h"
        case week = "7d"
        case month = "30d"

        var id: String { rawValue }
        var seconds: TimeInterval {
            switch self {
            case .day: return 86_400
            case .week: return 7 * 86_400
            case .month: return 30 * 86_400
            }
        }
    }

    @State private var window: Window = .day
    @State private var summaries: [ContainerSummary] = []
    @State private var events: [HistoryEvent] = []
    @State private var expanded: Set<String> = []
    @State private var series: [String: [Sample]] = [:]
    @State private var loading = false
    @State private var loaded = false

    var body: some View {
        VStack(spacing: 8) {
            toolbar
            if loading && !loaded {
                VStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Reading history…")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        containersCard
                        eventsCard
                        retentionCard
                    }
                    .padding(.horizontal, 12)
                    .padding(.bottom, 12)
                }
            }
        }
        .padding(.top, 8)
        .task(id: window) { await load() }
    }

    private var toolbar: some View {
        HStack(spacing: 6) {
            HStack(spacing: 2) {
                ForEach(Window.allCases) { item in
                    Button {
                        window = item
                    } label: {
                        Text(item.rawValue)
                            .font(.system(size: 10, weight: window == item ? .semibold : .regular))
                            .foregroundStyle(window == item ? .primary : .secondary)
                            .padding(.horizontal, 9)
                            .padding(.vertical, 3)
                            .background(
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(window == item ? Color.primary.opacity(0.1) : .clear)
                            )
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(2)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Color.primary.opacity(0.045))
            )

            Spacer()

            if loading {
                ProgressView().controlSize(.mini)
            }
            Text("\(summaries.reduce(0) { $0 + $1.points }) points")
                .font(.system(size: 9, design: .monospaced))
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 12)
    }

    private var containersCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionTitle(text: "Container usage", trailing: window.rawValue)

            if summaries.isEmpty {
                Text("No samples in this window yet. S-Info records one sample every \(Int(store.sampleInterval)) minutes while the panel is refreshing.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 6)
            } else {
                HStack(spacing: 6) {
                    Text("Container")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("CPU")
                        .frame(width: 44, alignment: .trailing)
                    Text("PEAK")
                        .frame(width: 44, alignment: .trailing)
                    Text("MEM")
                        .frame(width: 56, alignment: .trailing)
                    Text("UP")
                        .frame(width: 34, alignment: .trailing)
                }
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 4)

                VStack(spacing: 1) {
                    ForEach(summaries.prefix(40), id: \.name) { summary in
                        summaryRow(summary)
                    }
                }
            }
        }
        .cardStyle(padding: 10)
    }

    private func summaryRow(_ summary: ContainerSummary) -> some View {
        let isOpen = expanded.contains(summary.name)
        let runFraction = summary.points > 0
            ? Double(summary.samplesRunning) / Double(summary.points)
            : 0

        return VStack(spacing: 0) {
            Button {
                toggle(summary.name)
            } label: {
                HStack(spacing: 6) {
                    HStack(spacing: 4) {
                        Image(systemName: isOpen ? "chevron.down" : "chevron.right")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(.quaternary)
                            .frame(width: 8)
                        Text(displayName(summary.name))
                            .font(.system(size: 10.5, weight: .medium))
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    Text(Fmt.percent(summary.avgCPU))
                        .font(.system(size: 9.5, design: .monospaced))
                        .foregroundStyle(cpuColor(summary.avgCPU))
                        .frame(width: 44, alignment: .trailing)
                    Text(Fmt.percent(summary.peakCPU))
                        .font(.system(size: 9.5, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 44, alignment: .trailing)
                    Text(Fmt.bytes(summary.avgMem))
                        .font(.system(size: 9.5, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 56, alignment: .trailing)
                    Text(Fmt.percent(runFraction * 100))
                        .font(.system(size: 9.5, design: .monospaced))
                        .foregroundStyle(runFraction > 0.99 ? Theme.green : Theme.amber)
                        .frame(width: 34, alignment: .trailing)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 5)
                .contentShape(Rectangle())
                .background(
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(isOpen ? Color.primary.opacity(0.04) : .clear)
                )
            }
            .buttonStyle(.plain)

            if isOpen {
                expandedChart(summary.name)
                    .padding(.horizontal, 4)
                    .padding(.top, 4)
                    .padding(.bottom, 6)
            }
        }
    }

    @ViewBuilder
    private func expandedChart(_ name: String) -> some View {
        let points = series[name] ?? []
        if points.count < 2 {
            HStack(spacing: 5) {
                ProgressView().controlSize(.mini)
                Text("Loading samples…")
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .frame(height: 36)
        } else {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("CPU")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.tertiary)
                    Sparkline(values: points.map(\.cpu), color: Theme.accent)
                        .frame(height: 28)
                    Text("\(points.count) samples · \(Fmt.shortDate(points.first?.ts)) → \(Fmt.shortDate(points.last?.ts))")
                        .font(.system(size: 7.5, design: .monospaced))
                        .foregroundStyle(.quaternary)
                        .lineLimit(1)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("MEMORY")
                        .font(.system(size: 8, weight: .semibold))
                        .foregroundStyle(.tertiary)
                    Sparkline(values: points.map { Double($0.memUsed) }, color: Theme.blue, zeroBased: false)
                        .frame(height: 28)
                    Text("peak \(Fmt.bytes(points.map(\.memUsed).max() ?? 0))")
                        .font(.system(size: 7.5, design: .monospaced))
                        .foregroundStyle(.quaternary)
                }
            }
        }
    }

    private var eventsCard: some View {
        VStack(alignment: .leading, spacing: 6) {
            SectionTitle(text: "State changes", trailing: "\(events.count)")

            if events.isEmpty {
                Text("No start, stop, restart or health changes recorded in this window.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 4)
            } else {
                VStack(spacing: 0) {
                    ForEach(events.prefix(80)) { event in
                        HStack(alignment: .top, spacing: 6) {
                            Image(systemName: eventIcon(event.kind))
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(eventColor(event.kind))
                                .frame(width: 12)
                                .padding(.top, 1)
                            VStack(alignment: .leading, spacing: 1) {
                                HStack(spacing: 4) {
                                    Text(displayName(event.name))
                                        .font(.system(size: 10, weight: .medium))
                                        .lineLimit(1)
                                    Text(event.kind)
                                        .font(.system(size: 8))
                                        .foregroundStyle(.tertiary)
                                    Spacer(minLength: 0)
                                    Text(Fmt.shortDate(event.ts))
                                        .font(.system(size: 8, design: .monospaced))
                                        .foregroundStyle(.quaternary)
                                }
                                Text(event.detail)
                                    .font(.system(size: 8.5))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                        }
                        .padding(.vertical, 3)
                        .padding(.horizontal, 4)
                        if event.id != events.prefix(80).last?.id {
                            Divider().opacity(0.25)
                        }
                    }
                }
            }
        }
        .cardStyle(padding: 10)
    }

    private var retentionCard: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 12))
                .foregroundStyle(Theme.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("30-day retention")
                    .font(.system(size: 10.5, weight: .semibold))
                Text("Samples, state changes and upgrade logs older than 30 days are deleted automatically. History lives on this Mac in ~/Library/Application Support/S-Info/history.sqlite, not on the server.")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let stats = store.historyStats {
                    Text("\(stats.samples) samples · \(stats.events) events · \(Fmt.bytes(stats.bytes)) · oldest \(Fmt.relative(stats.oldest))")
                        .font(.system(size: 8.5, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 1)
                }
            }
        }
        .cardStyle(padding: 10)
    }

    private func load() async {
        loading = true
        let since = Date().addingTimeInterval(-window.seconds)
        async let freshSummaries = store.summaries(since: since)
        async let freshEvents = store.events(since: since)
        summaries = await freshSummaries
        events = await freshEvents
        expanded = []
        series = [:]
        loaded = true
        loading = false
    }

    private func toggle(_ name: String) {
        if expanded.contains(name) {
            expanded.remove(name)
            return
        }
        expanded.insert(name)
        guard series[name] == nil else { return }
        Task {
            series[name] = await store.series(
                name: name,
                since: Date().addingTimeInterval(-window.seconds)
            )
        }
    }

    /// History is keyed by container name (stable across restarts), but the
    /// compose service name is what the Containers tab shows.
    private func displayName(_ name: String) -> String {
        store.probe?.containers.first { $0.name == name }?.displayName ?? name
    }

    private func eventIcon(_ kind: String) -> String {
        switch kind {
        case "started": return "play.fill"
        case "stopped": return "stop.fill"
        case "restart": return "arrow.clockwise"
        case "health": return "heart.fill"
        default: return "circle.fill"
        }
    }

    private func eventColor(_ kind: String) -> Color {
        switch kind {
        case "started": return Theme.green
        case "stopped": return Theme.gray
        case "restart": return Theme.amber
        case "health": return Theme.red
        default: return Theme.blue
        }
    }
}
