// Regenerates the app icon and the menu bar glyph.
//
//   swift Resources/icon.swift build/AppIcon.iconset
//
// The colourful 1024px source (Resources/AppIcon-source.png) is masked to the
// macOS squircle; the menu bar glyph is drawn as a 1-bit template so macOS can
// tint it for light, dark and highlighted menu bars.
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let sourceURL = root.appendingPathComponent("Resources/AppIcon-source.png")
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
    return ctx
}

func maskedIcon(size: Int, source: CGImage) -> CGImage {
    let ctx = context(size)
    let scale = CGFloat(size) / CGFloat(design)
    let radius = 0.2237 * CGFloat(size)
    let body = CGPath(
        roundedRect: CGRect(x: 0, y: 0, width: size, height: size),
        cornerWidth: radius, cornerHeight: radius, transform: nil
    )
    ctx.addPath(body)
    ctx.clip()
    ctx.draw(source, in: CGRect(x: 0, y: 0, width: size, height: size))

    // A hairline inner edge keeps the icon from floating on light backgrounds.
    ctx.addPath(body)
    ctx.setStrokeColor(CGColor(gray: 0, alpha: 0.18))
    ctx.setLineWidth(max(1, 2 * scale))
    ctx.strokePath()

    guard let image = ctx.makeImage() else { exit(1) }
    return image
}

/// 18×18 logical menu bar glyph: two rack units, vent slots, one LED each.
func menuBarGlyph(pixel: Int) -> CGImage {
    let ctx = context(pixel)
    let scale = CGFloat(pixel) / 18.0
    ctx.scaleBy(x: scale, y: scale)
    ctx.setAllowsAntialiasing(true)

    let black = CGColor(gray: 0, alpha: 1)
    let units: [CGFloat] = [10.3, 2.3]
    let width: CGFloat = 14.0
    let height: CGFloat = 5.6
    let x: CGFloat = 2.0

    for y in units {
        let rect = CGRect(x: x, y: y, width: width, height: height)
        let path = CGPath(
            roundedRect: rect,
            cornerWidth: 1.3, cornerHeight: 1.3, transform: nil
        )
        ctx.addPath(path)
        ctx.setStrokeColor(black)
        ctx.setLineWidth(1.25)
        ctx.strokePath()

        ctx.setLineWidth(0.85)
        ctx.setLineCap(.round)
        for offset in [1.55, 2.8, 4.05] as [CGFloat] {
            ctx.move(to: CGPoint(x: 4.4, y: y + offset))
            ctx.addLine(to: CGPoint(x: 9.6, y: y + offset))
        }
        ctx.strokePath()

        ctx.setFillColor(black)
        ctx.fillEllipse(in: CGRect(x: 11.6, y: y + 2.0, width: 1.6, height: 1.6))
    }

    guard let image = ctx.makeImage() else { exit(1) }
    return image
}

guard CommandLine.arguments.count > 1 else {
    print("usage: icon.swift <iconset dir>")
    exit(1)
}
guard let sourceData = try? Data(contentsOf: sourceURL),
      let provider = CGDataProvider(data: sourceData as CFData),
      let source = CGImageSourceCreateWithDataProvider(provider, nil).flatMap({
          CGImageSourceCreateImageAtIndex($0, 0, nil)
      }) else {
    print("missing \(sourceURL.path)")
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
    writePNG(maskedIcon(size: size, source: source), to: iconset.appendingPathComponent("\(name).png"))
}

try? FileManager.default.createDirectory(
    at: root.appendingPathComponent("docs", isDirectory: true),
    withIntermediateDirectories: true
)
writePNG(maskedIcon(size: 512, source: source), to: root.appendingPathComponent("docs/icon.png"))
writePNG(menuBarGlyph(pixel: 18), to: root.appendingPathComponent("Resources/MenuBarIcon.png"))
writePNG(menuBarGlyph(pixel: 36), to: root.appendingPathComponent("Resources/MenuBarIcon@2x.png"))

print("iconset written to \(iconset.path)")
