import AppKit
import SwiftUI

// MARK: - Palette

enum Theme {
    static func adaptive(_ light: NSColor, _ dark: NSColor) -> Color {
        Color(nsColor: NSColor(name: nil) { appearance in
            let isDark = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
            return isDark ? dark : light
        })
    }

    static func srgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> NSColor {
        NSColor(srgbRed: r, green: g, blue: b, alpha: a)
    }

    static let accent = Color(red: 0.36, green: 0.92, blue: 0.82)
    static let accentDeep = Color(red: 0.16, green: 0.78, blue: 0.94)
    static let violet = Color(red: 0.64, green: 0.56, blue: 0.98)
    static let pink = Color(red: 0.95, green: 0.45, blue: 0.70)

    // Status colours are text-safe in both appearances; the bright palette
    // above is for gradients and glows only.
    static let green = adaptive(srgb(0.04, 0.55, 0.31), srgb(0.29, 0.87, 0.55))
    static let amber = adaptive(srgb(0.66, 0.42, 0.01), srgb(0.98, 0.72, 0.30))
    static let red = adaptive(srgb(0.76, 0.16, 0.16), srgb(0.96, 0.38, 0.38))
    static let blue = adaptive(srgb(0.08, 0.41, 0.84), srgb(0.38, 0.68, 0.99))
    static let gray = Color.secondary

    static let accentText = adaptive(srgb(0.01, 0.49, 0.43), srgb(0.36, 0.92, 0.82))
    static let cyanText = adaptive(srgb(0.01, 0.41, 0.61), srgb(0.38, 0.82, 0.98))
    static let violetText = adaptive(srgb(0.35, 0.27, 0.77), srgb(0.64, 0.56, 0.98))

    static let canvasTop = adaptive(srgb(0.975, 0.982, 0.996), srgb(0.035, 0.044, 0.062))
    static let canvasBottom = adaptive(srgb(0.915, 0.938, 0.975), srgb(0.018, 0.022, 0.034))
    static let surface = adaptive(srgb(1, 1, 1, 0.90), srgb(1, 1, 1, 0.055))
    static let surfaceHigh = adaptive(srgb(1, 1, 1, 1), srgb(1, 1, 1, 0.095))
    static let surfaceSunken = adaptive(srgb(0.925, 0.945, 0.975, 0.9), srgb(0, 0, 0, 0.16))
    static let stroke = adaptive(srgb(0.10, 0.13, 0.20, 0.14), srgb(1, 1, 1, 0.13))
    static let strokeStrong = adaptive(srgb(0.10, 0.13, 0.20, 0.22), srgb(1, 1, 1, 0.20))
    static let grid = adaptive(srgb(0.10, 0.13, 0.20, 0.055), srgb(1, 1, 1, 0.045))

    // Legacy names used across the views.
    static let card = surface
    static let cardStrong = surfaceHigh
    static let subtle = Color.primary.opacity(0.55)

    static let panelWidth: CGFloat = 440
    static let panelHeight: CGFloat = 620

