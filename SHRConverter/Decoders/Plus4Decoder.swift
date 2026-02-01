import Foundation
import CoreGraphics

// MARK: - Commodore Plus/4 Decoder

class Plus4Decoder {

    // Plus/4 palette: 128 colors (16 hues × 8 luminance levels)
    // Color index = luminance * 16 + hue
    // From Plus4Renderer.java
    static let plus4Palette: [(r: UInt8, g: UInt8, b: UInt8)] = [
        // Luminance 0 (darkest)
        (0x00, 0x00, 0x00), (0x17, 0x17, 0x17), (0x0a, 0x07, 0x46), (0x26, 0x2a, 0x00),
        (0x46, 0x02, 0x3e), (0x00, 0x33, 0x00), (0x70, 0x0d, 0x0f), (0x00, 0x21, 0x1f),
        (0x00, 0x0e, 0x3e), (0x00, 0x17, 0x30), (0x00, 0x2b, 0x0f), (0x26, 0x03, 0x46),
        (0x0a, 0x31, 0x00), (0x61, 0x17, 0x03), (0x70, 0x07, 0x1f), (0x00, 0x31, 0x03),
        // Luminance 1
        (0x00, 0x00, 0x00), (0x26, 0x26, 0x26), (0x17, 0x14, 0x59), (0x37, 0x3b, 0x01),
        (0x59, 0x0c, 0x51), (0x01, 0x45, 0x05), (0x85, 0x1c, 0x1e), (0x00, 0x32, 0x30),
        (0x01, 0x1c, 0x51), (0x00, 0x27, 0x42), (0x00, 0x3c, 0x1e), (0x37, 0x0e, 0x59),
        (0x17, 0x42, 0x01), (0x75, 0x26, 0x0f), (0x85, 0x13, 0x30), (0x00, 0x43, 0x0f),
        // Luminance 2
        (0x00, 0x00, 0x00), (0x37, 0x37, 0x37), (0x27, 0x23, 0x6d), (0x49, 0x4e, 0x0c),
        (0x6d, 0x1b, 0x64), (0x0c, 0x58, 0x12), (0x9b, 0x2c, 0x2e), (0x00, 0x44, 0x41),
        (0x0c, 0x2c, 0x64), (0x00, 0x38, 0x55), (0x00, 0x4e, 0x2e), (0x49, 0x1d, 0x6d),
        (0x27, 0x55, 0x0c), (0x8a, 0x37, 0x1d), (0x9b, 0x22, 0x41), (0x00, 0x56, 0x1d),
        // Luminance 3
        (0x00, 0x00, 0x00), (0x4a, 0x4a, 0x4a), (0x38, 0x33, 0x81), (0x5d, 0x61, 0x1a),
        (0x82, 0x2a, 0x79), (0x1a, 0x6c, 0x20), (0xb1, 0x3d, 0x3f), (0x00, 0x57, 0x54),
        (0x1a, 0x3d, 0x79), (0x07, 0x4a, 0x68), (0x00, 0x62, 0x3f), (0x5d, 0x2d, 0x81),
        (0x38, 0x69, 0x1a), (0xa0, 0x49, 0x2d), (0xb1, 0x33, 0x54), (0x07, 0x69, 0x2d),
        // Luminance 4
        (0x00, 0x00, 0x00), (0x7b, 0x7b, 0x7b), (0x67, 0x62, 0xb8), (0x90, 0x96, 0x44),
        (0xb9, 0x58, 0xaf), (0x44, 0xa1, 0x4c), (0xeb, 0x6d, 0x70), (0x1f, 0x8a, 0x87),
        (0x44, 0x6e, 0xaf), (0x2b, 0x7c, 0x9d), (0x1f, 0x96, 0x70), (0x90, 0x5a, 0xb8),
        (0x67, 0x9e, 0x44), (0xd9, 0x7b, 0x5b), (0xeb, 0x62, 0x87), (0x2b, 0x9e, 0x5b),
        // Luminance 5
        (0x00, 0x00, 0x00), (0x9b, 0x9b, 0x9b), (0x86, 0x81, 0xdb), (0xb1, 0xb7, 0x61),
        (0xdc, 0x76, 0xd1), (0x60, 0xc3, 0x69), (0xff, 0x8c, 0x8f), (0x38, 0xab, 0xa8),
        (0x60, 0x8d, 0xd1), (0x45, 0x9c, 0xbf), (0x38, 0xb7, 0x8f), (0xb1, 0x79, 0xdb),
        (0x86, 0xc0, 0x61), (0xfd, 0x9b, 0x79), (0xff, 0x80, 0xa8), (0x45, 0xc0, 0x79),
        // Luminance 6
        (0x00, 0x00, 0x00), (0xe0, 0xe0, 0xe0), (0xc9, 0xc3, 0xff), (0xf8, 0xfe, 0xa0),
        (0xff, 0xb7, 0xff), (0x9f, 0xff, 0xa9), (0xff, 0xd0, 0xd3), (0x71, 0xf1, 0xed),
        (0x9f, 0xd1, 0xff), (0x81, 0xe0, 0xff), (0x71, 0xfe, 0xd3), (0xf8, 0xba, 0xff),
        (0xc9, 0xff, 0xa0), (0xff, 0xe0, 0xbb), (0xff, 0xc3, 0xed), (0x81, 0xff, 0xbb),
        // Luminance 7 (brightest)
        (0x00, 0x00, 0x00), (0xff, 0xff, 0xff), (0xff, 0xff, 0xff), (0xff, 0xff, 0xfd),
        (0xff, 0xff, 0xff), (0xfd, 0xff, 0xff), (0xff, 0xff, 0xff), (0xc9, 0xff, 0xff),
        (0xfd, 0xff, 0xff), (0xdb, 0xff, 0xff), (0xc9, 0xff, 0xff), (0xff, 0xff, 0xff),
        (0xff, 0xff, 0xfd), (0xff, 0xff, 0xff), (0xff, 0xff, 0xff), (0xdb, 0xff, 0xff)
    ]

