import Foundation
import CoreGraphics

// MARK: - MSX Graphics Decoder

class MSXDecoder {

    // MARK: - MSX TMS9918 Palette (15 colors + transparent)

    static let msxPalette: [(r: UInt8, g: UInt8, b: UInt8)] = [
        (0x00, 0x00, 0x00),  // 0: Transparent (rendered as black)
        (0x00, 0x00, 0x00),  // 1: Black
        (0x21, 0xC8, 0x42),  // 2: Medium Green
        (0x5E, 0xDC, 0x78),  // 3: Light Green
        (0x54, 0x55, 0xED),  // 4: Dark Blue
        (0x7D, 0x76, 0xFC),  // 5: Light Blue
        (0xD4, 0x52, 0x4D),  // 6: Dark Red
        (0x42, 0xEB, 0xF5),  // 7: Cyan
        (0xFC, 0x55, 0x54),  // 8: Medium Red
        (0xFF, 0x79, 0x78),  // 9: Light Red
        (0xD4, 0xC1, 0x54),  // 10: Dark Yellow
        (0xE6, 0xCE, 0x80),  // 11: Light Yellow
        (0x21, 0xB0, 0x3B),  // 12: Dark Green
        (0xC9, 0x5B, 0xBA),  // 13: Magenta
        (0xCC, 0xCC, 0xCC),  // 14: Gray
        (0xFF, 0xFF, 0xFF)   // 15: White
    ]

    // MARK: - Screen 2 Decoder (Graphics Mode II)
    // Resolution: 256x192, 16 colors
    // Common file sizes: 14343 (with BSAVE header), 14336 (raw), 16384

    static func decodeScreen2(data: Data) -> (image: CGImage?, type: AppleIIImageType) {
        // MSX Screen 2 layout:
        // Pattern Name Table: 768 bytes (32x24 tile references)
        // Pattern Generator Table: 6144 bytes (256 patterns x 8 bytes per pattern x 3 banks)
        // Color Table: 6144 bytes (colors for each pattern line)

        let width = 256
        let height = 192

        var offset = 0

        // Check for BSAVE header (7 bytes: 0xFE + start addr + end addr + exec addr)
        if data.count >= 7 && data[0] == 0xFE {
            offset = 7
        }

        let dataSize = data.count - offset

        // Validate minimum size for Screen 2
        guard dataSize >= 6912 else {
            return (nil, .Unknown)
        }

        // Determine layout based on file size
        let patternNameTableOffset: Int
        let patternGeneratorOffset: Int
        let colorTableOffset: Int

        if dataSize >= 16384 {
            // Full VRAM dump (16KB) - standard MSX VRAM layout
            patternNameTableOffset = offset + 0x1800  // 6144
            patternGeneratorOffset = offset + 0x0000  // 0
            colorTableOffset = offset + 0x2000        // 8192
        } else if dataSize >= 14336 {
            // Typical SC2 file layout
            patternNameTableOffset = offset
            patternGeneratorOffset = offset + 768
            colorTableOffset = offset + 768 + 6144
        } else {
            // Minimal dump - just pattern and color tables
            patternNameTableOffset = offset
            patternGeneratorOffset = offset
            colorTableOffset = offset + 6144
        }

        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)

