import Foundation
import CoreGraphics

// MARK: - Commodore VIC-20 Decoder

class VIC20Decoder {

    // VIC-20 screen dimensions
    static let screenWidth = 176   // 22 characters × 8 pixels
    static let screenHeight = 184  // 23 characters × 8 pixels
    static let charsX = 22
    static let charsY = 23
    static let cellCount = 506     // 22 × 23

    // VIC-20 palette (16 colors)
    // First 8 colors can be foreground, all 16 can be background
    static let vic20Palette: [(r: UInt8, g: UInt8, b: UInt8)] = [
        (0x00, 0x00, 0x00),  // 0: Black
        (0xFF, 0xFF, 0xFF),  // 1: White
        (0xF0, 0x00, 0x00),  // 2: Red
        (0x00, 0xF0, 0xF0),  // 3: Cyan
        (0x60, 0x00, 0x60),  // 4: Purple
        (0x00, 0xA0, 0x00),  // 5: Green
        (0x00, 0x00, 0xF0),  // 6: Blue
        (0xD0, 0xD0, 0x00),  // 7: Yellow
        (0xC0, 0xA0, 0x00),  // 8: Orange
        (0xFF, 0xA0, 0x00),  // 9: Light Orange
        (0xF0, 0x80, 0x80),  // 10: Light Red (Pink)
        (0x00, 0xFF, 0xFF),  // 11: Light Cyan
        (0xFF, 0x00, 0xFF),  // 12: Light Purple (Magenta)
        (0x00, 0xFF, 0x00),  // 13: Light Green
        (0x00, 0xA0, 0xFF),  // 14: Light Blue
        (0xFF, 0xFF, 0x00)   // 15: Light Yellow
    ]

    // MARK: - Main Decode Function

    static func decode(data: Data, filename: String? = nil) -> (image: CGImage?, type: AppleIIImageType) {
        let size = data.count

        // VIC-20 PRG files are typically 3100-3200 bytes
        // Structure: load_addr(2) + basic_stub + viewer + screen(506) + color(506) + charset(2048)
        // Minimum: 2 + 506 + 506 + 2048 = 3062 bytes (without viewer)
        // Typical: ~3110-3150 bytes

        if size >= 3062 && size <= 3500 {
            // Try to decode as VIC-20 PRG
            if let result = decodePRG(data: data) {
                return result
            }
        }

        // Try raw format (no load address or viewer)
        // screen(506) + color(506) + charset(2048) = 3060 bytes
        if size == 3060 {
            return decodeRaw(data: data, offset: 0)
        }

        return (nil, .Unknown)
    }

    // MARK: - PRG Format Decoder

