// Draws the app icon and the menu bar glyph from one shape, so the Dock and
// the menu bar show the same two-unit rack.
//
//   swift Resources/icon.swift build/AppIcon.iconset
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let design = 1024.0

func writePNG(_ image: CGImage, to url: URL) {
    guard let destination = CGImageDestinationCreateWithURL(
        url as CFURL, UTType.png.identifier as CFString, 1, nil
    ) else { exit(1) }
    CGImageDestinationAddImage(destination, image, nil)
    CGImageDestinationFinalize(destination)
}

func context(_ size: Int) -> CGContext {
    guard let ctx = CGContext(
        data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
        space: CGColorSpace(name: CGColorSpace.sRGB)!,
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    ) else { exit(1) }
    ctx.interpolationQuality = .high
    ctx.setAllowsAntialiasing(true)
    return ctx
}

/// Two rack units with vent slots and one LED, drawn in a box of the given
/// width. Proportions match the original 18 pt glyph.
func drawRack(
    _ ctx: CGContext,
    center: CGPoint,
    width: CGFloat,
    lineWidth: CGFloat,
    stroke: CGColor,
    fill: CGColor?,
    led: CGColor?,
    ledGlow: CGColor? = nil
) {
    let unitHeight = width * 0.4
    let gap = width * 0.1714
    let totalHeight = unitHeight * 2 + gap
    let x = center.x - width / 2
    let bottom = center.y - totalHeight / 2
    let radius = unitHeight * 0.232

    for index in 0..<2 {
        let y = bottom + CGFloat(index) * (unitHeight + gap)
        let rect = CGRect(x: x, y: y, width: width, height: unitHeight)
        let path = CGPath(
            roundedRect: rect,
            cornerWidth: radius, cornerHeight: radius, transform: nil
        )

        if let fill {
            ctx.addPath(path)
            ctx.setFillColor(fill)
            ctx.fillPath()
        }

        ctx.addPath(path)
        ctx.setStrokeColor(stroke)
        ctx.setLineWidth(lineWidth)
        ctx.setLineJoin(.round)
        ctx.strokePath()

        ctx.setStrokeColor(stroke)
        ctx.setLineWidth(lineWidth * 0.62)
        ctx.setLineCap(.round)
        for offset in [0.277, 0.5, 0.723] as [CGFloat] {
            ctx.move(to: CGPoint(x: x + width * 0.171, y: y + unitHeight * offset))
            ctx.addLine(to: CGPoint(x: x + width * 0.543, y: y + unitHeight * offset))
        }
        ctx.strokePath()

        if let led {
            let ledRect = CGRect(
                x: x + width * 0.743 - width * 0.057,
                y: y + unitHeight * 0.5 - width * 0.057,
                width: width * 0.114,
                height: width * 0.114
            )
            if let ledGlow {
                ctx.saveGState()
                ctx.setShadow(offset: .zero, blur: width * 0.05, color: ledGlow)
                ctx.setFillColor(led)
                ctx.fillEllipse(in: ledRect)
                ctx.restoreGState()
            } else {
                ctx.setFillColor(led)
                ctx.fillEllipse(in: ledRect)
            }
        }
    }
}

