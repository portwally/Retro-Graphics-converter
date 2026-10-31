//
//  AppleIIgsIconDecoder.swift
//  Retro-Graphics-Converter
//
//  Apple IIgs Finder icon files (ProDOS type $CA, ICN), ported from RetroBrowse.
//  A file holds any number of icon records; each has a large and a small icon.
//  All icons of a file are drawn onto one sheet.
//

import Foundation
import CoreGraphics

enum AppleIIgsIconDecoder {

    /// One QuickDraw II icon: 4 bits per pixel image plus a mask of the same size
    struct Icon {
        let width: Int
        let height: Int
        let bytesPerRow: Int
        let pixels: Data
        let mask: Data
    }

    struct Entry {
        let name: String
        let large: Icon?
        let small: Icon?
    }

    /// The Finder runs in 640 mode, where each 4-bit icon pixel becomes two dithered screen pixels
    /// from the standard 640 palette. These are the blended colors (as CiderPress2 uses them).
    static let palette: [(r: UInt8, g: UInt8, b: UInt8)] = [
        (0x00, 0x00, 0x00), (0x00, 0x00, 0x7F), (0x7F, 0x7F, 0x00), (0x6F, 0x6F, 0x6F),
        (0x7F, 0x00, 0x00), (0x7F, 0x00, 0x7F), (0xFF, 0x7F, 0x00), (0xFF, 0x7F, 0x7F),
        (0x00, 0x7F, 0x00), (0x00, 0x7F, 0x7F), (0x7F, 0xFF, 0x00), (0x7F, 0xFF, 0x7F),
        (0x8F, 0x8F, 0x8F), (0x7F, 0x7F, 0xFF), (0xFF, 0xFF, 0x7F), (0xFF, 0xFF, 0xFF),
    ]

    /// SHR mode name of decoded icon sheets (the palette editor checks it)
    static let modeName = "Finder Icons"

    /// Most icons a sheet draws (keeps damaged files from making huge images)
    static let maxEntries = 512

    // MARK: - Parsing

    /// Parse the Finder icon file layout (Apple File Type Note $CA): a 26-byte header, then
    /// records of iDataLen(2), iDataBoss(64), iDataName(16), iDataType(2), iDataAux(2),
    /// large icon, small icon. A record length of 0 ends the list.
    static func parse(data input: Data) -> [Entry] {
        let data = Data(input)   // index from 0, also for slices
        var entries: [Entry] = []
        var offset = 0x1A
        while offset + 0x56 + 8 <= data.count && entries.count < maxEntries {
            let recordLength = word(data, offset)
            if recordLength == 0 || recordLength < 0x56 + 8 || offset + recordLength > data.count { break }
            let recordEnd = offset + recordLength

            var name = pascalString(data, offset + 0x42, field: 16)
            if name.isEmpty { name = pascalString(data, offset + 2, field: 64) }

            var large: Icon?
            var small: Icon?
            if let (icon, end) = parseIcon(data, offset + 0x56, limit: recordEnd) {
                large = icon
                small = parseIcon(data, end, limit: recordEnd)?.icon
            }
            if large != nil || small != nil {
                entries.append(Entry(name: name, large: large, small: small))
            }
            offset = recordEnd
        }
        return entries
    }

    /// Icon record: iconType(2), iconSize(2), iconHeight(2), iconWidth(2), image, mask
    private static func parseIcon(_ data: Data, _ offset: Int, limit: Int) -> (icon: Icon, end: Int)? {
        guard offset + 8 <= limit else { return nil }
        let size = word(data, offset + 2)
        let height = word(data, offset + 4)
        let width = word(data, offset + 6)
        guard (1...128).contains(width), (1...128).contains(height), size >= height else { return nil }
        let start = offset + 8
        guard start + size * 2 <= limit else { return nil }
        // Rows are 1 + (width - 1) / 2 bytes; iconSize / height covers files that pad the rows
        let bytesPerRow = max(size / height, 1 + (width - 1) / 2)
        guard bytesPerRow * height <= size else { return nil }
        let icon = Icon(width: width, height: height, bytesPerRow: bytesPerRow,
                        pixels: data.subdata(in: start..<(start + size)),
                        mask: data.subdata(in: (start + size)..<(start + size * 2)))
        return (icon, start + size * 2)
    }

