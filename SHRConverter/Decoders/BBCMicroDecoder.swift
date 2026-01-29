import Foundation
import CoreGraphics

// MARK: - BBC Micro Graphics Decoder

class BBCMicroDecoder {

    // MARK: - BBC Micro Palette (8 physical colors, 3-bit RGB)

    static let bbcPalette: [(r: UInt8, g: UInt8, b: UInt8)] = [
        (0x00, 0x00, 0x00),  // 0: Black
        (0xFF, 0x00, 0x00),  // 1: Red
        (0x00, 0xFF, 0x00),  // 2: Green
        (0xFF, 0xFF, 0x00),  // 3: Yellow
        (0x00, 0x00, 0xFF),  // 4: Blue
        (0xFF, 0x00, 0xFF),  // 5: Magenta
        (0x00, 0xFF, 0xFF),  // 6: Cyan
        (0xFF, 0xFF, 0xFF)   // 7: White
    ]

    // MODE 2 logical colors (16 colors mapped to 8 physical + flash)
    // For simplicity, we map the 16 logical colors to physical colors
    static let mode2LogicalPalette: [Int] = [
        0, 1, 2, 3, 4, 5, 6, 7,  // Colors 0-7 map directly
        0, 1, 2, 3, 4, 5, 6, 7   // Colors 8-15 are flashing versions (show as same)
    ]

    // MARK: - MODE 0 Decoder (640x256, 2 colors, 1bpp)
    // Screen memory: 20KB (0x5000 bytes)
    // BBC Micro uses character-cell organization: 8 consecutive bytes form a vertical column of 8 pixels

    static func decodeMode0(data: Data) -> (image: CGImage?, type: AppleIIImageType) {
        let width = 640
        let height = 256
        let expectedSize = 20480

        guard data.count >= expectedSize else {
            return (nil, .Unknown)
        }

        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)

        // BBC Micro MODE 0: character-cell based layout
        // Each character cell is 8x8 pixels
        // Memory is organized: 8 bytes per character column, then next column
        // 80 character columns per character row, 32 character rows
        let charsPerRow = 80
        let charRows = 32

