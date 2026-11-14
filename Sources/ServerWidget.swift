import AppKit
import SwiftUI

// MARK: - Controller

@MainActor
final class ServerWidgetController: ObservableObject {
    static let shared = ServerWidgetController()
    static let key = "serverfo.showWidget"

    private var panel: NSPanel?
    private var store: Store?

    @Published private(set) var isVisible = false

    func show(store: Store) {
        self.store = store

        if panel == nil {
            let view = ServerWidgetView(store: store) { [weak self] in
                self?.hide()
            }
            let hosting = NSHostingView(rootView: view)
            hosting.frame = NSRect(x: 0, y: 0, width: 288, height: 352)

            let panel = NSPanel(
                contentRect: hosting.frame,
                styleMask: [.borderless],
                backing: .buffered,
                defer: false
            )
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = true
            panel.level = .floating
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            panel.hidesOnDeactivate = false
            panel.isMovableByWindowBackground = true
            panel.isReleasedWhenClosed = false
            panel.contentView = hosting
            panel.setFrameAutosaveName("ServerFoWidget")

            if !panel.setFrameUsingName("ServerFoWidget"),
               let screen = NSScreen.main?.visibleFrame {
                panel.setFrameOrigin(
                    NSPoint(
                        x: screen.maxX - panel.frame.width - 24,
                        y: screen.maxY - panel.frame.height - 24
                    )
                )
            }
            self.panel = panel
        }

        UserDefaults.standard.set(true, forKey: Self.key)
        isVisible = true
        panel?.orderFrontRegardless()
    }

    func hide() {
        UserDefaults.standard.set(false, forKey: Self.key)
        isVisible = false
        panel?.orderOut(nil)
    }

    func toggle(store: Store) {
        isVisible ? hide() : show(store: store)
    }
}

// MARK: - View

