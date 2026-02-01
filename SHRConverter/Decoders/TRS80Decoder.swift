import Foundation
import CoreGraphics

// MARK: - TRS-80 Graphics Decoder

class TRS80Decoder {

    // MARK: - TRS-80 Model I/III Block Graphics
    // The original TRS-80 used "semigraphics" - each character cell could display
    // a 2x3 grid of blocks, giving effective resolution of 128x48

    static func decodeBlockGraphics(data: Data) -> (image: CGImage?, type: AppleIIImageType) {
        // Screen memory: 1024 bytes (64 columns x 16 rows)
        // Each byte with high bit set is a graphics character
        // Bits 0-5 represent the 2x3 block pattern

        let charWidth = 64
        let charHeight = 16
        let blockWidth = 2
        let blockHeight = 3
        let width = charWidth * blockWidth   // 128
        let height = charHeight * blockHeight // 48

        guard data.count >= 1024 else {
            return (nil, .Unknown)
        }

        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)

        // TRS-80 phosphor green color
        let greenOn: (r: UInt8, g: UInt8, b: UInt8) = (0x33, 0xFF, 0x33)
        let greenOff: (r: UInt8, g: UInt8, b: UInt8) = (0x00, 0x20, 0x00)

        for charRow in 0..<charHeight {
            for charCol in 0..<charWidth {
                let offset = charRow * charWidth + charCol
                let byte = data[offset]

                // Check if this is a graphics character (bit 7 set, bits 6 = 1 for graphics)
                // Graphics characters are 0x80-0xBF (128-191)
                let isGraphics = (byte & 0x80) != 0

                if isGraphics {
                    // Extract the 6 block bits (arranged as 2 columns x 3 rows)
                    // Bit 0: top-left, Bit 1: top-right
                    // Bit 2: mid-left, Bit 3: mid-right
                    // Bit 4: bot-left, Bit 5: bot-right
                    let blocks = byte & 0x3F

                    for blockRow in 0..<3 {
                        for blockCol in 0..<2 {
                            let bitIndex = blockRow * 2 + blockCol
                            let isOn = (blocks >> bitIndex) & 1 == 1

                            let x = charCol * blockWidth + blockCol
                            let y = charRow * blockHeight + blockRow
                            let bufferIdx = (y * width + x) * 4

                            let rgb = isOn ? greenOn : greenOff
                            rgbaBuffer[bufferIdx] = rgb.r
                            rgbaBuffer[bufferIdx + 1] = rgb.g
                            rgbaBuffer[bufferIdx + 2] = rgb.b
                            rgbaBuffer[bufferIdx + 3] = 255
                        }
                    }
                } else {
                    // Non-graphics character - render as off
                    for blockRow in 0..<3 {
                        for blockCol in 0..<2 {
                            let x = charCol * blockWidth + blockCol
                            let y = charRow * blockHeight + blockRow
                            let bufferIdx = (y * width + x) * 4

                            rgbaBuffer[bufferIdx] = greenOff.r
                            rgbaBuffer[bufferIdx + 1] = greenOff.g
                            rgbaBuffer[bufferIdx + 2] = greenOff.b
                            rgbaBuffer[bufferIdx + 3] = 255
                        }
                    }
                }
            }
        }

        guard let cgImage = ImageHelpers.createCGImage(from: rgbaBuffer, width: width, height: height) else {
            return (nil, .Unknown)
        }