    static var accentGradient: LinearGradient {
        LinearGradient(
            colors: [accent, accentDeep],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    static var violetGradient: LinearGradient {
        LinearGradient(
            colors: [violet, pink],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Appearance

enum AppearanceMode: String, CaseIterable, Identifiable {
    case system, light, dark

    var id: String { rawValue }

    var label: String {
        switch self {
        case .system: return "System"
        case .light: return "Light"
        case .dark: return "Dark"
        }
    }

    var nsAppearance: NSAppearance? {
        switch self {
        case .system: return nil
        case .light: return NSAppearance(named: .aqua)
        case .dark: return NSAppearance(named: .darkAqua)
        }
    }

    static func apply(_ raw: String) {
        let mode = AppearanceMode(rawValue: raw) ?? .system
        NSApplication.shared.appearance = mode.nsAppearance
    }

    static func applyCurrent() {
        apply(UserDefaults.standard.string(forKey: "serverfo.appearance") ?? "system")
    }
}

// MARK: - Background

struct AppBackground: View {
    @Environment(\.colorScheme) private var scheme

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Theme.canvasTop, Theme.canvasBottom],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [Theme.accent.opacity(scheme == .dark ? 0.20 : 0.16), .clear],
                center: UnitPoint(x: 0.12, y: 0.02),
                startRadius: 0,
                endRadius: 380
            )

            RadialGradient(
                colors: [Theme.violet.opacity(scheme == .dark ? 0.18 : 0.10), .clear],
                center: UnitPoint(x: 0.95, y: 1.0),
                startRadius: 0,
                endRadius: 340
            )

            Canvas { context, size in
                let step: CGFloat = 26
                var path = Path()
                var x: CGFloat = 0
                while x <= size.width {
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    x += step
                }
                var y: CGFloat = 0
                while y <= size.height {
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    y += step
                }
                context.stroke(path, with: .color(Theme.grid), lineWidth: 0.5)
            }
            .mask(
                LinearGradient(
                    colors: [.white.opacity(0.85), .white.opacity(0.15), .clear],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
        }
        .ignoresSafeArea()
    }
}

// MARK: - Surfaces

private struct CardModifier: ViewModifier {
    var padding: CGFloat
    var radius: CGFloat
    @Environment(\.colorScheme) private var scheme

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Theme.surfaceHigh, Theme.surface],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .shadow(
                        color: Color.black.opacity(scheme == .dark ? 0.35 : 0.10),
                        radius: 12,
                        y: 5
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [Theme.strokeStrong, Theme.stroke.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        lineWidth: 1
                    )
            )
    }
}

extension View {
    func cardStyle(padding: CGFloat = 12, radius: CGFloat = 13) -> some View {
        modifier(CardModifier(padding: padding, radius: radius))
    }
}

struct StatusDot: View {
    var color: Color
    var size: CGFloat = 7
    var glow: Bool = false

    var body: some View {
        ZStack {
            if glow {
                Circle().fill(color.opacity(0.22)).frame(width: size * 2.6, height: size * 2.6)
            }
            Circle()
                .fill(
                    LinearGradient(
                        colors: [color.opacity(0.95), color],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(width: size, height: size)
                .overlay(Circle().strokeBorder(.white.opacity(0.35), lineWidth: 0.6))
                .shadow(color: glow ? color.opacity(0.8) : .clear, radius: 3)
        }
        .frame(width: max(size, 6), height: max(size, 6))
    }
}

struct Pill: View {
    var text: String
    var color: Color
    var icon: String? = nil
    var glass = false

    var body: some View {
        HStack(spacing: 3) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 7.5, weight: .bold))
            }
            Text(text)
                .font(.system(size: 9, weight: .semibold, design: .rounded))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 7)
        .padding(.vertical, 2.5)
        .background(
            Capsule().fill(color.opacity(glass ? 0.10 : 0.15))
        )
        .overlay(
            Capsule().strokeBorder(color.opacity(0.22), lineWidth: 0.7)
        )
    }
}

struct SectionTitle: View {
    var text: String
    var trailing: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            RoundedRectangle(cornerRadius: 1)
                .fill(Theme.accentGradient)
                .frame(width: 2.5, height: 9)
            Text(text.uppercased())
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .tracking(0.9)
                .foregroundStyle(.tertiary)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

struct KeyValueRow: View {
    var key: String
    var value: String
    var mono = false

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text(key)
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
                .frame(width: 92, alignment: .leading)
            Text(value.isEmpty ? "—" : value)
                .font(.system(size: 10.5, design: mono ? .monospaced : .default))
                .foregroundStyle(.primary)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.vertical, 0.5)
    }
}

struct MetricTile: View {
    var label: String
    var value: String
    var detail: String?
    var color: Color = .primary
    var fraction: Double?
    var icon: String? = nil