    // MARK: - Decoding

    /// Draw every icon of the file onto one sheet: each large icon with its small icon to the right,
    /// on white like a Finder window. Masked-out pixels stay white.
    static func decode(data: Data, paletteOverride: [(r: UInt8, g: UInt8, b: UInt8)]? = nil)
        -> (image: CGImage?, type: AppleIIImageType) {
        let colors = (paletteOverride?.count ?? 0) >= 16 ? paletteOverride! : palette
        let entries = parse(data: data)
        guard !entries.isEmpty else { return (nil, .Unknown) }

        let largeW = entries.compactMap { $0.large?.width }.max() ?? 0
        let largeH = entries.compactMap { $0.large?.height }.max() ?? 0
        let smallW = entries.compactMap { $0.small?.width }.max() ?? 0
        let smallH = entries.compactMap { $0.small?.height }.max() ?? 0
        let gap = 6
        let cellW = largeW + (smallW > 0 ? gap + smallW : 0) + gap * 2
        let cellH = max(largeH, smallH) + gap * 2
        let columns = min(entries.count, max(1, 320 / max(cellW, 1)))
        let rows = (entries.count + columns - 1) / columns
        let width = columns * cellW
        let height = rows * cellH

        var rgba = [UInt8](repeating: 0xFF, count: width * height * 4)
        func draw(_ icon: Icon, x0: Int, y0: Int) {
            for y in 0..<icon.height {
                for x in 0..<icon.width {
                    let index = y * icon.bytesPerRow + x / 2
                    guard index < icon.pixels.count else { continue }
                    let shift = x % 2 == 0 ? 4 : 0
                    if index < icon.mask.count && (icon.mask[index] >> shift) & 0x0F == 0 { continue }
                    let color = colors[Int((icon.pixels[index] >> shift) & 0x0F)]
                    let p = ((y0 + y) * width + x0 + x) * 4
                    rgba[p] = color.r; rgba[p + 1] = color.g; rgba[p + 2] = color.b
                }
            }
        }

        for (n, entry) in entries.enumerated() {
            let cellX = (n % columns) * cellW + gap
            let cellY = (n / columns) * cellH + gap
            let rowH = cellH - gap * 2
            if let large = entry.large {
                draw(large, x0: cellX + (largeW - large.width) / 2, y0: cellY + (rowH - large.height) / 2)
            }
            if let small = entry.small {
                draw(small, x0: cellX + largeW + gap + (smallW - small.width) / 2, y0: cellY + (rowH - small.height) / 2)
            }
        }

        guard let provider = CGDataProvider(data: Data(rgba) as CFData),
              let image = CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32,
                                  bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                                  bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipLast.rawValue),
                                  provider: provider, decode: nil, shouldInterpolate: false,
                                  intent: .defaultIntent) else { return (nil, .Unknown) }
        return (image, .SHR(mode: modeName, width: width, height: height))
    }

    // MARK: - Helpers

    private static func word(_ data: Data, _ offset: Int) -> Int {
        guard offset >= 0, offset + 1 < data.count else { return 0 }
        return Int(data[data.startIndex + offset]) | Int(data[data.startIndex + offset + 1]) << 8
    }

    private static func pascalString(_ data: Data, _ offset: Int, field: Int) -> String {
        guard offset + field <= data.count else { return "" }
        let length = Int(data[data.startIndex + offset])
        guard length > 0, length < field else { return "" }
        let bytes = data[(data.startIndex + offset + 1)..<(data.startIndex + offset + 1 + length)]
        guard bytes.allSatisfy({ (0x20...0x7E).contains($0) }) else { return "" }
        return String(decoding: bytes, as: UTF8.self)
    }
}