    private static func decodePRG(data: Data) -> (image: CGImage?, type: AppleIIImageType)? {
        // PRG has 2-byte load address
        guard data.count >= 3062 else { return nil }

        // Check load address (typically $1201 for unexpanded VIC-20)
        let loadAddrLo = data[0]
        let loadAddrHi = data[1]

        // Valid VIC-20 load addresses: $1001 (3K expanded), $1201 (unexpanded), $0401 (8K+ expanded)
        let validLoadAddrs: [(UInt8, UInt8)] = [
            (0x01, 0x12),  // $1201 - unexpanded
            (0x01, 0x10),  // $1001 - 3K expanded
            (0x01, 0x04),  // $0401 - 8K+ expanded
            (0x01, 0x00)   // $0001 - possible
        ]

        let isValidLoadAddr = validLoadAddrs.contains { $0.0 == loadAddrLo && $0.1 == loadAddrHi }

        // VIC-20 PRG file structure (BitPast format):
        // - 2 bytes: Load address ($1201)
        // - 12 bytes: BASIC stub
        // - ~47 bytes: Viewer code
        // - Data: screen(506) + color(506) + charset(2048) = 3060 bytes
        // Total header: ~61 bytes, data starts at offset 61

        let dataSize = 506 + 506 + 2048  // 3060 bytes

        // Try to find data start by looking for sequential screen data pattern (00 01 02 03...)
        // This is how BitPast generates screen data
        func findScreenDataStart() -> Int? {
            // Look for pattern 00 01 02 03 04 05 (first 6 screen bytes)
            // Search up to 150 bytes into the file to handle various header sizes
            // BitPast uses ~61 byte headers, other formats may vary
            // Add 1 to include the boundary case where header = filesize - dataSize
            let searchEnd = min(150, data.count - dataSize + 1)
            guard searchEnd > 14 else { return nil }

            for offset in 14..<searchEnd {
                if data[offset] == 0x00 && data[offset + 1] == 0x01 &&
                   data[offset + 2] == 0x02 && data[offset + 3] == 0x03 &&
                   data[offset + 4] == 0x04 && data[offset + 5] == 0x05 {
                    return offset
                }
            }
            return nil
        }

        // Helper to check if color data at offset looks valid
        func colorDataValid(at offset: Int) -> Int {
            guard offset >= 0 && offset + dataSize <= data.count else { return 0 }
            let colorStart = offset + 506
            var validCount = 0
            for i in 0..<506 {
                let colorByte = data[colorStart + i]
                if colorByte <= 15 {  // Valid color values 0-15
                    validCount += 1
                }
            }
            return validCount
        }

        var dataOffset: Int

        // Primary method: calculate offset from end of file (data is always at the end)
        // This works for all BitPast files regardless of header size or charset deduplication
        let endOffset = data.count - dataSize

        // Also try pattern matching for legacy files with sequential screen data
        let patternOffset = findScreenDataStart()

        // Validate both offsets
        let endValid = colorDataValid(at: endOffset)
        let patternValid = patternOffset != nil ? colorDataValid(at: patternOffset!) : 0

        // Prefer end offset (more reliable), but use pattern if it's significantly better
        if endOffset >= 2 && endValid > 400 {
            dataOffset = endOffset
        } else if let pOffset = patternOffset, patternValid > 400 {
            dataOffset = pOffset
        } else if endOffset >= 2 {
            dataOffset = endOffset
        } else {
            dataOffset = 61  // Last resort fallback
        }

        // Verify offset is reasonable
        if dataOffset < 2 || dataOffset + dataSize > data.count {
            return nil
        }

        // Verify this looks like VIC-20 data
        // Screen data should contain character codes 0-255
        // Color data should contain values 0-15 (or with multicolor bit set, 8-15)

        let screenStart = dataOffset
        let colorStart = dataOffset + 506

        // Check if color data looks valid (values 0-15 or 8-23 for multicolor)
        var validColorCount = 0
        for i in 0..<506 {
            let colorByte = data[colorStart + i]
            if colorByte <= 23 {  // 0-7 normal, 8-15 multicolor (8-23 with aux bit)
                validColorCount += 1
            }
        }

        // If most color bytes are valid, proceed with decode
        if validColorCount < 400 {
            return nil
        }

        // Determine if HiRes or Multicolor based on color data
        var multicolorCount = 0
        for i in 0..<506 {
            let colorByte = data[colorStart + i]
            if colorByte >= 8 {  // Multicolor mode uses bit 3 set
                multicolorCount += 1
            }
        }

        let isMulticolor = multicolorCount > 250  // Most cells are multicolor

        if isMulticolor {
            return decodeMulticolor(data: data, offset: dataOffset)
        } else {
            return decodeHiRes(data: data, offset: dataOffset)
        }
    }

    // MARK: - Raw Format Decoder

    private static func decodeRaw(data: Data, offset: Int) -> (image: CGImage?, type: AppleIIImageType) {
        // Determine mode from color data
        let colorStart = offset + 506
        var multicolorCount = 0

        for i in 0..<506 {
            let colorByte = data[colorStart + i]
            if colorByte >= 8 {
                multicolorCount += 1
            }
        }

        if multicolorCount > 250 {
            return decodeMulticolor(data: data, offset: offset)
        } else {
            return decodeHiRes(data: data, offset: offset)
        }
    }

    // MARK: - HiRes Mode Decoder (176×184, 2 colors per cell)

