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

    static func decodeMode0(data: Data, palette: [Int]? = nil) -> (image: CGImage?, type: AppleIIImageType) {
        let width = 640
        let height = 256
        let expectedSize = 20480

        guard data.count >= expectedSize else {
            return (nil, .Unknown)
        }

        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)

        // Use custom palette if provided, otherwise default (black/white)
        let mode0Colors = palette ?? [0, 7]

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
                        let colorIndex = mode0Colors[Int(pixel)]
                        let rgb = bbcPalette[colorIndex]
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

    static func decodeMode1(data: Data, palette: [Int]? = nil) -> (image: CGImage?, type: AppleIIImageType) {
        let width = 320
        let height = 256
        let expectedSize = 20480

        guard data.count >= expectedSize else {
            return (nil, .Unknown)
        }

        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)

        // Use custom palette if provided, otherwise default: Black, Red, Yellow, White
        let mode1Colors = palette ?? [0, 1, 3, 7]

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
    // Output at 320x256 with 2x horizontal stretch for correct aspect ratio

    static func decodeMode2(data: Data) -> (image: CGImage?, type: AppleIIImageType) {
        let nativeWidth = 160
        let outputWidth = 320  // 2x horizontal stretch for correct aspect ratio
        let height = 256
        let expectedSize = 20480

        guard data.count >= expectedSize else {
            return (nil, .Unknown)
        }

        var rgbaBuffer = [UInt8](repeating: 0, count: outputWidth * height * 4)

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
                    // Bit layout: bits 7,5,3,1 = LEFT pixel, bits 6,4,2,0 = RIGHT pixel
                    // Left pixel (from odd bits)
                    let leftBit0 = (byte >> 1) & 1
                    let leftBit1 = (byte >> 3) & 1
                    let leftBit2 = (byte >> 5) & 1
                    let leftBit3 = (byte >> 7) & 1
                    let leftPixel = Int(leftBit0 | (leftBit1 << 1) | (leftBit2 << 2) | (leftBit3 << 3))

                    // Right pixel (from even bits)
                    let rightBit0 = (byte >> 0) & 1
                    let rightBit1 = (byte >> 2) & 1
                    let rightBit2 = (byte >> 4) & 1
                    let rightBit3 = (byte >> 6) & 1
                    let rightPixel = Int(rightBit0 | (rightBit1 << 1) | (rightBit2 << 2) | (rightBit3 << 3))

                    // Left pixel (doubled horizontally)
                    if baseX < nativeWidth && y < height {
                        let colorLeft = mode2LogicalPalette[leftPixel]
                        let rgbLeft = bbcPalette[colorLeft]
                        // Write two pixels for 2x horizontal stretch
                        for dx in 0..<2 {
                            let bufferIdx = (y * outputWidth + baseX * 2 + dx) * 4
                            rgbaBuffer[bufferIdx] = rgbLeft.r
                            rgbaBuffer[bufferIdx + 1] = rgbLeft.g
                            rgbaBuffer[bufferIdx + 2] = rgbLeft.b
                            rgbaBuffer[bufferIdx + 3] = 255
                        }
                    }

                    // Right pixel (doubled horizontally)
                    if baseX + 1 < nativeWidth && y < height {
                        let colorRight = mode2LogicalPalette[rightPixel]
                        let rgbRight = bbcPalette[colorRight]
                        // Write two pixels for 2x horizontal stretch
                        for dx in 0..<2 {
                            let bufferIdx = (y * outputWidth + (baseX + 1) * 2 + dx) * 4
                            rgbaBuffer[bufferIdx] = rgbRight.r
                            rgbaBuffer[bufferIdx + 1] = rgbRight.g
                            rgbaBuffer[bufferIdx + 2] = rgbRight.b
                            rgbaBuffer[bufferIdx + 3] = 255
                        }
                    }
                }
            }
        }

        guard let cgImage = ImageHelpers.createCGImage(from: rgbaBuffer, width: outputWidth, height: height) else {
            return (nil, .Unknown)
        }

        return (cgImage, .BBCMicro(mode: 2, colors: 16))
    }

    // MARK: - MODE 4 Decoder (320x256, 2 colors, 1bpp)
    // Screen memory: 10KB (0x2800 bytes)
    // Character-cell layout: 8 bytes per character column

    static func decodeMode4(data: Data, palette: [Int]? = nil) -> (image: CGImage?, type: AppleIIImageType) {
        let width = 320
        let height = 256
        let expectedSize = 10240

        guard data.count >= expectedSize else {
            return (nil, .Unknown)
        }

        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)

        // Use custom palette if provided, otherwise default (black/white)
        let mode4Colors = palette ?? [0, 7]

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
                        let colorIndex = mode4Colors[Int(pixel)]
                        let rgb = bbcPalette[colorIndex]
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

    // MARK: - MODE 5 Decoder (160x256 native, 4 colors, 2bpp)
    // Screen memory: 10KB (0x2800 bytes)
    // Character-cell layout: 8 bytes per character column
    // Output at 320x256 with 2x horizontal stretch for correct aspect ratio

    static func decodeMode5(data: Data, palette: [Int]? = nil) -> (image: CGImage?, type: AppleIIImageType) {
        let nativeWidth = 160
        let outputWidth = 320  // 2x horizontal stretch for correct aspect ratio
        let height = 256
        let expectedSize = 10240

        guard data.count >= expectedSize else {
            return (nil, .Unknown)
        }

        var rgbaBuffer = [UInt8](repeating: 0, count: outputWidth * height * 4)

        // Use custom palette if provided, otherwise default: Black, Red, Yellow, White
        let mode5Colors = palette ?? [0, 1, 3, 7]

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
                        guard x < nativeWidth && y < height else { continue }

                        // Write two pixels for 2x horizontal stretch
                        let rgb = bbcPalette[mode5Colors[colorIndex]]
                        for dx in 0..<2 {
                            let bufferIdx = (y * outputWidth + x * 2 + dx) * 4
                            rgbaBuffer[bufferIdx] = rgb.r
                            rgbaBuffer[bufferIdx + 1] = rgb.g
                            rgbaBuffer[bufferIdx + 2] = rgb.b
                            rgbaBuffer[bufferIdx + 3] = 255
                        }
                    }
                }
            }
        }

        guard let cgImage = ImageHelpers.createCGImage(from: rgbaBuffer, width: outputWidth, height: height) else {
            return (nil, .Unknown)
        }

        return (cgImage, .BBCMicro(mode: 5, colors: 4))
    }

    // MARK: - Embedded Palette Detection and Extraction
    // BitPast embeds palette info after screen data: mode byte + palette indices
    // Format: screen data (20480 or 10240) + mode (1 byte) + palette indices (2-8 bytes)

    private static func extractEmbeddedPalette(from data: Data) -> (mode: Int, palette: [Int], screenData: Data)? {
        let size = data.count

        // Expected sizes with embedded palette:
        // Mode 0: 20480 + 1 + 2 = 20483
        // Mode 1: 20480 + 1 + 4 = 20485
        // Mode 2: 20480 + 1 + 8 = 20489
        // Mode 4: 10240 + 1 + 2 = 10243
        // Mode 5: 10240 + 1 + 4 = 10245

        let possibleSizes: [(screenSize: Int, paletteCount: Int, mode: Int)] = [
            (20480, 2, 0),   // Mode 0
            (20480, 4, 1),   // Mode 1
            (20480, 8, 2),   // Mode 2
            (10240, 2, 4),   // Mode 4
            (10240, 4, 5),   // Mode 5
        ]

        for (screenSize, paletteCount, expectedMode) in possibleSizes {
            let expectedTotalSize = screenSize + 1 + paletteCount
            if size == expectedTotalSize {
                let modeByte = Int(data[screenSize])

                // Verify mode byte matches expected mode
                if modeByte == expectedMode {
                    var palette: [Int] = []
                    for i in 0..<paletteCount {
                        let paletteIndex = Int(data[screenSize + 1 + i])
                        // Validate palette index is in range (0-7)
                        if paletteIndex >= 0 && paletteIndex < 8 {
                            palette.append(paletteIndex)
                        } else {
                            return nil  // Invalid palette index
                        }
                    }

                    let screenData = data.prefix(screenSize)
                    return (modeByte, palette, Data(screenData))
                }
            }
        }

        return nil
    }

    // MARK: - Auto-detect BBC Micro format by size

    static func decode(data: Data, filename: String? = nil) -> (image: CGImage?, type: AppleIIImageType) {
        let dataSize = data.count

        // First, check for embedded palette data from BitPast
        if let embedded = extractEmbeddedPalette(from: data) {
            switch embedded.mode {
            case 0:
                return decodeMode0(data: embedded.screenData, palette: embedded.palette)
            case 1:
                return decodeMode1(data: embedded.screenData, palette: embedded.palette)
            case 2:
                return decodeMode2(data: embedded.screenData)  // Mode 2 uses all 8 colors, no custom palette needed
            case 4:
                return decodeMode4(data: embedded.screenData, palette: embedded.palette)
            case 5:
                return decodeMode5(data: embedded.screenData, palette: embedded.palette)
            default:
                break
            }
        }

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