        // Decode each 8x8 tile
        for tileRow in 0..<24 {
            for tileCol in 0..<32 {
                let tileIndex = tileRow * 32 + tileCol

                // Get pattern number from name table (or use sequential in minimal format)
                let patternNum: Int
                if patternNameTableOffset + tileIndex < data.count {
                    patternNum = Int(data[patternNameTableOffset + tileIndex])
                } else {
                    patternNum = tileIndex % 256
                }

                // Screen 2 has 3 banks of 256 patterns each (top, middle, bottom third)
                let bank = tileRow / 8
                let patternOffset = patternGeneratorOffset + (bank * 2048) + (patternNum * 8)
                let colorOffset = colorTableOffset + (bank * 2048) + (patternNum * 8)

                // Decode 8 lines of the tile
                for line in 0..<8 {
                    let patternByteOffset = patternOffset + line
                    let colorByteOffset = colorOffset + line

                    var patternByte: UInt8 = 0
                    var colorByte: UInt8 = 0

                    if patternByteOffset < data.count {
                        patternByte = data[patternByteOffset]
                    }
                    if colorByteOffset < data.count {
                        colorByte = data[colorByteOffset]
                    }

                    let fgColor = Int((colorByte >> 4) & 0x0F)
                    let bgColor = Int(colorByte & 0x0F)

                    // Decode 8 pixels
                    for pixel in 0..<8 {
                        let bit = (patternByte >> (7 - pixel)) & 1
                        let colorIndex = bit == 1 ? fgColor : bgColor

                        // Handle transparent (color 0) as black
                        let actualColor = colorIndex == 0 ? 1 : colorIndex

                        let x = tileCol * 8 + pixel
                        let y = tileRow * 8 + line
                        let bufferIdx = (y * width + x) * 4

                        let rgb = msxPalette[actualColor]
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

        return (cgImage, .MSX(mode: 2, colors: 16))
    }

    // MARK: - Screen 1 Decoder (Graphics Mode I / Text Mode with graphics)
    // Resolution: 256x192 (32x24 tiles of 8x8)
    // Simpler color model: one color pair per 8 patterns

    static func decodeScreen1(data: Data) -> (image: CGImage?, type: AppleIIImageType) {
        let width = 256
        let height = 192

        var offset = 0

        // Check for BSAVE header
        if data.count >= 7 && data[0] == 0xFE {
            offset = 7
        }

        let dataSize = data.count - offset
        guard dataSize >= 2048 else {
            return (nil, .Unknown)
        }

        // Screen 1 layout (simplified):
        // Pattern Name Table: 768 bytes
        // Pattern Generator: 2048 bytes (256 patterns x 8 bytes)
        // Color Table: 32 bytes (one color pair per 8 patterns)

        let patternNameTableOffset = offset
        let patternGeneratorOffset = offset + 768
        let colorTableOffset = offset + 768 + 2048

        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)

        for tileRow in 0..<24 {
            for tileCol in 0..<32 {
                let tileIndex = tileRow * 32 + tileCol

                let patternNum: Int
                if patternNameTableOffset + tileIndex < data.count {
                    patternNum = Int(data[patternNameTableOffset + tileIndex])
                } else {
                    patternNum = tileIndex % 256
                }

                let patternOffset = patternGeneratorOffset + (patternNum * 8)

                // Color table: one byte per 8 patterns
                let colorIndex = patternNum / 8
                var colorByte: UInt8 = 0xF1  // Default: white on black
                if colorTableOffset + colorIndex < data.count {
                    colorByte = data[colorTableOffset + colorIndex]
                }

                let fgColor = Int((colorByte >> 4) & 0x0F)
                let bgColor = Int(colorByte & 0x0F)

                for line in 0..<8 {
                    let patternByteOffset = patternOffset + line
                    var patternByte: UInt8 = 0
                    if patternByteOffset < data.count {
                        patternByte = data[patternByteOffset]
                    }

                    for pixel in 0..<8 {
                        let bit = (patternByte >> (7 - pixel)) & 1
                        let colorIdx = bit == 1 ? fgColor : bgColor
                        let actualColor = colorIdx == 0 ? 1 : colorIdx

                        let x = tileCol * 8 + pixel
                        let y = tileRow * 8 + line
                        let bufferIdx = (y * width + x) * 4

                        let rgb = msxPalette[actualColor]
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

        return (cgImage, .MSX(mode: 1, colors: 16))
    }

    // MARK: - Screen 5 Decoder (MSX2 Graphics Mode 4)
    // Resolution: 256x212, 16 colors from 512 color palette
    // 4 bits per pixel (2 pixels per byte)

    static func decodeScreen5(data: Data) -> (image: CGImage?, type: AppleIIImageType) {
        let width = 256
        let height = 212

        var offset = 0

        // Check for BSAVE header
        if data.count >= 7 && data[0] == 0xFE {
            offset = 7
        }

        let dataSize = data.count - offset

        // Screen 5: 256x212, 4bpp = 27136 bytes minimum
        guard dataSize >= 27136 else {
            return (nil, .Unknown)
        }

        // Check for palette at end (32 bytes for 16 RGB values)
        var palette = msxPalette
        if dataSize >= 27136 + 32 {
            // Extract palette (MSX2 format: 2 bytes per color, GRB format)
            palette = []
            let paletteOffset = offset + 27136
            for i in 0..<16 {
                if paletteOffset + i * 2 + 1 < data.count {
                    let byte1 = data[paletteOffset + i * 2]
                    let byte2 = data[paletteOffset + i * 2 + 1]
                    // MSX2 palette: xRRR xBBB xGGG (spread across bytes)
                    let r = UInt8((Int(byte1 & 0x07) * 255) / 7)
                    let b = UInt8((Int((byte1 >> 4) & 0x07) * 255) / 7)
                    let g = UInt8((Int(byte2 & 0x07) * 255) / 7)
                    palette.append((r: r, g: g, b: b))
                } else {
                    palette.append(msxPalette[i])
                }
            }
        }

        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)

        for y in 0..<height {
            for x in 0..<(width / 2) {
                let byteOffset = offset + y * 128 + x
                guard byteOffset < data.count else { continue }

                let byte = data[byteOffset]
                let pixel1 = Int((byte >> 4) & 0x0F)
                let pixel2 = Int(byte & 0x0F)

                // First pixel
                let bufferIdx1 = (y * width + x * 2) * 4
                let rgb1 = palette[pixel1]
                rgbaBuffer[bufferIdx1] = rgb1.r
                rgbaBuffer[bufferIdx1 + 1] = rgb1.g
                rgbaBuffer[bufferIdx1 + 2] = rgb1.b
                rgbaBuffer[bufferIdx1 + 3] = 255

                // Second pixel
                let bufferIdx2 = (y * width + x * 2 + 1) * 4
                let rgb2 = palette[pixel2]
                rgbaBuffer[bufferIdx2] = rgb2.r
                rgbaBuffer[bufferIdx2 + 1] = rgb2.g
                rgbaBuffer[bufferIdx2 + 2] = rgb2.b
                rgbaBuffer[bufferIdx2 + 3] = 255
            }
        }

        guard let cgImage = ImageHelpers.createCGImage(from: rgbaBuffer, width: width, height: height) else {
            return (nil, .Unknown)
        }

        return (cgImage, .MSX(mode: 5, colors: 16))
    }

    // MARK: - Screen 8 Decoder (MSX2 Graphics Mode 7)
    // Resolution: 256x212, 256 colors (8 bits per pixel)

    static func decodeScreen8(data: Data) -> (image: CGImage?, type: AppleIIImageType) {
        let width = 256
        let height = 212

        var offset = 0

        // Check for BSAVE header
        if data.count >= 7 && data[0] == 0xFE {
            offset = 7
        }

        let dataSize = data.count - offset

        // Screen 8: 256x212, 8bpp = 54272 bytes
        guard dataSize >= 54272 else {
            return (nil, .Unknown)
        }

        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)

        for y in 0..<height {
            for x in 0..<width {
                let byteOffset = offset + y * width + x
                guard byteOffset < data.count else { continue }

                let colorByte = data[byteOffset]
                // MSX2 Screen 8: GGGRRRBB format
                let g = UInt8((Int((colorByte >> 5) & 0x07) * 255) / 7)
                let r = UInt8((Int((colorByte >> 2) & 0x07) * 255) / 7)
                let b = UInt8((Int(colorByte & 0x03) * 255) / 3)

                let bufferIdx = (y * width + x) * 4
                rgbaBuffer[bufferIdx] = r
                rgbaBuffer[bufferIdx + 1] = g
                rgbaBuffer[bufferIdx + 2] = b
                rgbaBuffer[bufferIdx + 3] = 255
            }
        }

        guard let cgImage = ImageHelpers.createCGImage(from: rgbaBuffer, width: width, height: height) else {
            return (nil, .Unknown)
        }

        return (cgImage, .MSX(mode: 8, colors: 256))
    }

    // MARK: - Auto-detect MSX format by size

    static func decode(data: Data, filename: String? = nil) -> (image: CGImage?, type: AppleIIImageType) {
        var offset = 0

        // Check for BSAVE header
        if data.count >= 7 && data[0] == 0xFE {
            offset = 7
        }

        let dataSize = data.count - offset

        // Try to determine format by file extension
        let ext = filename?.split(separator: ".").last?.lowercased() ?? ""

        switch ext {
        case "sc1":
            return decodeScreen1(data: data)
        case "sc2", "sr2":
            return decodeScreen2(data: data)
        case "sc5", "sr5":
            return decodeScreen5(data: data)
        case "sc8", "sr8", "pic":
            if dataSize >= 54272 {
                return decodeScreen8(data: data)
            }
        default:
            break
        }

        // Auto-detect by size
        if dataSize >= 54272 {
            return decodeScreen8(data: data)
        } else if dataSize >= 27136 {
            return decodeScreen5(data: data)
        } else if dataSize >= 14336 || dataSize >= 6912 {
            return decodeScreen2(data: data)
        } else if dataSize >= 2048 {
            return decodeScreen1(data: data)
        }

        return (nil, .Unknown)
    }
}
