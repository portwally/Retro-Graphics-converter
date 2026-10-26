import AppKit

// Renders Mac App Store screenshots: gradient background, title + subtitle on top, app window below.
// Usage (from the project folder):
//   swift AppStoreAssets/make-appstore-screenshots.swift AppStoreAssets/source AppStoreAssets/screenshots

let canvas = CGSize(width: 2880, height: 1800)   // Mac App Store 16:10, largest size

struct Shot {
    let file: String
    let title: String
    let subtitle: String
    let top: NSColor
    let bottom: NSColor
}

func rgb(_ hex: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
            blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
}

let shots: [Shot] = [
    Shot(file: "main-window", title: "Retro graphics, ready for today",
         subtitle: "Open pictures from Apple II, Amiga, Atari, C64, ZX Spectrum and more",
         top: rgb(0x3A1C71), bottom: rgb(0xD76D77)),
    Shot(file: "disk-browser", title: "Pictures straight from disk images",
         subtitle: "Browse ProDOS, DOS 3.3, D64, ADF, ATR, ST, TR-DOS and DFS disks",
         top: rgb(0x0F2027), bottom: rgb(0x2C7DA0)),
    Shot(file: "palette-editor", title: "Edit every palette",
         subtitle: "Even 3200-color Apple IIgs pictures with a palette on every line",
         top: rgb(0x42275A), bottom: rgb(0x734B6D)),
    Shot(file: "amiga", title: "Amiga IFF in all its colors",
         subtitle: "32 and 256 colors, Extra-Half-Brite and HAM",
         top: rgb(0x8E2DE2), bottom: rgb(0x4A00E0)),
    Shot(file: "atari-st", title: "Atari ST classics",
         subtitle: "Degas, NEOchrome, Art Director, GFA Artist and more",
         top: rgb(0x134E5E), bottom: rgb(0x71B280)),
    Shot(file: "c64", title: "Commodore 64 art",
         subtitle: "Koala Painter and Advanced Art Studio, imported from D64 disks",
         top: rgb(0x1E3C72), bottom: rgb(0x6A82FB)),
    Shot(file: "zx-spectrum", title: "ZX Spectrum screens",
         subtitle: "SCR files and pictures from TR-DOS disks",
         top: rgb(0x232526), bottom: rgb(0xB24592)),
    Shot(file: "macpaint", title: "MacPaint, pixel for pixel",
         subtitle: "The original 1-bit Macintosh pictures",
         top: rgb(0x2C3E50), bottom: rgb(0x6C7A89)),
    Shot(file: "pcx", title: "PC Paintbrush PCX",
         subtitle: "From 1-bit to 24-bit, with palette editing up to 256 colors",
         top: rgb(0x870000), bottom: rgb(0xF0A04B)),
    Shot(file: "bmp", title: "Windows BMP pictures",
         subtitle: "Export everything to PNG, JPEG, TIFF, GIF or HEIC",
         top: rgb(0x005C97), bottom: rgb(0x363795)),
]

let args = CommandLine.arguments
let inDir = URL(fileURLWithPath: args[1])
let outDir = URL(fileURLWithPath: args[2])
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

func drawCentered(_ text: String, font: NSFont, color: NSColor, y: CGFloat, in ctx: NSGraphicsContext) {
    let style = NSMutableParagraphStyle()
    style.alignment = .center
    let attributes: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color, .paragraphStyle: style]
    let string = NSAttributedString(string: text, attributes: attributes)
    let height = string.boundingRect(with: CGSize(width: canvas.width - 200, height: 1000), options: .usesLineFragmentOrigin).height
    string.draw(with: CGRect(x: 100, y: y, width: canvas.width - 200, height: height), options: .usesLineFragmentOrigin)
}

for (index, shot) in shots.enumerated() {
    guard let window = NSImage(contentsOf: inDir.appendingPathComponent(shot.file + ".png")),
          let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(canvas.width), pixelsHigh: Int(canvas.height),
                                     bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                     colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
          let ctx = NSGraphicsContext(bitmapImageRep: rep) else {
        print("skipped \(shot.file)"); continue
    }
    rep.size = canvas
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = ctx

    // Background gradient, top to bottom with a slight diagonal
    NSGradient(starting: shot.top, ending: shot.bottom)!.draw(in: CGRect(origin: .zero, size: canvas), angle: -70)

    // Title and subtitle (AppKit's origin is bottom-left, so y counts from the bottom)
    drawCentered(shot.title, font: .systemFont(ofSize: 112, weight: .heavy), color: .white, y: canvas.height - 250, in: ctx)
    drawCentered(shot.subtitle, font: .systemFont(ofSize: 54, weight: .medium),
                 color: NSColor.white.withAlphaComponent(0.85), y: canvas.height - 345, in: ctx)

    // App window (the capture includes its shadow), as large as fits below the text
    let source = window.representations.first.map { CGSize(width: $0.pixelsWide, height: $0.pixelsHigh) } ?? window.size
    let maxHeight = canvas.height - 400 - 20
    let maxWidth = canvas.width - 160
    let scale = min(maxHeight / source.height, maxWidth / source.width)
    let size = CGSize(width: source.width * scale, height: source.height * scale)
    let rect = CGRect(x: (canvas.width - size.width) / 2, y: 20, width: size.width, height: size.height)
    ctx.imageInterpolation = .high
    window.draw(in: rect, from: .zero, operation: .sourceOver, fraction: 1)

    NSGraphicsContext.restoreGraphicsState()

    let name = String(format: "%02d-%@.png", index + 1, shot.file)
    try rep.representation(using: .png, properties: [:])!.write(to: outDir.appendingPathComponent(name))
    print("wrote \(name)")
}
