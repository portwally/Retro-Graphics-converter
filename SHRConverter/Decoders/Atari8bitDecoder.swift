import Foundation
import CoreGraphics

// MARK: - Atari 8-bit Graphics Decoder

class Atari8bitDecoder {

    // MARK: - Atari CTIA/GTIA Palette
    // 128 colors: 16 hues × 8 luminance levels
    // Based on Atari 800 NTSC palette

    static let atariPalette: [(r: UInt8, g: UInt8, b: UInt8)] = [
        // Hue 0 (Gray)
        (0x00, 0x00, 0x00), (0x1C, 0x1C, 0x1C), (0x39, 0x39, 0x39), (0x59, 0x59, 0x59),
        (0x7A, 0x7A, 0x7A), (0x9C, 0x9C, 0x9C), (0xBC, 0xBC, 0xBC), (0xDC, 0xDC, 0xDC),
        // Hue 1 (Gold/Orange)
        (0x26, 0x10, 0x00), (0x44, 0x2C, 0x00), (0x64, 0x4C, 0x0C), (0x84, 0x6C, 0x2C),
        (0xA4, 0x8C, 0x4C), (0xC4, 0xAC, 0x6C), (0xE4, 0xCC, 0x8C), (0xFF, 0xEC, 0xAC),
        // Hue 2 (Orange)
        (0x39, 0x04, 0x00), (0x5A, 0x20, 0x00), (0x7A, 0x40, 0x00), (0x9A, 0x60, 0x14),
        (0xBA, 0x80, 0x34), (0xDA, 0xA0, 0x54), (0xFA, 0xC0, 0x74), (0xFF, 0xE0, 0x94),
        // Hue 3 (Red-Orange)
        (0x45, 0x00, 0x00), (0x66, 0x14, 0x00), (0x86, 0x34, 0x0C), (0xA6, 0x54, 0x2C),
        (0xC6, 0x74, 0x4C), (0xE6, 0x94, 0x6C), (0xFF, 0xB4, 0x8C), (0xFF, 0xD4, 0xAC),
        // Hue 4 (Pink/Red)
        (0x4A, 0x00, 0x08), (0x6A, 0x0C, 0x18), (0x8A, 0x2C, 0x38), (0xAA, 0x4C, 0x58),
        (0xCA, 0x6C, 0x78), (0xEA, 0x8C, 0x98), (0xFF, 0xAC, 0xB8), (0xFF, 0xCC, 0xD8),
        // Hue 5 (Purple)
        (0x46, 0x00, 0x2C), (0x66, 0x08, 0x44), (0x86, 0x28, 0x64), (0xA6, 0x48, 0x84),
        (0xC6, 0x68, 0xA4), (0xE6, 0x88, 0xC4), (0xFF, 0xA8, 0xE4), (0xFF, 0xC8, 0xFF),
        // Hue 6 (Purple-Blue)
        (0x3A, 0x00, 0x4C), (0x58, 0x04, 0x68), (0x78, 0x24, 0x88), (0x98, 0x44, 0xA8),
        (0xB8, 0x64, 0xC8), (0xD8, 0x84, 0xE8), (0xF8, 0xA4, 0xFF), (0xFF, 0xC4, 0xFF),
        // Hue 7 (Blue)
        (0x26, 0x00, 0x64), (0x42, 0x08, 0x80), (0x62, 0x28, 0xA0), (0x82, 0x48, 0xC0),
        (0xA2, 0x68, 0xE0), (0xC2, 0x88, 0xFF), (0xE2, 0xA8, 0xFF), (0xFF, 0xC8, 0xFF),
        // Hue 8 (Blue)
        (0x10, 0x00, 0x70), (0x28, 0x10, 0x8C), (0x48, 0x30, 0xAC), (0x68, 0x50, 0xCC),
        (0x88, 0x70, 0xEC), (0xA8, 0x90, 0xFF), (0xC8, 0xB0, 0xFF), (0xE8, 0xD0, 0xFF),
        // Hue 9 (Light Blue)
        (0x00, 0x00, 0x6C), (0x08, 0x18, 0x8C), (0x28, 0x38, 0xAC), (0x48, 0x58, 0xCC),
        (0x68, 0x78, 0xEC), (0x88, 0x98, 0xFF), (0xA8, 0xB8, 0xFF), (0xC8, 0xD8, 0xFF),
        // Hue 10 (Cyan-Blue)
        (0x00, 0x04, 0x5C), (0x00, 0x24, 0x7C), (0x14, 0x44, 0x9C), (0x34, 0x64, 0xBC),
        (0x54, 0x84, 0xDC), (0x74, 0xA4, 0xFC), (0x94, 0xC4, 0xFF), (0xB4, 0xE4, 0xFF),
        // Hue 11 (Cyan)
        (0x00, 0x10, 0x44), (0x00, 0x30, 0x64), (0x04, 0x50, 0x84), (0x24, 0x70, 0xA4),
        (0x44, 0x90, 0xC4), (0x64, 0xB0, 0xE4), (0x84, 0xD0, 0xFF), (0xA4, 0xF0, 0xFF),
        // Hue 12 (Cyan-Green)
        (0x00, 0x1C, 0x28), (0x00, 0x3C, 0x48), (0x00, 0x5C, 0x68), (0x14, 0x7C, 0x88),
        (0x34, 0x9C, 0xA8), (0x54, 0xBC, 0xC8), (0x74, 0xDC, 0xE8), (0x94, 0xFC, 0xFF),
        // Hue 13 (Green)
        (0x00, 0x24, 0x0C), (0x00, 0x44, 0x24), (0x04, 0x64, 0x44), (0x24, 0x84, 0x64),
        (0x44, 0xA4, 0x84), (0x64, 0xC4, 0xA4), (0x84, 0xE4, 0xC4), (0xA4, 0xFF, 0xE4),
        // Hue 14 (Yellow-Green)
        (0x00, 0x28, 0x00), (0x0C, 0x48, 0x04), (0x2C, 0x68, 0x24), (0x4C, 0x88, 0x44),
        (0x6C, 0xA8, 0x64), (0x8C, 0xC8, 0x84), (0xAC, 0xE8, 0xA4), (0xCC, 0xFF, 0xC4),
        // Hue 15 (Yellow)
        (0x14, 0x24, 0x00), (0x34, 0x44, 0x00), (0x54, 0x64, 0x0C), (0x74, 0x84, 0x2C),
        (0x94, 0xA4, 0x4C), (0xB4, 0xC4, 0x6C), (0xD4, 0xE4, 0x8C), (0xF4, 0xFF, 0xAC),
    ]