    private static func decodeHiRes(data: Data, offset: Int) -> (image: CGImage?, type: AppleIIImageType) {
        let screenOffset = offset
        let colorOffset = offset + 506
        let charsetOffset = offset + 506 + 506

        guard charsetOffset + 2048 <= data.count else {
            return (nil, .Unknown)
        }

        // Create pixel buffer
        var pixels = [UInt8](repeating: 0, count: screenWidth * screenHeight * 4)

        // Extract background color from viewer code in PRG header
        // Look for STA $900F pattern (0x8D 0x0F 0x90)
        var backgroundColor = 0  // Default to black
        if offset >= 20 {
            for i in 14..<min(offset - 3, 70) {
                if data[i] == 0x8D && data[i + 1] == 0x0F && data[i + 2] == 0x90 {
                    if i >= 2 && data[i - 2] == 0xA9 {
                        let regValue = Int(data[i - 1])
                        backgroundColor = (regValue >> 4) & 0x0F  // Background from upper nibble
                    }
                    break
                }
            }
        }

        // Process each character cell (row-major order: left-to-right, top-to-bottom)
        for cellY in 0..<charsY {
            for cellX in 0..<charsX {
                let cellIdx = cellY * charsX + cellX

                // Get character code and foreground color
                let charCode = Int(data[screenOffset + cellIdx])
                let fgColor = Int(data[colorOffset + cellIdx] & 0x07)  // Lower 3 bits

                // Get character bitmap (8 bytes)
                let charBitmapOffset = charsetOffset + (charCode * 8)

                // Render 8×8 cell
                for py in 0..<8 {
                    guard charBitmapOffset + py < data.count else { continue }
                    let rowByte = data[charBitmapOffset + py]

                    for px in 0..<8 {
                        let bit = (rowByte >> (7 - px)) & 1
                        let colorIdx = bit == 1 ? fgColor : backgroundColor

                        let screenX = cellX * 8 + px
                        let screenY = cellY * 8 + py

                        if screenX < screenWidth && screenY < screenHeight {
                            let pixelOffset = (screenY * screenWidth + screenX) * 4
                            let color = vic20Palette[colorIdx]
                            pixels[pixelOffset] = color.r
                            pixels[pixelOffset + 1] = color.g
                            pixels[pixelOffset + 2] = color.b
                            pixels[pixelOffset + 3] = 255
                        }
                    }
                }
            }
        }

        // Create CGImage
        guard let image = createImage(from: pixels, width: screenWidth, height: screenHeight) else {
            return (nil, .Unknown)
        }

        return (image, .VIC20(mode: "HiRes", colors: 16))
    }

    // MARK: - Multicolor Mode Decoder (88×184 double-wide, 4 colors per cell)

