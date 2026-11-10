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

    @AppStorage("sinfo.showHistoryEvents") private var showEvents = true

    var body: some View {
        VStack(spacing: 8) {
            toolbar
            if loading && !loaded {
                VStack(spacing: 9) {
                    ProgressView().controlSize(.small)
                    Text("Reading 30-day history…")
                        .font(.system(size: 10.5))
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 11) {
                        containersCard
                        if showEvents { eventsCard }
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
            HStack(spacing: 3) {
                ForEach(Window.allCases) { item in
                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.85)) {
                            window = item
                        }
                    } label: {
                        Text(item.rawValue)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(window == item ? Color.black.opacity(0.85) : Color.secondary)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background {
                                if window == item {
                                    Capsule()
                                        .fill(Theme.accentGradient)
                                        .shadow(color: Theme.accent.opacity(0.3), radius: 5, y: 1)
                                }
                            }
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(3)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Theme.surfaceSunken)
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .strokeBorder(Theme.stroke, lineWidth: 0.8)
                    )
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
        VStack(alignment: .leading, spacing: 7) {
            SectionTitle(text: "Container usage", trailing: window.rawValue)

            if summaries.isEmpty {
                HStack(spacing: 8) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 14))
                        .foregroundStyle(Theme.accent.opacity(0.6))
                    Text("No samples yet. S-Info records one every \(Int(store.sampleInterval / 60)) minutes while it is running.")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 5)
            } else {
                HStack(spacing: 6) {
                    Text("Container")
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text("CPU").frame(width: 44, alignment: .trailing)
                    Text("PEAK").frame(width: 44, alignment: .trailing)
                    Text("MEM").frame(width: 58, alignment: .trailing)
                    Text("UP").frame(width: 34, alignment: .trailing)
                }
                .font(.system(size: 8, weight: .bold, design: .rounded))
                .tracking(0.4)
                .foregroundStyle(.tertiary)
                .padding(.horizontal, 4)

                VStack(spacing: 1) {
                    ForEach(summaries.prefix(40), id: \.name) { summary in
                        summaryRow(summary)
                    }
                }
            }
        }
        .cardStyle(padding: 11)
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
                    HStack(spacing: 5) {
                        Image(systemName: isOpen ? "chevron.down" : "chevron.right")
                            .font(.system(size: 7, weight: .bold))
                            .foregroundStyle(isOpen ? Theme.accent : Color.primary.opacity(0.25))
                            .frame(width: 8)
                        Text(displayName(summary.name))
                            .font(.system(size: 10.5, weight: .medium))
                            .lineLimit(1)
                        Spacer(minLength: 0)
                    }
                    Text(Fmt.percent(summary.avgCPU))
                        .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                        .foregroundStyle(cpuColor(summary.avgCPU))
                        .frame(width: 44, alignment: .trailing)
                    Text(Fmt.percent(summary.peakCPU))
                        .font(.system(size: 9.5, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 44, alignment: .trailing)
                    Text(Fmt.bytes(summary.avgMem))
                        .font(.system(size: 9.5, design: .monospaced))
                        .foregroundStyle(.secondary)
                        .frame(width: 58, alignment: .trailing)
                    HStack(spacing: 2) {
                        if runFraction < 0.99 {
                            Circle()
                                .fill(Theme.amber)
                                .frame(width: 4, height: 4)
                        }
                        Text(Fmt.percent(runFraction * 100))
                            .font(.system(size: 9.5, design: .monospaced))
                            .foregroundStyle(runFraction > 0.99 ? Theme.green : Theme.amber)
                    }
                    .frame(width: 34, alignment: .trailing)
                }
                .padding(.horizontal, 4)
                .padding(.vertical, 5.5)
                .contentShape(Rectangle())
                .background(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(isOpen ? Theme.surfaceHigh : .clear)
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
            .frame(height: 38)
        } else {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("CPU")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundStyle(.tertiary)
                    Sparkline(values: points.map(\.cpu), color: Theme.accentText)
                        .frame(height: 28)
                    Text("\(points.count) samples · \(Fmt.shortDate(points.first?.ts)) → \(Fmt.shortDate(points.last?.ts))")
                        .font(.system(size: 7.5, design: .monospaced))
                        .foregroundStyle(.quaternary)
                        .lineLimit(1)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("MEMORY")
                        .font(.system(size: 8, weight: .bold, design: .rounded))
                        .foregroundStyle(.tertiary)
                    Sparkline(values: points.map { Double($0.memUsed) }, color: Theme.violetText, zeroBased: false)
                        .frame(height: 28)
                    Text("peak \(Fmt.bytes(points.map(\.memUsed).max() ?? 0))")
                        .font(.system(size: 7.5, design: .monospaced))
                        .foregroundStyle(.quaternary)
                }
            }
            .padding(7)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(Theme.surfaceSunken)
            )
        }
    }

    private var eventsCard: some View {
        VStack(alignment: .leading, spacing: 7) {
            SectionTitle(text: "State changes", trailing: "\(events.count)")

            if events.isEmpty {
                Text("No start, stop, restart or health changes recorded in this window.")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 3)
            } else {
                VStack(spacing: 0) {
                    ForEach(events.prefix(80)) { event in
                        HStack(alignment: .top, spacing: 7) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 5, style: .continuous)
                                    .fill(eventColor(event.kind).opacity(0.12))
                                    .frame(width: 18, height: 18)
                                Image(systemName: eventIcon(event.kind))
                                    .font(.system(size: 7.5, weight: .bold))
                                    .foregroundStyle(eventColor(event.kind))
                            }
                            VStack(alignment: .leading, spacing: 1) {
                                HStack(spacing: 4) {
                                    Text(displayName(event.name))
                                        .font(.system(size: 10, weight: .semibold))
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
                        .padding(.vertical, 3.5)
                        if event.id != events.prefix(80).last?.id {
                            Divider().opacity(0.2).padding(.leading, 25)
                        }
                    }
                }
            }
        }
        .cardStyle(padding: 11)
    }

    private var retentionCard: some View {
        HStack(alignment: .top, spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Theme.violetGradient)
                    .opacity(0.16)
                    .frame(width: 30, height: 30)
                Image(systemName: "clock.arrow.circlepath")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Theme.violetText)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text("30-day retention")
                    .font(.system(size: 10.5, weight: .semibold))
                Text("Samples, state changes and activity logs older than 30 days are deleted automatically. Everything is local, in ~/Library/Application Support/S-Info/history.sqlite.")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                if let stats = store.historyStats {
                    Text("\(stats.samples) samples · \(stats.events) events · \(Fmt.bytes(stats.bytes)) · oldest \(Fmt.relative(stats.oldest))")
                        .font(.system(size: 8.3, design: .monospaced))
                        .foregroundStyle(.tertiary)
                        .padding(.top, 1)
                }
            }
        }
        .cardStyle(padding: 11)
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
        withAnimation(.easeOut(duration: 0.16)) {
            if expanded.contains(name) {
                expanded.remove(name)
                return
            }
            expanded.insert(name)
        }
        guard series[name] == nil else { return }
        Task {
            series[name] = await store.series(
                name: name,
                since: Date().addingTimeInterval(-window.seconds)
            )
        }
    }

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
        default: return Theme.accentDeep
        }
    }
}
