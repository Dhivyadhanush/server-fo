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

    // One accent, used as a solid colour. No gradient fills.
    static let accent = Color(red: 0.24, green: 0.79, blue: 0.69)
    static let accentDeep = Color(red: 0.22, green: 0.63, blue: 0.92)
    static let violet = Color(red: 0.61, green: 0.52, blue: 0.96)
    static let pink = Color(red: 0.93, green: 0.44, blue: 0.69)

    static let green = adaptive(srgb(0.04, 0.55, 0.31), srgb(0.29, 0.87, 0.55))
    static let amber = adaptive(srgb(0.66, 0.42, 0.01), srgb(0.98, 0.72, 0.30))
    static let red = adaptive(srgb(0.76, 0.16, 0.16), srgb(0.96, 0.38, 0.38))
    static let blue = adaptive(srgb(0.08, 0.41, 0.84), srgb(0.38, 0.68, 0.99))
    static let gray = Color.secondary

    static let accentText = adaptive(srgb(0.01, 0.49, 0.43), srgb(0.36, 0.92, 0.82))
    static let cyanText = adaptive(srgb(0.01, 0.41, 0.61), srgb(0.38, 0.82, 0.98))
    static let violetText = adaptive(srgb(0.35, 0.27, 0.77), srgb(0.64, 0.56, 0.98))

    static let canvas = adaptive(srgb(0.960, 0.968, 0.980), srgb(0.043, 0.049, 0.061))
    static let surface = adaptive(srgb(1, 1, 1, 0.94), srgb(1, 1, 1, 0.055))
    static let surfaceHigh = adaptive(srgb(1, 1, 1, 1), srgb(1, 1, 1, 0.095))
    static let surfaceSunken = adaptive(srgb(0.925, 0.936, 0.955), srgb(0, 0, 0, 0.18))
    static let stroke = adaptive(srgb(0.10, 0.13, 0.20, 0.13), srgb(1, 1, 1, 0.12))
    static let strokeStrong = adaptive(srgb(0.10, 0.13, 0.20, 0.22), srgb(1, 1, 1, 0.20))

    // Legacy names used across the views.
    static let card = surface
    static let cardStrong = surfaceHigh
    static let subtle = Color.primary.opacity(0.55)
    static let grid = Color.clear

    static let panelWidth: CGFloat = 440
    static let panelHeight: CGFloat = 620
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

/// A solid canvas. Deliberately no radial glow, grid or gradient.
struct AppBackground: View {
    var body: some View {
        Theme.canvas
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
                    .fill(Theme.surface)
                    .shadow(
                        color: Color.black.opacity(scheme == .dark ? 0.24 : 0.07),
                        radius: 9,
                        y: 4
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 1)
            )
    }
}

extension View {
    func cardStyle(padding: CGFloat = 12, radius: CGFloat = 12) -> some View {
        modifier(CardModifier(padding: padding, radius: radius))
    }
}

struct StatusDot: View {
    var color: Color
    var size: CGFloat = 7
    var glow: Bool = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .overlay(Circle().strokeBorder(.white.opacity(0.22), lineWidth: 0.6))
            .shadow(color: glow ? color.opacity(0.35) : .clear, radius: 2)
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
            Capsule().fill(color.opacity(glass ? 0.10 : 0.14))
        )
        .overlay(
            Capsule().strokeBorder(color.opacity(0.20), lineWidth: 0.7)
        )
    }
}

struct SectionTitle: View {
    var text: String
    var trailing: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            RoundedRectangle(cornerRadius: 1)
                .fill(Theme.accent)
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
                            .fill(color)
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
                .fill(Color.primary.opacity(scheme == .dark ? 0.045 : 0.035))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(color.opacity(0.12), lineWidth: 0.8)
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
                    .fill(color.opacity(0.10))
                }
                if points.count > 1 {
                    Path { path in
                        path.move(to: points[0])
                        for point in points.dropFirst() { path.addLine(to: point) }
                    }
                    .stroke(
                        color,
                        style: StrokeStyle(lineWidth: 1.5, lineCap: .round, lineJoin: .round)
                    )
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
                    .fill(active ? Theme.accent : (hovering ? Theme.surfaceHigh : Theme.surface))
                    .overlay(
                        Circle().strokeBorder(
                            active ? Theme.accent.opacity(0.5) : Theme.stroke,
                            lineWidth: 0.8
                        )
                    )
                if spinning {
                    ProgressView()
                        .controlSize(.mini)
                        .tint(Theme.accentText)
                } else {
                    Image(systemName: icon)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(active ? Color.black.opacity(0.85) : Color.primary.opacity(0.8))
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