        for charRow in 0..<charRows {
            for charCol in 0..<charsPerRow {
                let baseOffset = (charRow * charsPerRow + charCol) * 8

                for row in 0..<8 {
                    let offset = baseOffset + row
                    guard offset < data.count else { continue }

                    let byte = data[offset]
                    let y = charRow * 8 + row
                    let baseX = charCol * 8

                    // Each byte contains 8 horizontal pixels (MSB = leftmost)
                    for bit in 0..<8 {
                        let pixel = (byte >> (7 - bit)) & 1
                        let x = baseX + bit

                        guard x < width && y < height else { continue }
                        let bufferIdx = (y * width + x) * 4
                        let rgb = bbcPalette[pixel == 1 ? 7 : 0]
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

        return (cgImage, .BBCMicro(mode: 0, colors: 2))
    }

    // MARK: - MODE 1 Decoder (320x256, 4 colors, 2bpp)
    // Screen memory: 20KB (0x5000 bytes)
    // Character-cell layout: 8 bytes per character column

    static func decodeMode1(data: Data) -> (image: CGImage?, type: AppleIIImageType) {
        let width = 320
        let height = 256
        let expectedSize = 20480

        guard data.count >= expectedSize else {
            return (nil, .Unknown)
        }

        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)

        // Default MODE 1 palette: Black, Red, Yellow, White
        let mode1Colors = [0, 1, 3, 7]

        // MODE 1: 80 character columns, 32 character rows
        // Each character is 4 pixels wide (2bpp), 8 pixels tall
        let charsPerRow = 80
        let charRows = 32

        for charRow in 0..<charRows {
            for charCol in 0..<charsPerRow {
                let baseOffset = (charRow * charsPerRow + charCol) * 8

                for row in 0..<8 {
                    let offset = baseOffset + row
                    guard offset < data.count else { continue }

                    let byte = data[offset]
                    let y = charRow * 8 + row
                    let baseX = charCol * 4

                    // MODE 1: 2 bits per pixel, interleaved bit pattern
                    // Bit layout: p0b1 p1b1 p2b1 p3b1 p0b0 p1b0 p2b0 p3b0
                    for pixel in 0..<4 {
                        let bit0 = (byte >> (3 - pixel)) & 1
                        let bit1 = (byte >> (7 - pixel)) & 1
                        let colorIndex = Int(bit0 | (bit1 << 1))

                        let x = baseX + pixel
                        guard x < width && y < height else { continue }
                        let bufferIdx = (y * width + x) * 4
                        let rgb = bbcPalette[mode1Colors[colorIndex]]
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

        return (cgImage, .BBCMicro(mode: 1, colors: 4))
    }

    // MARK: - MODE 2 Decoder (160x256, 16 logical colors, 4bpp)
    // Screen memory: 20KB (0x5000 bytes)
    // Character-cell layout: 8 bytes per character column

    static func decodeMode2(data: Data) -> (image: CGImage?, type: AppleIIImageType) {
        let width = 160
        let height = 256
        let expectedSize = 20480

        guard data.count >= expectedSize else {
            return (nil, .Unknown)
        }

        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)

        // MODE 2: 80 character columns, 32 character rows
        // Each character is 2 pixels wide (4bpp), 8 pixels tall
        let charsPerRow = 80
        let charRows = 32

        for charRow in 0..<charRows {
            for charCol in 0..<charsPerRow {
                let baseOffset = (charRow * charsPerRow + charCol) * 8

                for row in 0..<8 {
                    let offset = baseOffset + row
                    guard offset < data.count else { continue }

                    let byte = data[offset]
                    let y = charRow * 8 + row
                    let baseX = charCol * 2

                    // MODE 2: 4 bits per pixel, 2 pixels per byte
                    // Bit layout is interleaved: p0b3 p1b3 p0b2 p1b2 p0b1 p1b1 p0b0 p1b0
                    let bit0_p0 = (byte >> 0) & 1
                    let bit1_p0 = (byte >> 2) & 1
                    let bit2_p0 = (byte >> 4) & 1
                    let bit3_p0 = (byte >> 6) & 1
                    let pixel0 = Int(bit0_p0 | (bit1_p0 << 1) | (bit2_p0 << 2) | (bit3_p0 << 3))

                    let bit0_p1 = (byte >> 1) & 1
                    let bit1_p1 = (byte >> 3) & 1
                    let bit2_p1 = (byte >> 5) & 1
                    let bit3_p1 = (byte >> 7) & 1
                    let pixel1 = Int(bit0_p1 | (bit1_p1 << 1) | (bit2_p1 << 2) | (bit3_p1 << 3))

                    // First pixel
                    if baseX < width && y < height {
                        let bufferIdx0 = (y * width + baseX) * 4
                        let color0 = mode2LogicalPalette[pixel0]
                        let rgb0 = bbcPalette[color0]
                        rgbaBuffer[bufferIdx0] = rgb0.r
                        rgbaBuffer[bufferIdx0 + 1] = rgb0.g
                        rgbaBuffer[bufferIdx0 + 2] = rgb0.b
                        rgbaBuffer[bufferIdx0 + 3] = 255
                    }

                    // Second pixel
                    if baseX + 1 < width && y < height {
                        let bufferIdx1 = (y * width + baseX + 1) * 4
                        let color1 = mode2LogicalPalette[pixel1]
                        let rgb1 = bbcPalette[color1]
                        rgbaBuffer[bufferIdx1] = rgb1.r
                        rgbaBuffer[bufferIdx1 + 1] = rgb1.g
                        rgbaBuffer[bufferIdx1 + 2] = rgb1.b
                        rgbaBuffer[bufferIdx1 + 3] = 255
                    }
                }
            }
        }

        guard let cgImage = ImageHelpers.createCGImage(from: rgbaBuffer, width: width, height: height) else {
            return (nil, .Unknown)
        }

        return (cgImage, .BBCMicro(mode: 2, colors: 16))
    }

    // MARK: - MODE 4 Decoder (320x256, 2 colors, 1bpp)
    // Screen memory: 10KB (0x2800 bytes)
    // Character-cell layout: 8 bytes per character column

    static func decodeMode4(data: Data) -> (image: CGImage?, type: AppleIIImageType) {
        let width = 320
        let height = 256
        let expectedSize = 10240

        guard data.count >= expectedSize else {
            return (nil, .Unknown)
        }

        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)

        // MODE 4: 40 character columns, 32 character rows
        // Each character is 8 pixels wide (1bpp), 8 pixels tall
        let charsPerRow = 40
        let charRows = 32

        for charRow in 0..<charRows {
            for charCol in 0..<charsPerRow {
                let baseOffset = (charRow * charsPerRow + charCol) * 8

                for row in 0..<8 {
                    let offset = baseOffset + row
                    guard offset < data.count else { continue }

                    let byte = data[offset]
                    let y = charRow * 8 + row
                    let baseX = charCol * 8

                    for bit in 0..<8 {
                        let pixel = (byte >> (7 - bit)) & 1
                        let x = baseX + bit

                        guard x < width && y < height else { continue }
                        let bufferIdx = (y * width + x) * 4
                        let rgb = bbcPalette[pixel == 1 ? 7 : 0]
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

        return (cgImage, .BBCMicro(mode: 4, colors: 2))
    }

    // MARK: - MODE 5 Decoder (160x256, 4 colors, 2bpp)
    // Screen memory: 10KB (0x2800 bytes)
    // Character-cell layout: 8 bytes per character column

    static func decodeMode5(data: Data) -> (image: CGImage?, type: AppleIIImageType) {
        let width = 160
        let height = 256
        let expectedSize = 10240

        guard data.count >= expectedSize else {
            return (nil, .Unknown)
        }

        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)

        // Default MODE 5 palette
        let mode5Colors = [0, 1, 3, 7]  // Black, Red, Yellow, White

        // MODE 5: 40 character columns, 32 character rows
        // Each character is 4 pixels wide (2bpp), 8 pixels tall
        let charsPerRow = 40
        let charRows = 32

        for charRow in 0..<charRows {
            for charCol in 0..<charsPerRow {
                let baseOffset = (charRow * charsPerRow + charCol) * 8

                for row in 0..<8 {
                    let offset = baseOffset + row
                    guard offset < data.count else { continue }

                    let byte = data[offset]
                    let y = charRow * 8 + row
                    let baseX = charCol * 4

                    // 2 bits per pixel, 4 pixels per byte (interleaved)
                    for pixel in 0..<4 {
                        let bit0 = (byte >> (3 - pixel)) & 1
                        let bit1 = (byte >> (7 - pixel)) & 1
                        let colorIndex = Int(bit0 | (bit1 << 1))

                        let x = baseX + pixel
                        guard x < width && y < height else { continue }
                        let bufferIdx = (y * width + x) * 4
                        let rgb = bbcPalette[mode5Colors[colorIndex]]
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

        return (cgImage, .BBCMicro(mode: 5, colors: 4))
    }

    // MARK: - Auto-detect BBC Micro format by size

    static func decode(data: Data, filename: String? = nil) -> (image: CGImage?, type: AppleIIImageType) {
        let dataSize = data.count

        // Try to determine mode by file extension
        let ext = filename?.split(separator: ".").last?.lowercased() ?? ""

        switch ext {
        case "bbm0", "mode0":
            return decodeMode0(data: data)
        case "bbm1", "mode1":
            return decodeMode1(data: data)
        case "bbm2", "mode2":
            return decodeMode2(data: data)
        case "bbm4", "mode4":
            return decodeMode4(data: data)
        case "bbm5", "mode5":
            return decodeMode5(data: data)
        default:
            break
        }

        // Try to parse mode from filename (e.g., "bbc micro mode 0.bbc", "picture_mode2.bbc")
        if let name = filename?.lowercased() {
            // Look for "mode X" or "mode_X" or "modeX" patterns
            if name.contains("mode 0") || name.contains("mode_0") || name.contains("mode0") {
                return decodeMode0(data: data)
            }
            if name.contains("mode 1") || name.contains("mode_1") || name.contains("mode1") {
                return decodeMode1(data: data)
            }
            if name.contains("mode 2") || name.contains("mode_2") || name.contains("mode2") {
                return decodeMode2(data: data)
            }
            if name.contains("mode 4") || name.contains("mode_4") || name.contains("mode4") {
                return decodeMode4(data: data)
            }
            if name.contains("mode 5") || name.contains("mode_5") || name.contains("mode5") {
                return decodeMode5(data: data)
            }
        }

        // Auto-detect by size
        // 20KB files could be MODE 0, 1, or 2
        // 10KB files could be MODE 4 or 5

        if dataSize == 20480 || dataSize == 20736 {  // 20KB or with header
            // Default to MODE 1 (most common for graphics)
            return decodeMode1(data: data)
        } else if dataSize == 10240 || dataSize == 10496 {  // 10KB or with header
            // Default to MODE 5 (more colorful)
            return decodeMode5(data: data)
        }

        // Try MODE 1 as default for unknown sizes >= 20KB
        if dataSize >= 20480 {
            return decodeMode1(data: data)
        } else if dataSize >= 10240 {
            return decodeMode5(data: data)
        }

        return (nil, .Unknown)
    }
}