    // MARK: - Default 4-Color Palette for GR.15/GR.7
    // Colors typically used: background, PF0, PF1, PF2
    // Using a visible grayscale palette: black, dark gray, medium gray, light gray
    static let defaultGR15Palette: [Int] = [0, 2, 4, 7]  // Grayscale for visibility

    // MARK: - Extract embedded palette from BitPast files
    // BitPast appends Atari color registers after the 7680-byte bitmap
    // Register format: HHHHLLLL where H=hue(4 bits), L=luminance*2(4 bits)

    static func extractEmbeddedPalette(data: Data, bitmapSize: Int, numColors: Int) -> [Int]? {
        let paletteOffset = bitmapSize
        guard data.count >= paletteOffset + numColors else {
            return nil
        }

        var palette: [Int] = []
        for i in 0..<numColors {
            let register = data[paletteOffset + i]
            // Convert Atari register to palette index
            // Register: HHHHLLLL (hue in high nibble, lum*2 in low nibble)
            let hue = Int(register >> 4) & 0x0F
            let lum = Int(register >> 1) & 0x07
            let paletteIndex = hue * 8 + lum
            palette.append(paletteIndex)
        }

        return palette
    }

    // MARK: - Graphics 8 Decoder (Hi-Res)
    // Resolution: 320×192, 1 bit per pixel (monochrome)
    // File size: 7,680 bytes (+ optional 2 bytes palette)

    static func decodeGR8(data: Data, bgColor: Int = 0, fgColor: Int = 7) -> (image: CGImage?, type: AppleIIImageType) {
        let expectedSize = 7680
        guard data.count >= expectedSize else {
            return (nil, .Unknown)
        }

        let width = 320
        let height = 192
        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)

        // Check for embedded palette from BitPast (2 colors for GR.8)
        var finalBg = bgColor
        var finalFg = fgColor
        if let embedded = extractEmbeddedPalette(data: data, bitmapSize: expectedSize, numColors: 2) {
            finalBg = embedded[0]
            finalFg = embedded[1]
        }

        let bg = atariPalette[finalBg % 128]
        let fg = atariPalette[finalFg % 128]

