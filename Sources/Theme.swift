import AppKit
import SwiftUI

enum Theme {
    static let accent = Color(red: 0.26, green: 0.82, blue: 0.70)
    static let green = Color(red: 0.30, green: 0.84, blue: 0.55)
    static let amber = Color(red: 0.96, green: 0.70, blue: 0.28)
    static let red = Color(red: 0.94, green: 0.36, blue: 0.36)
    static let blue = Color(red: 0.36, green: 0.66, blue: 0.98)
    static let gray = Color.secondary

    static let card = Color.primary.opacity(0.045)
    static let cardStrong = Color.primary.opacity(0.07)
    static let stroke = Color.primary.opacity(0.08)
    static let subtle = Color.primary.opacity(0.55)

    static let panelWidth: CGFloat = 440
    static let panelHeight: CGFloat = 620
}

extension View {
    func cardStyle(padding: CGFloat = 12, radius: CGFloat = 12) -> some View {
        self
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .fill(Theme.card)
            )
            .overlay(
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(Theme.stroke, lineWidth: 1)
            )
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
            .shadow(color: glow ? color.opacity(0.7) : .clear, radius: 3)
    }
}

struct Pill: View {
    var text: String
    var color: Color
    var icon: String? = nil

    var body: some View {
        HStack(spacing: 3) {
            if let icon {
                Image(systemName: icon).font(.system(size: 8, weight: .bold))
            }
            Text(text).font(.system(size: 9, weight: .semibold))
        }
        .foregroundStyle(color)
        .padding(.horizontal, 6)
        .padding(.vertical, 2)
        .background(Capsule().fill(color.opacity(0.14)))
    }
}

struct SectionTitle: View {
    var text: String
    var trailing: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(text.uppercased())
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.7)
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
    }
}

struct MetricTile: View {
    var label: String
    var value: String
    var detail: String?
    var color: Color = .primary
    var fraction: Double?

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 8.5, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(color)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let detail {
                Text(detail)
                    .font(.system(size: 8.5, design: .monospaced))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
            if let fraction {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.primary.opacity(0.08))
                        Capsule()
                            .fill(color.opacity(0.75))
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
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(Color.primary.opacity(0.04))
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
                            colors: [color.opacity(0.35), color.opacity(0.02)],
                            startPoint: .top, endPoint: .bottom
                        )
                    )
                }
                if points.count > 1 {
                    Path { path in
                        path.move(to: points[0])
                        for point in points.dropFirst() { path.addLine(to: point) }
                    }
                    .stroke(color, style: StrokeStyle(lineWidth: 1.4, lineCap: .round, lineJoin: .round))
                } else if let point = points.first {
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: point.y))
                        path.addLine(to: CGPoint(x: geo.size.width, y: point.y))
                    }
                    .stroke(color.opacity(0.6), style: StrokeStyle(lineWidth: 1.2, dash: [2, 2]))
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

        // A flat series should read as a calm line, not a solid block.
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

func cpuColor(_ value: Double) -> Color {
    if value >= 80 { return Theme.red }
    if value >= 40 { return Theme.amber }
    return Theme.green
}

func memoryColor(fraction: Double) -> Color {
    if fraction >= 0.9 { return Theme.red }
    if fraction >= 0.7 { return Theme.amber }
    return Theme.blue
}