    // MARK: - HiRes Mode (320×200, 2 colors per 8×8 cell)
    // File structure: nibble (1000) + screen (1000) + bitmap (8000) = 10000 bytes
    // With load address: 10002 bytes
    // D64 extraction may add 1 extra byte: 10001 bytes

    static func decodeHiRes(data: Data) -> (image: CGImage?, type: AppleIIImageType) {
        // Check file size (with or without 2-byte load address, with D64 padding)
        var offset = 0
        if data.count == 10002 {
            offset = 2
        } else if data.count == 10001 {
            // D64 extraction artifact - treat as raw 10000 bytes
            offset = 0
        } else if data.count != 10000 {
            return (nil, .Unknown)
        }

        let width = 320
        let height = 200
        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)

        let nibbleOffset = offset
        let screenOffset = offset + 1000
        let bitmapOffset = offset + 2000

        for cellY in 0..<25 {
            for cellX in 0..<40 {
                let cellIndex = cellY * 40 + cellX

                // Decode colors from nibble and screen RAM
                // nibble: (bgLuma << 4) | fgLuma
                // screen: (fgHue << 4) | bgHue
                let nibbleByte = data[nibbleOffset + cellIndex]
                let screenByte = data[screenOffset + cellIndex]

                let fgLuma = Int(nibbleByte & 0x0F)
                let bgLuma = Int((nibbleByte >> 4) & 0x0F)
                let fgHue = Int((screenByte >> 4) & 0x0F)
                let bgHue = Int(screenByte & 0x0F)

                // Color index = luminance * 16 + hue
                let fgColor = fgLuma * 16 + fgHue
                let bgColor = bgLuma * 16 + bgHue

                // Decode 8 rows of the character cell
                for row in 0..<8 {
                    let bitmapByteOffset = bitmapOffset + (cellIndex * 8) + row
                    guard bitmapByteOffset < data.count else { continue }

                    let bitmapByte = data[bitmapByteOffset]
                    let y = cellY * 8 + row

                    for bit in 0..<8 {
                        let x = cellX * 8 + bit
                        let bitVal = (bitmapByte >> (7 - bit)) & 1
                        let colorIndex = (bitVal == 1) ? fgColor : bgColor

                        let rgb = plus4Palette[colorIndex % 128]
                        let bufferIdx = (y * width + x) * 4

                        rgbaBuffer[bufferIdx] = rgb.r
                        rgbaBuffer[bufferIdx + 1] = rgb.g
                        rgbaBuffer[bufferIdx + 2] = rgb.b
                        rgbaBuffer[bufferIdx + 3] = 255
                    }
                }
            }
        }

        guard let cgImage = ImageHelpers.createCGImage(from: rgbaBuffer, width: width, height: height) else {
            return (nil, .Unknown)
        }