struct ServerWidgetView: View {
    @ObservedObject var store: Store
    var onClose: () -> Void

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider().opacity(0.25)
            content
        }
        .frame(width: 288, height: 352)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Theme.surfaceHigh, Theme.surface],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )

                RadialGradient(
                    colors: [Theme.accent.opacity(scheme == .dark ? 0.16 : 0.10), .clear],
                    center: .topLeading,
                    startRadius: 0,
                    endRadius: 210
                )
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [Theme.strokeStrong, Theme.stroke.opacity(0.45)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .shadow(color: .black.opacity(scheme == .dark ? 0.40 : 0.16), radius: 16, y: 7)
    }

    // MARK: Header

    private var header: some View {
        HStack(spacing: 8) {
            if let icon = AppAssets.appIcon {
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 26, height: 26)
                    .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
            }

            VStack(alignment: .leading, spacing: 1) {
                Text("Server-Fo")
                    .font(.system(size: 12, weight: .heavy, design: .rounded))
                Text(store.probe?.hostname.isEmpty == false ? store.probe!.hostname : "server")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            Circle()
                .fill(statusColor)
                .frame(width: 6, height: 6)
                .shadow(color: statusColor.opacity(0.6), radius: 2)

            Button {
                store.refresh()
            } label: {
                Image(systemName: "arrow.clockwise")
                    .font(.system(size: 9, weight: .semibold))
                    .frame(width: 18, height: 18)
            }
            .buttonStyle(.plain)
            .help("Refresh")

            Button(action: onClose) {
                Image(systemName: "xmark")
                    .font(.system(size: 8, weight: .bold))
                    .frame(width: 18, height: 18)
                    .background(Circle().fill(Theme.surfaceSunken))
            }
            .buttonStyle(.plain)
            .help("Hide widget")
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private var statusColor: Color {
        switch store.connection {
        case .online: return Theme.green
        case .connecting, .idle: return Theme.blue
        case .unreachable: return Theme.red
        }
    }

    // MARK: Content

    @ViewBuilder
    private var content: some View {
        if let probe = store.probe {
            VStack(spacing: 8) {
                metric(
                    "RAM",
                    value: probe.ramTotal > 0 ? Fmt.percent(probe.ramPercent) : "—",
                    detail: probe.ramTotal > 0
                        ? "\(Fmt.bytes(probe.ramUsed)) / \(Fmt.bytes(probe.ramTotal))"
                        : "unavailable",
                    fraction: probe.ramPercent / 100,
                    color: memoryColor(fraction: probe.ramPercent / 100),
                    icon: "memorychip.fill"
                )

                metric(
                    "CPU",
                    value: probe.cpuPercent > 0 ? Fmt.percent(probe.cpuPercent) : "—",
                    detail: "\(probe.cpuCores) cores · load \(String(format: "%.2f", probe.load1)) \(String(format: "%.2f", probe.load5)) \(String(format: "%.2f", probe.load15))",
                    fraction: probe.cpuPercent / 100,
                    color: cpuColor(probe.cpuPercent),
                    icon: "cpu"
                )

                metric(
                    "Disk",
                    value: probe.diskTotal > 0 ? Fmt.percent(probe.diskPercent) : "—",
                    detail: probe.diskTotal > 0
                        ? "\(Fmt.bytes(probe.diskUsed)) / \(Fmt.bytes(probe.diskTotal)) · root"
                        : "unavailable",
                    fraction: probe.diskPercent / 100,
                    color: probe.diskPercent > 85 ? Theme.amber : Theme.blue,
                    icon: "internaldrive.fill"
                )

                stats(probe)

                HStack(spacing: 4) {
                    Text("updated \(Fmt.relative(store.lastUpdated))")
                    if store.tailscaleEnabled {
                        Text("· via Tailscale")
                            .foregroundStyle(Theme.accentText)
                            .help(store.tailscalePiIP ?? SSHConfig.current().jumpHost)
                    }
                    Spacer()
                    if store.probe?.aptUpgradable.isEmpty == false {
                        Text("\(store.probe?.aptUpgradable.count ?? 0) updates")
                    }
                }
                .font(.system(size: 8, design: .monospaced))
                .foregroundStyle(.tertiary)
                .lineLimit(1)
            }
            .padding(.horizontal, 12)
            .padding(.top, 10)
            .padding(.bottom, 12)
        } else {
            VStack(spacing: 8) {
                Spacer()
                ProgressView().controlSize(.small)
                Text("Contacting the server…")
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                if let error = store.lastError {
                    Text(error)
                        .font(.system(size: 8.5))
                        .foregroundStyle(.tertiary)
                        .multilineTextAlignment(.center)
                        .lineLimit(3)
                        .padding(.horizontal, 18)
                }
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func metric(
        _ label: String,
        value: String,
        detail: String,
        fraction: Double,
        color: Color,
        icon: String
    ) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(color.opacity(0.9))
                Text(label.uppercased())
                    .font(.system(size: 8, weight: .bold, design: .rounded))
                    .tracking(0.5)
                    .foregroundStyle(.tertiary)
                Spacer()
                Text(value)
                    .font(.system(size: 13, weight: .heavy, design: .rounded))
                    .foregroundStyle(color)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.primary.opacity(0.08))
                    Capsule()
                        .fill(LinearGradient(colors: [color, color.opacity(0.6)], startPoint: .leading, endPoint: .trailing))
                        .frame(width: max(2, geo.size.width * min(1, max(0, fraction))))
                }
            }
            .frame(height: 3)

            HStack {
                Text(detail)
                    .font(.system(size: 7.8, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer()
            }
        }
    }

    private func stats(_ probe: Probe) -> some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 5) {
            stat("Uptime", Fmt.uptime(probe.uptimeSeconds), icon: "clock.fill", color: Theme.accentText)
            stat("Docker", "\(probe.running) up", icon: "shippingbox.fill", color: Theme.green)
            stat(
                "Updates",
                "\(probe.aptUpgradable.count)",
                icon: "arrow.down.circle.fill",
                color: probe.aptUpgradable.isEmpty ? Theme.green : Theme.amber
            )
            stat(
                "Reboot",
                probe.rebootRequired ? "required" : "no",
                icon: "power",
                color: probe.rebootRequired ? Theme.amber : Theme.green
            )
        }
        .padding(.top, 2)
    }

    private func stat(_ label: String, _ value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(color.opacity(0.9))
            VStack(alignment: .leading, spacing: 0) {
                Text(label.uppercased())
                    .font(.system(size: 7, weight: .bold, design: .rounded))
                    .tracking(0.4)
                    .foregroundStyle(.tertiary)
                Text(value)
                    .font(.system(size: 9.5, weight: .semibold, design: .monospaced))
                    .foregroundStyle(color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 7)
        .padding(.vertical, 5)
        .background(
            RoundedRectangle(cornerRadius: 7, style: .continuous)
                .fill(Theme.surfaceSunken)
        )
    }
}