func appIcon(size: Int) -> CGImage {
    let ctx = context(size)
    let scale = CGFloat(size) / CGFloat(design)
    let radius = 0.2237 * CGFloat(size)
    let body = CGPath(
        roundedRect: CGRect(x: 0, y: 0, width: size, height: size),
        cornerWidth: radius, cornerHeight: radius, transform: nil
    )

    ctx.addPath(body)
    ctx.clip()

    let background = [
        CGColor(srgbRed: 0.085, green: 0.115, blue: 0.165, alpha: 1),
        CGColor(srgbRed: 0.022, green: 0.028, blue: 0.042, alpha: 1),
    ] as CFArray
    if let gradient = CGGradient(colorsSpace: nil, colors: background, locations: [0, 1]) {
        ctx.drawLinearGradient(
            gradient,
            start: CGPoint(x: 0, y: CGFloat(size)),
            end: CGPoint(x: CGFloat(size), y: 0),
            options: []
        )
    }

    // Cool glow behind the rack, plus a violet corner for depth.
    if let glow = CGGradient(
        colorsSpace: nil,
        colors: [
            CGColor(srgbRed: 0.36, green: 0.92, blue: 0.82, alpha: 0.34),
            CGColor(srgbRed: 0.36, green: 0.92, blue: 0.82, alpha: 0),
        ] as CFArray,
        locations: [0, 1]
    ) {
        ctx.drawRadialGradient(
            glow,
            startCenter: CGPoint(x: CGFloat(size) * 0.32, y: CGFloat(size) * 0.78),
            startRadius: 0,
            endCenter: CGPoint(x: CGFloat(size) * 0.32, y: CGFloat(size) * 0.78),
            endRadius: CGFloat(size) * 0.58,
            options: []
        )
    }
    if let violet = CGGradient(
        colorsSpace: nil,
        colors: [
            CGColor(srgbRed: 0.64, green: 0.56, blue: 0.98, alpha: 0.22),
            CGColor(srgbRed: 0.64, green: 0.56, blue: 0.98, alpha: 0),
        ] as CFArray,
        locations: [0, 1]
    ) {
        ctx.drawRadialGradient(
            violet,
            startCenter: CGPoint(x: CGFloat(size) * 0.82, y: CGFloat(size) * 0.18),
            startRadius: 0,
            endCenter: CGPoint(x: CGFloat(size) * 0.82, y: CGFloat(size) * 0.18),
            endRadius: CGFloat(size) * 0.5,
            options: []
        )
    }

    drawRack(
        ctx,
        center: CGPoint(x: CGFloat(size) / 2, y: CGFloat(size) * 0.51),
        width: CGFloat(size) * 0.60,
        lineWidth: CGFloat(size) * 0.030,
        stroke: CGColor(srgbRed: 0.92, green: 0.96, blue: 0.98, alpha: 0.95),
        fill: CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.045),
        led: CGColor(srgbRed: 0.36, green: 0.92, blue: 0.82, alpha: 1),
        ledGlow: CGColor(srgbRed: 0.36, green: 0.92, blue: 0.82, alpha: 0.85)
    )

    // Inset highlight so the squircle reads as glass, not a flat square.
    let inset = 2.0 * scale
    let highlight = CGPath(
        roundedRect: CGRect(
            x: inset, y: inset,
            width: CGFloat(size) - inset * 2,
            height: CGFloat(size) - inset * 2
        ),
        cornerWidth: radius - inset, cornerHeight: radius - inset, transform: nil
    )
    ctx.addPath(highlight)
    ctx.setStrokeColor(CGColor(srgbRed: 1, green: 1, blue: 1, alpha: 0.14))
    ctx.setLineWidth(2.5 * scale)
    ctx.strokePath()

    guard let image = ctx.makeImage() else { exit(1) }
    return image
}

/// 18×18 logical menu bar glyph, monochrome so macOS can tint it.
func menuBarGlyph(pixel: Int) -> CGImage {
    let ctx = context(pixel)
    let scale = CGFloat(pixel) / 18.0
    ctx.scaleBy(x: scale, y: scale)

    drawRack(
        ctx,
        center: CGPoint(x: 9, y: 9),
        width: 14,
        lineWidth: 1.25,
        stroke: CGColor(gray: 0, alpha: 1),
        fill: nil,
        led: CGColor(gray: 0, alpha: 1)
    )

    guard let image = ctx.makeImage() else { exit(1) }
    return image
}

guard CommandLine.arguments.count > 1 else {
    print("usage: icon.swift <iconset dir>")
    exit(1)
}

let iconset = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try? FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

let sizes = [
    ("icon_16x16", 16), ("icon_16x16@2x", 32),
    ("icon_32x32", 32), ("icon_32x32@2x", 64),
    ("icon_128x128", 128), ("icon_128x128@2x", 256),
    ("icon_256x256", 256), ("icon_256x256@2x", 512),
    ("icon_512x512", 512), ("icon_512x512@2x", 1024),
]
for (name, size) in sizes {
    writePNG(appIcon(size: size), to: iconset.appendingPathComponent("\(name).png"))
}

try? FileManager.default.createDirectory(
    at: root.appendingPathComponent("docs", isDirectory: true),
    withIntermediateDirectories: true
)
writePNG(appIcon(size: 512), to: root.appendingPathComponent("docs/icon.png"))
writePNG(menuBarGlyph(pixel: 18), to: root.appendingPathComponent("Resources/MenuBarIcon.png"))
writePNG(menuBarGlyph(pixel: 36), to: root.appendingPathComponent("Resources/MenuBarIcon@2x.png"))

print("iconset written to \(iconset.path)")