    private static func decodeMulticolor(data: Data, offset: Int) -> (image: CGImage?, type: AppleIIImageType) {
        let screenOffset = offset
        let colorOffset = offset + 506
        let charsetOffset = offset + 506 + 506

        guard charsetOffset + 2048 <= data.count else {
            return (nil, .Unknown)
        }

        // Create pixel buffer (still 176×184, but pixels are double-wide)
        var pixels = [UInt8](repeating: 0, count: screenWidth * screenHeight * 4)

        // In multicolor mode, we need 4 colors:
        // 00 = background (from $900F upper nibble)
        // 01 = border (from $900F lower nibble)
        // 10 = auxiliary color (from color RAM)
        // 11 = auxiliary color 2 (from $900E)

        // Try to extract colors from viewer code in PRG header
        // BitPast viewer code pattern at offset 14:
        // 0xA9, value,       // LDA #(bg << 4 | border)
        // 0x8D, 0x0F, 0x90,  // STA $900F
        // 0xA9, value2,      // LDA #(aux2 << 4)
        // 0x8D, 0x0E, 0x90,  // STA $900E
        var color0 = 0   // Background - black (default)
        var color1 = 1   // Border - white (default)
        var color3 = 7   // Aux2 - yellow (default)

        // Look for the viewer code pattern in the header
        // BitPast Multicolor format: LDA #value, STA $900F, LDA #value2, STA $900E at offset 14
        if offset >= 20 && data.count >= 24 {
            // Direct extraction for BitPast format (most reliable)
            // Offset 14: LDA #(color0 << 4 | color1)
            // Offset 16: STA $900F
            // Offset 19: LDA #(color3 << 4)
            // Offset 21: STA $900E
            if data[14] == 0xA9 && data[16] == 0x8D && data[17] == 0x0F && data[18] == 0x90 {
                let regValue = Int(data[15])
                color0 = (regValue >> 4) & 0x0F
                color1 = regValue & 0x0F
            }
            if data[19] == 0xA9 && data[21] == 0x8D && data[22] == 0x0E && data[23] == 0x90 {
                let regValue = Int(data[20])
                color3 = (regValue >> 4) & 0x0F
            }

            // Fallback: search for patterns if direct extraction failed
            if color0 == 0 && color1 == 1 && color3 == 7 {
                for i in 14..<min(offset - 3, 70) {
                    if data[i] == 0x8D && data[i + 1] == 0x0F && data[i + 2] == 0x90 {
                        if i >= 2 && data[i - 2] == 0xA9 {
                            let regValue = Int(data[i - 1])
                            color0 = (regValue >> 4) & 0x0F
                            color1 = regValue & 0x0F
                        }
                    }
                    if data[i] == 0x8D && data[i + 1] == 0x0E && data[i + 2] == 0x90 {
                        if i >= 2 && data[i - 2] == 0xA9 {
                            let regValue = Int(data[i - 1])
                            color3 = (regValue >> 4) & 0x0F
                        }
                    }
                }
            }
        }

        // Process each character cell (row-major order: left-to-right, top-to-bottom)
        for cellY in 0..<charsY {
            for cellX in 0..<charsX {
                let cellIdx = cellY * charsX + cellX

                let charCode = Int(data[screenOffset + cellIdx])
                let colorByte = data[colorOffset + cellIdx]
                let color2 = Int(colorByte & 0x07)  // Auxiliary color from color RAM

                let charBitmapOffset = charsetOffset + (charCode * 8)

                // Render 4×8 cell (but output as 8×8 with double-wide pixels)
                for py in 0..<8 {
                    guard charBitmapOffset + py < data.count else { continue }
                    let rowByte = data[charBitmapOffset + py]

                    for px in 0..<4 {
                        // Get 2-bit color value
                        let shift = (3 - px) * 2
                        let colorValue = Int((rowByte >> shift) & 0x03)

                        let colorIdx: Int
                        switch colorValue {
                        case 0: colorIdx = color0
                        case 1: colorIdx = color1
                        case 2: colorIdx = color2
                        default: colorIdx = color3
                        }

                        // Double-wide pixel
                        let screenX1 = cellX * 8 + px * 2
                        let screenX2 = screenX1 + 1
                        let screenY = cellY * 8 + py

                        if screenY < screenHeight {
                            let color = vic20Palette[colorIdx]

                            if screenX1 < screenWidth {
                                let pixelOffset1 = (screenY * screenWidth + screenX1) * 4
                                pixels[pixelOffset1] = color.r
                                pixels[pixelOffset1 + 1] = color.g
                                pixels[pixelOffset1 + 2] = color.b
                                pixels[pixelOffset1 + 3] = 255
                            }
                            if screenX2 < screenWidth {
                                let pixelOffset2 = (screenY * screenWidth + screenX2) * 4
                                pixels[pixelOffset2] = color.r
                                pixels[pixelOffset2 + 1] = color.g
                                pixels[pixelOffset2 + 2] = color.b
                                pixels[pixelOffset2 + 3] = 255
                            }
                        }
                    }
                }
            }
        }

        // Create CGImage
        guard let image = createImage(from: pixels, width: screenWidth, height: screenHeight) else {
            return (nil, .Unknown)
        }

        return (image, .VIC20(mode: "Multicolor", colors: 16))
    }

    // MARK: - Image Creation Helper

    private static func createImage(from pixels: [UInt8], width: Int, height: Int) -> CGImage? {
        var mutablePixels = pixels

        guard let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) else {
            return nil
        }

        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue

        guard let context = CGContext(
            data: &mutablePixels,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return nil
        }

        return context.makeImage()
    }
}