        return (cgImage, .TRS80(model: "Model I/III", resolution: "128x48"))
    }

    // MARK: - CoCo 1/2 Color Palette (MC6847 VDG)
    // Color Set 0 for PMODE 3 - matches BitPast output format
    // Index 0 = background (black), indices 1-3 = foreground colors

    static let cocoPalette: [(r: UInt8, g: UInt8, b: UInt8)] = [
        (0x00, 0x00, 0x00),  // 0: Black (background)
        (0x00, 0xFF, 0x00),  // 1: Green
        (0xFF, 0xFF, 0x00),  // 2: Yellow
        (0x00, 0x00, 0xFF),  // 3: Blue
        (0xFF, 0x00, 0x00),  // 4: Red
        (0xFF, 0xFF, 0xFF),  // 5: Buff (White)
        (0x00, 0xFF, 0xFF),  // 6: Cyan
        (0xFF, 0x00, 0xFF),  // 7: Magenta
        (0xFF, 0x80, 0x00),  // 8: Orange
        (0x00, 0x80, 0x00),  // 9: Dark Green
        (0x00, 0x00, 0x80),  // 10: Dark Blue
        (0x80, 0x00, 0x00),  // 11: Dark Red
        (0x80, 0x80, 0x80),  // 12: Gray
        (0x00, 0x80, 0x80),  // 13: Dark Cyan
        (0x80, 0x00, 0x80),  // 14: Dark Magenta
        (0x80, 0x40, 0x00)   // 15: Brown
    ]

    // MARK: - CoCo 3 Color Palette (GIME RGB222)
    // GIME uses 6-bit RGB (2 bits per channel): values 0, 85, 170, 255
    // Full 64-color GIME palette for direct index mapping

    static let gime64Palette: [(r: UInt8, g: UInt8, b: UInt8)] = {
        var palette: [(r: UInt8, g: UInt8, b: UInt8)] = []
        for i in 0..<64 {
            // RGB222 format: RRGGBB (2 bits each)
            let r = UInt8(((i >> 4) & 0x03) * 85)  // 0, 85, 170, 255
            let g = UInt8(((i >> 2) & 0x03) * 85)
            let b = UInt8((i & 0x03) * 85)
            palette.append((r, g, b))
        }
        return palette
    }()

    // CoCo 3 fixed 16-color palette - compatible with BitPast and emulators
    // Uses specific GIME indices for standard color mapping
    // GIME RGB222: index = R*16 + G*4 + B where R,G,B are 0-3
    static let coco3Palette: [(r: UInt8, g: UInt8, b: UInt8)] = [
        gime64Palette[0],   // 0: Black (R0G0B0)
        gime64Palette[63],  // 1: White (R3G3B3)
        gime64Palette[48],  // 2: Red (R3G0B0)
        gime64Palette[12],  // 3: Green (R0G3B0)
        gime64Palette[3],   // 4: Blue (R0G0B3)
        gime64Palette[15],  // 5: Cyan (R0G3B3)
        gime64Palette[51],  // 6: Magenta (R3G0B3)
        gime64Palette[60],  // 7: Yellow (R3G3B0)
        gime64Palette[21],  // 8: Dark Gray (R1G1B1)
        gime64Palette[42],  // 9: Light Gray (R2G2B2)
        gime64Palette[32],  // 10: Dark Red (R2G0B0)
        gime64Palette[8],   // 11: Dark Green (R0G2B0)
        gime64Palette[2],   // 12: Dark Blue (R0G0B2)
        gime64Palette[52],  // 13: Orange (R3G1B0)
        gime64Palette[44],  // 14: Brown (R2G2B0)
        gime64Palette[7]    // 15: Sky Blue (R0G1B3)
    ]

    // CoCo artifact colors (for PMODE 4)
    static let cocoArtifactColors: [(r: UInt8, g: UInt8, b: UInt8)] = [
        (0x00, 0x00, 0x00),  // Black
        (0x00, 0x80, 0xFF),  // Blue artifact
        (0xFF, 0x80, 0x00),  // Orange artifact
        (0xFF, 0xFF, 0xFF)   // White
    ]

    // MARK: - CoCo PMODE 3 Decoder (128x192, 4 colors)
    // Common format: 6144 bytes
    // Output: 256x192 to correct aspect ratio (CoCo pixels were ~2:1 wide)

    static func decodePMode3(data: Data) -> (image: CGImage?, type: AppleIIImageType) {
        let sourceWidth = 128
        let outputWidth = 256  // Double horizontal for correct aspect ratio
        let height = 192
        let bytesPerLine = 32  // 128 pixels * 2 bits / 8 = 32 bytes
        let expectedSize = bytesPerLine * height  // 6144 bytes

        guard data.count >= expectedSize else {
            return (nil, .Unknown)
        }

        var rgbaBuffer = [UInt8](repeating: 0, count: outputWidth * height * 4)

        // Color set 0: Black, Green, Yellow, Blue (matches BitPast)
        let colorSet = [0, 1, 2, 3]

        for y in 0..<height {
            for byteX in 0..<bytesPerLine {
                let offset = y * bytesPerLine + byteX
                guard offset < data.count else { continue }

                let byte = data[offset]

                // 4 pixels per byte, 2 bits each
                for pixel in 0..<4 {
                    let shift = (3 - pixel) * 2
                    let colorIndex = Int((byte >> shift) & 0x03)
                    let color = colorSet[colorIndex]

                    let sourceX = byteX * 4 + pixel
                    let outputX = sourceX * 2  // Double each pixel horizontally

                    let rgb = cocoPalette[color]

                    // Write doubled pixel (2 pixels wide)
                    for dx in 0..<2 {
                        let bufferIdx = (y * outputWidth + outputX + dx) * 4
                        rgbaBuffer[bufferIdx] = rgb.r
                        rgbaBuffer[bufferIdx + 1] = rgb.g
                        rgbaBuffer[bufferIdx + 2] = rgb.b
                        rgbaBuffer[bufferIdx + 3] = 255
                    }
                }
            }
        }

        guard let cgImage = ImageHelpers.createCGImage(from: rgbaBuffer, width: outputWidth, height: height) else {
            return (nil, .Unknown)
        }

        return (cgImage, .TRS80(model: "CoCo", resolution: "128x192, 4 colors"))
    }

    // MARK: - CoCo PMODE 4 Decoder (256x192, 2 colors with artifacts)
    // Common format: 6144 bytes

    static func decodePMode4(data: Data) -> (image: CGImage?, type: AppleIIImageType) {
        let width = 256
        let height = 192
        let bytesPerLine = 32  // 256 pixels / 8 = 32 bytes
        let expectedSize = bytesPerLine * height  // 6144 bytes

        guard data.count >= expectedSize else {
            return (nil, .Unknown)
        }

        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)

        // Simple 2-color mode (green on black or white on black)
        let colorOn: (r: UInt8, g: UInt8, b: UInt8) = (0x00, 0xFF, 0x00)
        let colorOff: (r: UInt8, g: UInt8, b: UInt8) = (0x00, 0x00, 0x00)

        for y in 0..<height {
            for byteX in 0..<bytesPerLine {
                let offset = y * bytesPerLine + byteX
                guard offset < data.count else { continue }

                let byte = data[offset]

                // 8 pixels per byte
                for bit in 0..<8 {
                    let pixel = (byte >> (7 - bit)) & 1
                    let x = byteX * 8 + bit
                    let bufferIdx = (y * width + x) * 4

                    let rgb = pixel == 1 ? colorOn : colorOff
                    rgbaBuffer[bufferIdx] = rgb.r
                    rgbaBuffer[bufferIdx + 1] = rgb.g
                    rgbaBuffer[bufferIdx + 2] = rgb.b
                    rgbaBuffer[bufferIdx + 3] = 255
                }
            }
        }

        guard let cgImage = ImageHelpers.createCGImage(from: rgbaBuffer, width: width, height: height) else {
            return (nil, .Unknown)
        }

        return (cgImage, .TRS80(model: "CoCo", resolution: "256x192, 2 colors"))
    }

    // MARK: - CoCo PMODE 4 with Artifact Colors
    // Simulates the NTSC artifact coloring

    static func decodePMode4Artifact(data: Data) -> (image: CGImage?, type: AppleIIImageType) {
        let width = 256
        let height = 192
        let bytesPerLine = 32
        let expectedSize = bytesPerLine * height

        guard data.count >= expectedSize else {
            return (nil, .Unknown)
        }

        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)

        for y in 0..<height {
            for byteX in 0..<bytesPerLine {
                let offset = y * bytesPerLine + byteX
                guard offset < data.count else { continue }

                let byte = data[offset]

                // Process pairs of bits for artifact colors
                for bitPair in 0..<4 {
                    let shift = (3 - bitPair) * 2
                    let bits = (byte >> shift) & 0x03

                    let x = byteX * 8 + bitPair * 2

                    // Artifact color mapping
                    let rgb = cocoArtifactColors[Int(bits)]

                    // Two pixels per artifact color
                    for px in 0..<2 {
                        let bufferIdx = (y * width + x + px) * 4
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

        return (cgImage, .TRS80(model: "CoCo", resolution: "256x192, Artifact"))
    }

    // MARK: - CoCo 3 320x200 16-color mode
    // Screen memory: 32000 bytes (4 bits per pixel)
    // Some formats include a 16-byte palette header with GIME register values

    static func decodeCoCo3_320(data: Data) -> (image: CGImage?, type: AppleIIImageType) {
        let width = 320
        let bytesPerLine = 160  // 320 pixels * 4 bits / 8 = 160 bytes
        let imageDataSize = 32000  // 320x200 @ 4bpp

        // Accept files >= 24000 bytes (some CoCo 3 images are 320x150 to 320x200)
        guard data.count >= 24000 else {
            return (nil, .Unknown)
        }

        // Determine if file has embedded palette header
        // Format with palette: 16 bytes palette + 32000 bytes pixel data = 32016 bytes
        // Format without palette: 32000 bytes pixel data
        var pixelDataOffset = 0
        var palette = coco3Palette  // Default palette matching BitPast's coco3Fixed16

        // Check for embedded palette at START of file (32016 bytes = 16 palette + 32000 pixels)
        if data.count == 32016 {
            var validPalette = true
            for i in 0..<16 {
                if data[i] > 63 {
                    validPalette = false
                    break
                }
            }
            if validPalette {
                var embeddedPalette: [(r: UInt8, g: UInt8, b: UInt8)] = []
                for i in 0..<16 {
                    let gimeIndex = Int(data[i])
                    embeddedPalette.append(gime64Palette[gimeIndex])
                }
                palette = embeddedPalette
                pixelDataOffset = 16
            }
        }

        // Check for embedded palette at END of file (32016 bytes = 32000 pixels + 16 palette)
        if pixelDataOffset == 0 && data.count == 32016 {
            let paletteOffset = 32000
            var validPalette = true
            for i in 0..<16 {
                if data[paletteOffset + i] > 63 {
                    validPalette = false
                    break
                }
            }
            if validPalette {
                var embeddedPalette: [(r: UInt8, g: UInt8, b: UInt8)] = []
                for i in 0..<16 {
                    let gimeIndex = Int(data[paletteOffset + i])
                    embeddedPalette.append(gime64Palette[gimeIndex])
                }
                palette = embeddedPalette
                // pixelDataOffset stays 0, but we limit height to 200 rows (32000 bytes)
            }
        }

        // Calculate height from available pixel data (max 200 rows)
        let availablePixelBytes = data.count - pixelDataOffset
        let height = min(200, availablePixelBytes / bytesPerLine)

        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)

        for y in 0..<height {
            for byteX in 0..<bytesPerLine {
                let offset = pixelDataOffset + y * bytesPerLine + byteX
                guard offset < data.count else { continue }

                let byte = data[offset]

                // 2 pixels per byte, 4 bits each (high nibble first)
                let pixel1 = Int((byte >> 4) & 0x0F)
                let pixel2 = Int(byte & 0x0F)

                let x = byteX * 2

                // First pixel
                let bufferIdx1 = (y * width + x) * 4
                let rgb1 = palette[pixel1]
                rgbaBuffer[bufferIdx1] = rgb1.r
                rgbaBuffer[bufferIdx1 + 1] = rgb1.g
                rgbaBuffer[bufferIdx1 + 2] = rgb1.b
                rgbaBuffer[bufferIdx1 + 3] = 255

                // Second pixel
                if x + 1 < width {
                    let bufferIdx2 = (y * width + x + 1) * 4
                    let rgb2 = palette[pixel2]
                    rgbaBuffer[bufferIdx2] = rgb2.r
                    rgbaBuffer[bufferIdx2 + 1] = rgb2.g
                    rgbaBuffer[bufferIdx2 + 2] = rgb2.b
                    rgbaBuffer[bufferIdx2 + 3] = 255
                }
            }
        }

        guard let cgImage = ImageHelpers.createCGImage(from: rgbaBuffer, width: width, height: height) else {
            return (nil, .Unknown)
        }

        return (cgImage, .TRS80(model: "CoCo 3", resolution: "320x\(height), 16 colors"))
    }

    // MARK: - CoCo 3 640x200 4-color mode
    // Screen memory: 32000 bytes (2 bits per pixel)

    static func decodeCoCo3_640(data: Data) -> (image: CGImage?, type: AppleIIImageType) {
        let width = 640
        let height = 200
        let bytesPerLine = 160  // 640 pixels * 2 bits / 8 = 160 bytes
        let expectedSize = bytesPerLine * height  // 32000 bytes

        guard data.count >= expectedSize else {
            return (nil, .Unknown)
        }

        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)

        // CoCo 3 640x200 uses first 4 colors from the 16-color palette
        // Must match BitPast: Black, White, Red, Green (indices 0, 1, 2, 3)
        let colorSet = [0, 1, 2, 3]

        for y in 0..<height {
            for byteX in 0..<bytesPerLine {
                let offset = y * bytesPerLine + byteX
                guard offset < data.count else { continue }

                let byte = data[offset]

                // 4 pixels per byte, 2 bits each
                for pixel in 0..<4 {
                    let shift = (3 - pixel) * 2
                    let colorIndex = Int((byte >> shift) & 0x03)
                    let color = colorSet[colorIndex]

                    let x = byteX * 4 + pixel
                    let bufferIdx = (y * width + x) * 4

                    let rgb = coco3Palette[color]
                    rgbaBuffer[bufferIdx] = rgb.r
                    rgbaBuffer[bufferIdx + 1] = rgb.g
                    rgbaBuffer[bufferIdx + 2] = rgb.b
                    rgbaBuffer[bufferIdx + 3] = 255
                }
            }
        }

        guard let cgImage = ImageHelpers.createCGImage(from: rgbaBuffer, width: width, height: height) else {
            return (nil, .Unknown)
        }

        return (cgImage, .TRS80(model: "CoCo 3", resolution: "640x200, 4 colors"))
    }

    // MARK: - Auto-detect PMODE 3 vs PMODE 4

    /// Analyzes 6144-byte data to determine if it's PMODE 3 (4-color) or PMODE 4 (2-color)
    /// PMODE 3: 128x192, 2 bits/pixel - uses color indices 0-3
    /// PMODE 4: 256x192, 1 bit/pixel - uses only 0 and 1
    private static func detectPMode(data: Data) -> Bool {
        // Returns true if likely PMODE 3 (4 colors), false if PMODE 4 (2 colors)
        //
        // PMODE 4: 256x192, 1bpp - each bit is a pixel (2 colors: black + green/white)
        // PMODE 3: 128x192, 2bpp - each 2-bit value is a pixel (4 colors)
        //
        // Key insight: In PMODE 4 dithered images, when read as 2-bit pairs:
        // - Alternating pixels (01, 10) are very common due to dithering
        // - This creates a characteristic "mixed pair" pattern
        // In PMODE 3 (true 4-color), colors are more deliberately placed

        let sampleSize = min(data.count, 6144)
        var pairCounts = [Int](repeating: 0, count: 4)
        var transitionCount = 0  // Count bit transitions within bytes

        for i in 0..<sampleSize {
            let byte = data[i]

            // Extract 4 2-bit pairs from each byte
            for shift in stride(from: 6, through: 0, by: -2) {
                let pair = Int((byte >> shift) & 0x03)
                pairCounts[pair] += 1
            }

            // Count bit transitions (characteristic of PMODE 4 dithering)
            var transitions = 0
            for bit in 0..<7 {
                let b1 = (byte >> bit) & 1
                let b2 = (byte >> (bit + 1)) & 1
                if b1 != b2 {
                    transitions += 1
                }
            }
            transitionCount += transitions
        }

        let totalPairs = pairCounts.reduce(0, +)
        let totalPossibleTransitions = sampleSize * 7
        let transitionRatio = Double(transitionCount) / Double(totalPossibleTransitions)

        // Count "mixed" pairs (01, 10) vs "solid" pairs (00, 11)
        let mixedPairs = pairCounts[1] + pairCounts[2]  // 01 and 10
        let solidPairs = pairCounts[0] + pairCounts[3]  // 00 and 11
        let mixedRatio = Double(mixedPairs) / Double(totalPairs)

        // Count how many of the 4 possible values are significantly used
        let threshold = totalPairs / 20  // 5% threshold
        var significantValues = 0
        for count in pairCounts {
            if count > threshold {
                significantValues += 1
            }
        }

        // PMODE 4 characteristics:
        // 1. High transition ratio (dithering creates alternating bits)
        // 2. High mixed pair ratio (01, 10 pairs from alternating pixels)
        // 3. Even distribution across all 4 pair values (dithering spreads evenly)

        // If transition ratio is high (>35%), likely PMODE 4 dithered image
        if transitionRatio > 0.35 {
            return false  // PMODE 4
        }

        // If mixed pairs dominate (>40% of all pairs), likely PMODE 4
        if mixedRatio > 0.40 {
            return false  // PMODE 4
        }

        // Check for solid byte patterns (undithered PMODE 4)
        var solidByteCount = 0
        for i in 0..<sampleSize {
            let byte = data[i]
            if byte == 0x00 || byte == 0xFF || byte == 0xAA || byte == 0x55 {
                solidByteCount += 1
            }
        }
        let solidRatio = Double(solidByteCount) / Double(sampleSize)

        // High solid byte ratio with few significant pair values = PMODE 4
        if solidRatio > 0.3 && significantValues <= 2 {
            return false  // PMODE 4
        }

        // If only 2 significant pair values and they're opposites (00,11 or 01,10), PMODE 4
        if significantValues == 2 {
            let has00 = pairCounts[0] > threshold
            let has11 = pairCounts[3] > threshold
            let has01 = pairCounts[1] > threshold
            let has10 = pairCounts[2] > threshold
            if (has00 && has11) || (has01 && has10) {
                return false  // PMODE 4
            }
        }

        // PMODE 3 characteristics (true 4-color images):
        // 1. Uses 3-4 distinct colors deliberately placed
        // 2. Colors are in blocks/regions, not random dithering
        // 3. Lower transition ratio than dithered 2-color images

        // If 3+ significant color values are used, likely PMODE 3 (true 4-color)
        // unless we have very high transitions indicating dithering
        if significantValues >= 3 && transitionRatio < 0.35 {
            return true  // PMODE 3 - uses multiple colors
        }

        // If transition ratio is low, likely PMODE 3 with solid color regions
        if transitionRatio < 0.30 {
            return true  // PMODE 3
        }

        // If pair distribution is uneven (one or two colors dominate), PMODE 3
        let maxPairCount = pairCounts.max() ?? 0
        let minPairCount = pairCounts.min() ?? 0
        let dominanceRatio = Double(maxPairCount) / Double(max(minPairCount, 1))
        if dominanceRatio > 3.0 {
            return true  // PMODE 3 - deliberate color placement creates uneven distribution
        }

        // If mixed pairs are relatively low, PMODE 3
        if mixedRatio < 0.35 {
            return true  // PMODE 3
        }

        // High transitions (>40%) with balanced distribution = PMODE 4 dithered
        if transitionRatio > 0.40 && significantValues == 4 {
            let balanceRatio = Double(minPairCount) / Double(max(maxPairCount, 1))
            if balanceRatio > 0.4 {
                return false  // PMODE 4 dithered - very even distribution
            }
        }

        // Default to PMODE 3 (4-color) - PMODE 4 has distinctive dithering patterns
        // that should be caught by earlier checks
        return true
    }

    // MARK: - Auto-detect CoCo 3 mode (320x200 16-color vs 640x200 4-color)

    /// Analyzes 32000-byte data to determine if it's 320x200 16-color or 640x200 4-color
    /// Both modes have the same file size, so we use content heuristics
    private static func detectCoCo3Mode(data: Data) -> Bool {
        // Returns true if likely 640x200 4-color, false if 320x200 16-color
        //
        // In 640x200 4-color mode (2bpp), each byte contains 4 pixels with values 0-3
        // When read as 4bpp (nibbles), the values are:
        //   high nibble = pixel0 * 4 + pixel1
        //   low nibble = pixel2 * 4 + pixel3

        let sampleSize = min(data.count, 32000)
        var nibbleHistogram = [Int](repeating: 0, count: 16)

        for i in 0..<sampleSize {
            let byte = data[i]
            let highNibble = Int((byte >> 4) & 0x0F)
            let lowNibble = Int(byte & 0x0F)
            nibbleHistogram[highNibble] += 1
            nibbleHistogram[lowNibble] += 1
        }

        let totalNibbles = sampleSize * 2

        // Heuristic 1: Check uniformity of nibble distribution
        // In 640x200 with dithered 4 colors, each 2-bit value (0-3) is roughly equally distributed
        // When combined into nibbles, this creates a relatively uniform distribution
        // In 320x200 16-color, the distribution is typically very uneven (some colors dominate)
        let expectedPerNibble = Double(totalNibbles) / 16.0
        var chiSquared = 0.0
        for count in nibbleHistogram {
            let diff = Double(count) - expectedPerNibble
            chiSquared += (diff * diff) / expectedPerNibble
        }
        // Lower chi-squared means more uniform distribution (640x200 characteristic)
        // Threshold: chi-squared < 5000 suggests relatively uniform (640x200)
        let isUniform = chiSquared < 8000

        // Heuristic 2: Count how many nibble values are significantly used
        // In 320x200 16-color, typically only some colors are heavily used
        // In 640x200 dithered, most nibble combinations appear
        let threshold = totalNibbles / 100  // 1% threshold
        var significantNibbles = 0
        for count in nibbleHistogram {
            if count > threshold {
                significantNibbles += 1
            }
        }
        // If 12+ of 16 possible nibble values are significantly used, likely 640x200
        let hasWideDistribution = significantNibbles >= 12

        // Heuristic 3: Check for presence of "diagonal" nibbles (solid color pairs)
        // In 640x200, nibbles 0 (0,0), 5 (1,1), 10 (2,2), 15 (3,3) represent solid areas
        let diagonalNibbles = nibbleHistogram[0] + nibbleHistogram[5] + nibbleHistogram[10] + nibbleHistogram[15]
        let diagonalRatio = Double(diagonalNibbles) / Double(totalNibbles)
        // If diagonal nibbles are >15% of total, suggests 640x200 with some solid areas
        let hasDiagonalPresence = diagonalRatio > 0.15

        // Heuristic 4: Check 2-bit value distribution
        // In 640x200 4-color, at least 3 of 4 possible values should be used significantly
        // (some images may not use all 4 colors, e.g., black/white/red without green)
        var twoBitHistogram = [Int](repeating: 0, count: 4)
        for i in 0..<sampleSize {
            let byte = data[i]
            twoBitHistogram[Int((byte >> 6) & 0x03)] += 1
            twoBitHistogram[Int((byte >> 4) & 0x03)] += 1
            twoBitHistogram[Int((byte >> 2) & 0x03)] += 1
            twoBitHistogram[Int(byte & 0x03)] += 1
        }
        let totalTwoBit = sampleSize * 4
        let twoBitThreshold = totalTwoBit / 50  // 2% threshold (more lenient)
        var significantTwoBitValues = 0
        for count in twoBitHistogram {
            if count > twoBitThreshold {
                significantTwoBitValues += 1
            }
        }
        // At least 3 of 4 2-bit values should be used (allows for 3-color images)
        let hasReasonableTwoBit = significantTwoBitValues >= 3

        // Heuristic 5: In 640x200, row-to-row correlation should exist
        // Adjacent rows in real images are similar; when misread as 320x200, this breaks
        var rowCorrelation = 0
        let bytesPerRow = 160
        let rowsToCheck = min(100, sampleSize / bytesPerRow - 1)
        for row in 0..<rowsToCheck {
            for col in 0..<bytesPerRow {
                let offset1 = row * bytesPerRow + col
                let offset2 = (row + 1) * bytesPerRow + col
                if offset2 < data.count {
                    // Check if bytes in adjacent rows are similar
                    let diff = abs(Int(data[offset1]) - Int(data[offset2]))
                    if diff < 64 {  // Allow some variation
                        rowCorrelation += 1
                    }
                }
            }
        }
        let totalRowChecks = rowsToCheck * bytesPerRow
        let rowCorrelationRatio = totalRowChecks > 0 ? Double(rowCorrelation) / Double(totalRowChecks) : 0
        let hasRowCorrelation = rowCorrelationRatio > 0.30

        // Decision: Use multiple signals with lower threshold
        var score = 0
        if isUniform { score += 2 }
        if hasWideDistribution { score += 2 }
        if hasDiagonalPresence { score += 1 }
        if hasReasonableTwoBit { score += 2 }
        if hasRowCorrelation { score += 1 }

        // If score >= 3, likely 640x200 (lowered from 4)
        return score >= 3
    }

    // MARK: - Auto-detect TRS-80 format

    static func decode(data: Data, filename: String? = nil) -> (image: CGImage?, type: AppleIIImageType) {
        let dataSize = data.count

        // Try to determine format by file extension
        let ext = filename?.split(separator: ".").last?.lowercased() ?? ""

        if (ext == "bin" || ext == "cas") && dataSize == 1024 {
            return decodeBlockGraphics(data: data)
        } else if (ext == "max" || ext == "pic" || ext == "pix") && dataSize == 6144 {
            // CoCo PMODE graphics - auto-detect mode
            if detectPMode(data: data) {
                return decodePMode3(data: data)
            } else {
                return decodePMode4(data: data)
            }
        } else if (ext == "cm3" || ext == "pi3" || ext == "mg3") && dataSize >= 24000 {
            // CoCo 3 graphics - check for 640x200 vs 320x200
            if dataSize == 32000 && detectCoCo3Mode(data: data) {
                return decodeCoCo3_640(data: data)
            }
            return decodeCoCo3_320(data: data)
        }

        // Auto-detect by size
        if dataSize == 1024 {
            // TRS-80 Model I/III block graphics
            return decodeBlockGraphics(data: data)
        } else if dataSize == 6144 {
            // CoCo PMODE 3 or PMODE 4 - both are 6144 bytes
            // Auto-detect based on content analysis
            if detectPMode(data: data) {
                return decodePMode3(data: data)
            } else {
                return decodePMode4(data: data)
            }
        } else if dataSize == 3072 {
            // CoCo PMODE 0/1/2 (128x96 or 128x192, less memory)
            return decodePMode3(data: data)
        } else if dataSize >= 24000 && dataSize <= 33000 {
            // CoCo 3 modes - check for 640x200 vs 320x200
            if dataSize == 32000 && detectCoCo3Mode(data: data) {
                return decodeCoCo3_640(data: data)
            }
            return decodeCoCo3_320(data: data)
        }

        return (nil, .Unknown)
    }
}