    @Environment(\.colorScheme) private var scheme

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                if let icon {
                    Image(systemName: icon)
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(color.opacity(0.9))
                }
                Text(label.uppercased())
                    .font(.system(size: 8, weight: .semibold, design: .rounded))
                    .tracking(0.5)
                    .foregroundStyle(.tertiary)
                Spacer(minLength: 0)
            }
            Text(value)
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.65)
            if let detail {
                Text(detail)
                    .font(.system(size: 8.3, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            if let fraction {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.primary.opacity(0.08))
                        Capsule()
                            .fill(LinearGradient(colors: [color, color.opacity(0.65)], startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(2, geo.size.width * min(1, max(0, fraction))))
                    }
                }
                .frame(height: 3)
                .padding(.top, 1)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(9)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(scheme == .dark ? 0.055 : 0.04))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(color.opacity(0.13), lineWidth: 0.8)
        )
    }
}

struct Sparkline: View {
    var values: [Double]
    var color: Color
    var filled = true
    var zeroBased = true

    var body: some View {
        GeometryReader { geo in
            let points = normalised(in: geo.size)
            ZStack {
                if filled, points.count > 1 {
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: geo.size.height))
                        for point in points { path.addLine(to: point) }
                        path.addLine(to: CGPoint(x: geo.size.width, y: geo.size.height))
                        path.closeSubpath()
                    }
                    .fill(
                        LinearGradient(
                            colors: [color.opacity(0.34), color.opacity(0.015)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                }
                if points.count > 1 {
                    Path { path in
                        path.move(to: points[0])
                        for point in points.dropFirst() { path.addLine(to: point) }
                    }
                    .stroke(
                        LinearGradient(colors: [color, color.opacity(0.65)], startPoint: .leading, endPoint: .trailing),
                        style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
                    )
                    .shadow(color: color.opacity(0.35), radius: 2.5)
                } else if let point = points.first {
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: point.y))
                        path.addLine(to: CGPoint(x: geo.size.width, y: point.y))
                    }
                    .stroke(color.opacity(0.55), style: StrokeStyle(lineWidth: 1.2, dash: [2, 2]))
                }
            }
        }
    }

    private func normalised(in size: CGSize) -> [CGPoint] {
        guard !values.isEmpty else { return [] }
        let high = values.max() ?? 1
        let low = zeroBased ? 0 : (values.min() ?? 0)
        let span = high - low
        let usable = size.height - 3
        let flat = span < max(abs(high) * 0.02, 0.0001)
        let step = size.width / CGFloat(max(1, values.count - 1))

        return values.enumerated().map { index, value in
            let y: CGFloat
            if flat {
                y = size.height * 0.55
            } else {
                let normalised = (value - low) / span
                y = size.height - 1.5 - CGFloat(min(1, max(0, normalised))) * usable
            }
            return CGPoint(x: CGFloat(index) * step, y: y)
        }
    }
}

// MARK: - Controls

struct GlassIconButton: View {
    var icon: String
    var help: String
    var active = false
    var spinning = false
    var action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            ZStack {
                Circle()
                    .fill(
                        hovering || active
                            ? AnyShapeStyle(Theme.accentGradient)
                            : AnyShapeStyle(Theme.surfaceHigh)
                    )
                    .overlay(
                        Circle().strokeBorder(
                            (hovering || active) ? Theme.accent.opacity(0.5) : Theme.stroke,
                            lineWidth: 0.8
                        )
                    )
                if spinning {
                    ProgressView().controlSize(.mini)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(
                            hovering || active ? Color.black.opacity(0.85) : Color.primary.opacity(0.8)
                        )
                }
            }
            .frame(width: 24, height: 24)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(help)
    }
}

struct TagChip: View {
    var text: String
    var color: Color = Theme.accent

    var body: some View {
        Text(text)
            .font(.system(size: 8.5, weight: .semibold, design: .monospaced))
            .foregroundStyle(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(
                RoundedRectangle(cornerRadius: 5, style: .continuous)
                    .fill(color.opacity(0.10))
            )
    }
}

// MARK: - Helpers

func cpuColor(_ value: Double) -> Color {
    if value >= 80 { return Theme.red }
    if value >= 40 { return Theme.amber }
    if value >= 10 { return Theme.cyanText }
    return Theme.accentText
}

func memoryColor(fraction: Double) -> Color {
    if fraction >= 0.9 { return Theme.red }
    if fraction >= 0.7 { return Theme.amber }
    return Theme.violetText
}