        for y in 0..<height {
            for xByte in 0..<40 {
                let byteOffset = y * 40 + xByte
                guard byteOffset < data.count else { continue }

                let byte = data[byteOffset]

                for bit in 0..<8 {
                    let x = xByte * 8 + bit
                    let isSet = (byte >> (7 - bit)) & 1 == 1
                    let color = isSet ? fg : bg

                    let bufferIdx = (y * width + x) * 4
                    rgbaBuffer[bufferIdx] = color.r
                    rgbaBuffer[bufferIdx + 1] = color.g
                    rgbaBuffer[bufferIdx + 2] = color.b
                    rgbaBuffer[bufferIdx + 3] = 255
                }
            }
        }

        guard let cgImage = ImageHelpers.createCGImage(from: rgbaBuffer, width: width, height: height) else {
            return (nil, .Unknown)
        }

        return (cgImage, .Atari8bit(mode: "GR.8", colors: 2))
    }

    // MARK: - Graphics 9 Decoder (GTIA Mode 1 - 16 shades)
    // Resolution: 80×192 native, displayed as 160×192 (2x horizontal for correct aspect)
    // File size: 7,680 bytes (+ optional 16 bytes palette)

    static func decodeGR9(data: Data, hue: Int = 0) -> (image: CGImage?, type: AppleIIImageType) {
        let expectedSize = 7680
        guard data.count >= expectedSize else {
            return (nil, .Unknown)
        }

        let nativeWidth = 80
        let height = 192
        let displayWidth = 160  // 2x horizontal for correct aspect ratio
        var rgbaBuffer = [UInt8](repeating: 0, count: displayWidth * height * 4)

        // Check for embedded palette from BitPast (16 shades)
        // For GR.9, we extract the hue from the first register value
        var finalHue = hue
        if let embedded = extractEmbeddedPalette(data: data, bitmapSize: expectedSize, numColors: 1) {
            // Extract hue from first palette entry
            finalHue = embedded[0] / 8
        }

        // GR.9 uses 16 luminance levels of one hue
        // Build palette for this mode (hue × 8 luminances, interpolated to 16)
        let baseIndex = (finalHue % 16) * 8

        for y in 0..<height {
            for xByte in 0..<40 {
                let byteOffset = y * 40 + xByte
                guard byteOffset < data.count else { continue }

                let byte = data[byteOffset]

                // Two pixels per byte (high nibble, low nibble)
                let pixel1 = Int((byte >> 4) & 0x0F)
                let pixel2 = Int(byte & 0x0F)

                for (pixelIdx, luminance) in [(0, pixel1), (1, pixel2)] {
                    let nativeX = xByte * 2 + pixelIdx

                    // Map 16 luminance levels to 8 palette entries
                    let palIdx = baseIndex + (luminance / 2)
                    let color = atariPalette[palIdx % 128]

                    // Double pixels horizontally for correct aspect ratio
                    for dx in 0..<2 {
                        let displayX = nativeX * 2 + dx
                        let bufferIdx = (y * displayWidth + displayX) * 4
                        rgbaBuffer[bufferIdx] = color.r
                        rgbaBuffer[bufferIdx + 1] = color.g
                        rgbaBuffer[bufferIdx + 2] = color.b
                        rgbaBuffer[bufferIdx + 3] = 255
                    }
                }
            }
        }

        guard let cgImage = ImageHelpers.createCGImage(from: rgbaBuffer, width: displayWidth, height: height) else {
            return (nil, .Unknown)
        }

        return (cgImage, .Atari8bit(mode: "GR.9", colors: 8))
    }

    // MARK: - Graphics 15 Decoder (4 colors)
    // Resolution: 160×192, 2 bits per pixel
    // File size: 7,680 bytes (+ optional 4 bytes palette)

    static func decodeGR15(data: Data, palette: [Int]? = nil) -> (image: CGImage?, type: AppleIIImageType) {
        let expectedSize = 7680
        guard data.count >= expectedSize else {
            return (nil, .Unknown)
        }

        let width = 160
        let height = 192
        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)

        // Check for embedded palette from BitPast (4 colors for GR.15)
        var colorIndices: [Int]
        if let userPalette = palette {
            colorIndices = userPalette
        } else if let embedded = extractEmbeddedPalette(data: data, bitmapSize: expectedSize, numColors: 4) {
            colorIndices = embedded
        } else {
            colorIndices = defaultGR15Palette
        }

        for y in 0..<height {
            for xByte in 0..<40 {
                let byteOffset = y * 40 + xByte
                guard byteOffset < data.count else { continue }

                let byte = data[byteOffset]

                // 4 pixels per byte, 2 bits each
                for pixelIdx in 0..<4 {
                    let shift = 6 - (pixelIdx * 2)
                    let colorIdx = Int((byte >> shift) & 0x03)
                    let palIdx = colorIndices[colorIdx] % 128
                    let color = atariPalette[palIdx]

                    let x = xByte * 4 + pixelIdx
                    let bufferIdx = (y * width + x) * 4
                    rgbaBuffer[bufferIdx] = color.r
                    rgbaBuffer[bufferIdx + 1] = color.g
                    rgbaBuffer[bufferIdx + 2] = color.b
                    rgbaBuffer[bufferIdx + 3] = 255
                }
            }
        }

        guard let cgImage = ImageHelpers.createCGImage(from: rgbaBuffer, width: width, height: height) else {
            return (nil, .Unknown)
        }

        return (cgImage, .Atari8bit(mode: "GR.15", colors: 4))
    }

    // MARK: - Graphics 7 Decoder (alias for GR.15 with different aspect)
    // Same format as GR.15 but often used with different palettes

    static func decodeGR7(data: Data, palette: [Int]? = nil) -> (image: CGImage?, type: AppleIIImageType) {
        let result = decodeGR15(data: data, palette: palette)
        if result.image != nil {
            return (result.image, .Atari8bit(mode: "GR.7", colors: 4))
        }
        return result
    }

    // MARK: - MicroIllustrator Decoder (.MIC)
    // Koala-style format for Atari: 7680 bytes bitmap + 40 bytes color info

    static func decodeMIC(data: Data) -> (image: CGImage?, type: AppleIIImageType) {
        // MIC files can vary in size - check for minimum
        guard data.count >= 7680 else {
            return (nil, .Unknown)
        }

        // Try to extract color info if present
        var palette = defaultGR15Palette

        // Some MIC files have color registers at the end
        if data.count >= 7720 {
            // Try to read color registers from after bitmap data
            let colorOffset = 7680
            palette = [
                Int(data[colorOffset]) >> 1,     // Background
                Int(data[colorOffset + 1]) >> 1, // PF0
                Int(data[colorOffset + 2]) >> 1, // PF1
                Int(data[colorOffset + 3]) >> 1  // PF2
            ]
        }

        // Decode as GR.15/GR.7 format
        return decodeGR15(data: data, palette: palette)
    }

    // MARK: - Graphics 11 Decoder (GTIA Mode 3 - 16 colors)
    // Resolution: 80×192 native, displayed as 160×192 (2x horizontal for correct aspect)
    // File size: 7,680 bytes (+ optional 16 bytes palette)

    static func decodeGR11(data: Data, luminance: Int = 6) -> (image: CGImage?, type: AppleIIImageType) {
        let expectedSize = 7680
        guard data.count >= expectedSize else {
            return (nil, .Unknown)
        }

        let nativeWidth = 80
        let height = 192
        let displayWidth = 160  // 2x horizontal for correct aspect ratio
        var rgbaBuffer = [UInt8](repeating: 0, count: displayWidth * height * 4)

        // Check for embedded palette from BitPast (16 hues at fixed luminance)
        // For GR.11, we extract luminance from the first register value
        var finalLuminance = luminance
        if let embedded = extractEmbeddedPalette(data: data, bitmapSize: expectedSize, numColors: 1) {
            // Extract luminance from first palette entry (stored as lum index 0-7)
            finalLuminance = (embedded[0] % 8) * 2
        }

        // GR.11 uses 16 hues at one luminance level
        let lumIndex = (finalLuminance / 2) % 8

        for y in 0..<height {
            for xByte in 0..<40 {
                let byteOffset = y * 40 + xByte
                guard byteOffset < data.count else { continue }

                let byte = data[byteOffset]

                // Two pixels per byte
                let pixel1 = Int((byte >> 4) & 0x0F)
                let pixel2 = Int(byte & 0x0F)

                for (pixelIdx, hue) in [(0, pixel1), (1, pixel2)] {
                    let nativeX = xByte * 2 + pixelIdx

                    // Map hue (0-15) to palette index
                    let palIdx = (hue * 8) + lumIndex
                    let color = atariPalette[palIdx % 128]

                    // Double pixels horizontally for correct aspect ratio
                    for dx in 0..<2 {
                        let displayX = nativeX * 2 + dx
                        let bufferIdx = (y * displayWidth + displayX) * 4
                        rgbaBuffer[bufferIdx] = color.r
                        rgbaBuffer[bufferIdx + 1] = color.g
                        rgbaBuffer[bufferIdx + 2] = color.b
                        rgbaBuffer[bufferIdx + 3] = 255
                    }
                }
            }
        }

        guard let cgImage = ImageHelpers.createCGImage(from: rgbaBuffer, width: displayWidth, height: height) else {
            return (nil, .Unknown)
        }

        return (cgImage, .Atari8bit(mode: "GR.11", colors: 16))
    }

    // MARK: - Graphics 10 Decoder (GTIA Mode 2 - 9 colors)
    // Resolution: 80×192 native, displayed as 160×192 (2x horizontal for correct aspect)
    // File size: 7,680 bytes (+ optional 9 bytes palette)

    static func decodeGR10(data: Data, palette: [Int]? = nil) -> (image: CGImage?, type: AppleIIImageType) {
        let expectedSize = 7680
        guard data.count >= expectedSize else {
            return (nil, .Unknown)
        }

        let nativeWidth = 80
        let height = 192
        let displayWidth = 160  // 2x horizontal for correct aspect ratio
        var rgbaBuffer = [UInt8](repeating: 0, count: displayWidth * height * 4)

        // Check for embedded palette from BitPast (9 colors for GR.10)
        var colorIndices: [Int]
        if let userPalette = palette {
            colorIndices = userPalette
        } else if let embedded = extractEmbeddedPalette(data: data, bitmapSize: expectedSize, numColors: 9) {
            colorIndices = embedded
        } else {
            // Default 9-color palette (grayscale progression)
            colorIndices = [0, 1, 2, 3, 4, 5, 6, 7, 7]  // Black to white
        }

        // Ensure we have 9 colors (pad if needed)
        while colorIndices.count < 9 {
            colorIndices.append(0)
        }

        for y in 0..<height {
            for xByte in 0..<40 {
                let byteOffset = y * 40 + xByte
                guard byteOffset < data.count else { continue }

                let byte = data[byteOffset]

                // Two pixels per byte (high nibble, low nibble)
                let pixel1 = Int((byte >> 4) & 0x0F)
                let pixel2 = Int(byte & 0x0F)

                for (pixelIdx, colorIdx) in [(0, pixel1), (1, pixel2)] {
                    let nativeX = xByte * 2 + pixelIdx

                    // GR.10 uses values 0-8 for 9 colors, 9-15 wrap/repeat
                    let palIdx = colorIndices[min(colorIdx, 8) % 9] % 128
                    let color = atariPalette[palIdx]

                    // Double pixels horizontally for correct aspect ratio
                    for dx in 0..<2 {
                        let displayX = nativeX * 2 + dx
                        let bufferIdx = (y * displayWidth + displayX) * 4
                        rgbaBuffer[bufferIdx] = color.r
                        rgbaBuffer[bufferIdx + 1] = color.g
                        rgbaBuffer[bufferIdx + 2] = color.b
                        rgbaBuffer[bufferIdx + 3] = 255
                    }
                }
            }
        }

        guard let cgImage = ImageHelpers.createCGImage(from: rgbaBuffer, width: displayWidth, height: height) else {
            return (nil, .Unknown)
        }

        return (cgImage, .Atari8bit(mode: "GR.10", colors: 9))
    }

    // MARK: - Auto-detect and decode

    static func decode(data: Data, filename: String? = nil) -> (image: CGImage?, type: AppleIIImageType) {
        let ext = filename?.split(separator: ".").last?.lowercased() ?? ""

        // Try by extension first
        switch ext {
        case "gr8":
            return decodeGR8(data: data)
        case "gr9":
            return decodeGR9(data: data)
        case "gr15", "gr7":
            return decodeGR15(data: data)
        case "gr10":
            return decodeGR10(data: data)
        case "gr11":
            return decodeGR11(data: data)
        case "gr1", "gr2", "gr3", "gr4", "gr5", "gr6":
            // BitPast exports - extension gets truncated by Atari DOS
            // Detect by embedded palette size: GR.10 = 7689 (9 colors), GR.15 = 7684 (4 colors)
            if data.count == 7689 {
                return decodeGR10(data: data)
            } else if data.count >= 7680 {
                return decodeGR15(data: data)
            }
        case "mic":
            return decodeMIC(data: data)
        case "pic":
            // Generic "PIC" - try to detect format
            if data.count >= 7680 {
                // Try GR.15/GR.7 first (most common for art)
                let result = decodeGR15(data: data)
                if result.image != nil {
                    return result
                }
            }
        default:
            break
        }

        // Auto-detect by size
        if data.count == 7680 {
            // Could be GR.8, GR.9, GR.15 - default to GR.15 for art files
            return decodeGR15(data: data)
        } else if data.count >= 7680 && data.count <= 7800 {
            // Likely MIC format with color data
            return decodeMIC(data: data)
        }

        return (nil, .Unknown)
    }
}