        return (cgImage, .Plus4(mode: "HiRes", colors: 128))
    }

    // MARK: - Multicolor Mode (160×200, 4 colors per 4×8 cell)
    // File structure: bgColor1 (1) + bgColor2 (1) + nibble (1000) + screen (1000) + bitmap (8000) = 10002 bytes
    // With load address: 10004 bytes

    static func decodeMulticolor(data: Data) -> (image: CGImage?, type: AppleIIImageType) {
        // Check file size (with or without 2-byte load address, with D64 padding)
        var offset = 0
        if data.count == 10004 {
            offset = 2
        } else if data.count == 10003 {
            // D64 extraction artifact - treat as raw 10002 bytes
            offset = 0
        } else if data.count != 10002 {
            return (nil, .Unknown)
        }

        let width = 320  // Output doubled horizontally
        let height = 200
        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)

        // Global background colors
        let bgColor1 = Int(data[offset])
        let bgColor2 = Int(data[offset + 1])

        let nibbleOffset = offset + 2
        let screenOffset = offset + 2 + 1000
        let bitmapOffset = offset + 2 + 2000

        for cellY in 0..<25 {
            for cellX in 0..<40 {
                let cellIndex = cellY * 40 + cellX

                // Decode cell colors from nibble and screen RAM
                // nibble: (c2Luma << 4) | c1Luma
                // screen: (c1Hue << 4) | c2Hue
                let nibbleByte = data[nibbleOffset + cellIndex]
                let screenByte = data[screenOffset + cellIndex]

                let c1Luma = Int(nibbleByte & 0x0F)
                let c2Luma = Int((nibbleByte >> 4) & 0x0F)
                let c1Hue = Int((screenByte >> 4) & 0x0F)
                let c2Hue = Int(screenByte & 0x0F)

                // Color index = luminance * 16 + hue
                let cellColor1 = c1Luma * 16 + c1Hue
                let cellColor2 = c2Luma * 16 + c2Hue

                // 4-color palette for this cell: bg1, c1, c2, bg2
                let cellPalette = [bgColor1, cellColor1, cellColor2, bgColor2]

                // Decode 8 rows of the character cell
                for row in 0..<8 {
                    let bitmapByteOffset = bitmapOffset + (cellIndex * 8) + row
                    guard bitmapByteOffset < data.count else { continue }

                    let bitmapByte = data[bitmapByteOffset]
                    let y = cellY * 8 + row

                    // 4 pixels per byte (2 bits each)
                    for pixel in 0..<4 {
                        let bitShift = 6 - (pixel * 2)
                        let colorIndex = Int((bitmapByte >> bitShift) & 0x03)
                        let paletteColor = cellPalette[colorIndex]

                        let rgb = plus4Palette[paletteColor % 128]

                        // Double pixels horizontally (160 -> 320)
                        let x = cellX * 8 + pixel * 2
                        for dx in 0..<2 {
                            let bufferIdx = (y * width + x + dx) * 4
                            rgbaBuffer[bufferIdx] = rgb.r
                            rgbaBuffer[bufferIdx + 1] = rgb.g
                            rgbaBuffer[bufferIdx + 2] = rgb.b
                            rgbaBuffer[bufferIdx + 3] = 255
                        }
                    }
                }
            }
        }

        guard let cgImage = ImageHelpers.createCGImage(from: rgbaBuffer, width: width, height: height) else {
            return (nil, .Unknown)
        }

        return (cgImage, .Plus4(mode: "Multicolor", colors: 128))
    }

    // MARK: - Auto-detect Plus/4 format by size

    static func decode(data: Data, filename: String? = nil) -> (image: CGImage?, type: AppleIIImageType) {
        let size = data.count

        // Try to determine format by file extension
        let ext = filename?.split(separator: ".").last?.lowercased() ?? ""

        // PRG files may have a 2-byte load address
        let hasLoadAddress = ext == "prg"

        // Check for Multicolor format first (has 2 extra bytes for global colors)
        // Multicolor: 10002 bytes (raw), 10003 (D64 padded), or 10004 bytes (with load address)
        if size == 10002 || size == 10003 || size == 10004 {
            // Check if first two bytes (after optional load address) look like color indices
            let colorOffset = (size == 10004) ? 2 : 0
            let byte1 = data[colorOffset]
            let byte2 = data[colorOffset + 1]

            // Valid Plus/4 color indices are 0-127
            if byte1 < 128 && byte2 < 128 {
                // Try Multicolor decode
                let result = decodeMulticolor(data: data)
                if result.image != nil {
                    return result
                }
            }
        }

        // Check for HiRes format
        // HiRes: 10000-10001 bytes (raw, with D64 padding) or 10002 bytes (with load address)
        if size == 10000 || size == 10001 || size == 10002 {
            // Could be HiRes (no global colors) or Multicolor (has global colors)
            // Try HiRes first for 10000/10001/10002 sizes
            if size == 10000 || size == 10001 || (size == 10002 && hasLoadAddress) {
                let result = decodeHiRes(data: data)
                if result.image != nil {
                    return result
                }
            }
        }

        // Fallback: try both formats
        if size >= 10000 && size <= 10004 {
            // Try HiRes
            if size == 10000 || size == 10001 || size == 10002 {
                let hiresResult = decodeHiRes(data: data)
                if hiresResult.image != nil {
                    return hiresResult
                }
            }

            // Try Multicolor
            if size == 10002 || size == 10004 {
                let mcResult = decodeMulticolor(data: data)
                if mcResult.image != nil {
                    return mcResult
                }
            }
        }

        return (nil, .Unknown)
    }
}
