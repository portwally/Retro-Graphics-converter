import Foundation
import AppKit

// MARK: - Palette Extractor

/// Extracts palette information from raw image data for display in the UI
struct PaletteExtractor {

    // MARK: - Main Extraction Function

    static func extractPalette(from data: Data, type: AppleIIImageType, filename: String = "") -> PaletteInfo? {
        switch type {
        case .SHR(let mode, _, _):
            if mode.contains("3200") {
                // Check for 3201 compressed format first
                if let palette = extract3201Palette(from: data) {
                    return palette
                }
                // Try standard 3200-color extraction
                if let palette = extract3200ColorPalette(from: data) {
                    return palette
                }
                // Fall back to APF 3200 extraction
                if let palette = extractAPFPalette(from: data, is3200: true) {
                    return palette
                }
                // Try DreamGrafix extraction
                if let palette = extractDreamGrafixPalette(from: data, mode: mode) {
                    return palette
                }
                return nil
            } else if mode.contains("DreamGrafix") {
                return extractDreamGrafixPalette(from: data, mode: mode)
            } else if mode.contains("APF") || mode.contains("816") {
                // Apple Preferred Format - palette embedded in MAIN block
                return extractAPFPalette(from: data, is3200: false)
            } else if mode.contains("Paintworks") {
                // Paintworks format - palette at offset 0x00-0x1F
                return extractPaintworksPalette(from: data)
            } else if mode.contains("Packed") {
                // Packed SHR - decompress first, then extract palette
                return extractPackedSHRPalette(from: data)
            } else {
                // Standard SHR - try standard extraction first
                if let palette = extractStandardSHRPalette(from: data) {
                    return palette
                }
                // Fall back to APF extraction for packed formats
                return extractAPFPalette(from: data, is3200: false)
            }

        case .HGR:
            return createHGRPalette()

        case .DHGR:
            return createDHGRPalette()

        case .C64:
            return createC64Palette()

        case .IFF(_, _, _):
            return extractIFFPalette(from: data)

        case .DEGAS(let resolution, _):
            return extractDegasPalette(from: data, resolution: resolution)

        case .ZXSpectrum:
            return createZXSpectrumPalette()

        case .AmstradCPC(let mode, _):
            return createAmstradCPCPalette(mode: mode)

        case .PCX(_, _, let bpp):
            return extractPCXPalette(from: data, bitsPerPixel: bpp)

        case .BMP(_, _, let bpp):
            return extractBMPPalette(from: data, bitsPerPixel: bpp)

        case .MacPaint:
            return createMacPaintPalette()

        case .MSX(let mode, _):
            return createMSXPalette(mode: mode)

        case .BBCMicro(let mode, _):
            return createBBCMicroPalette(mode: mode)

        case .TRS80(let model, _):
            return createTRS80Palette(model: model)

        case .ModernImage:
            return nil  // Modern images don't have indexed palettes

        case .Unknown:
            return nil
        }
    }

    // MARK: - Apple IIgs SHR Palettes

    /// Extract standard SHR palette (16 palettes, each with 16 colors)
    private static func extractStandardSHRPalette(from data: Data) -> PaletteInfo? {
        let paletteOffset = 32256
        let scbOffset = 32000

        guard data.count >= paletteOffset + 512 else { return nil }

        var palettes: [[PaletteColor]] = []

        // Read 16 palettes
        for i in 0..<16 {
            let pOffset = paletteOffset + (i * 32)
            if pOffset + 32 <= data.count {
                let palette = readAppleIIgsPalette(from: data, offset: pOffset, reverseOrder: false)
                palettes.append(palette)
            }
        }

        // Read SCB mapping (which palette each scanline uses)
        var scbMapping: [Int] = []
        for y in 0..<200 {
            if scbOffset + y < data.count {
                let scb = data[scbOffset + y]
                scbMapping.append(Int(scb & 0x0F))
            } else {
                scbMapping.append(0)
            }
        }

        return PaletteInfo(
            type: .multiPalette,
            palettes: palettes,
            colorsPerPalette: 16,
            platformName: "Apple IIgs",
            scbMapping: scbMapping
        )
    }

    /// Extract palette from packed SHR format (PNT $0001)
    /// Decompresses the data first, then extracts palette from decompressed data
    private static func extractPackedSHRPalette(from data: Data) -> PaletteInfo? {
        // Decompress the packed data
        let decompressedData = PackedSHRDecoder.unpackBytes(data: data, maxOutputSize: 65536)

        // Need at least standard SHR size with palette
        guard decompressedData.count >= 32768 else {
            // Try with less data - some packed files may have partial palette
            if decompressedData.count >= 32512 {
                // Has at least some palette data
                return extractStandardSHRPalette(from: decompressedData)
            }
            return nil
        }

        // Extract palette from decompressed data
        if let palette = extractStandardSHRPalette(from: decompressedData) {
            // Update platform name to indicate packed source
            return PaletteInfo(
                type: palette.type,
                palettes: palette.palettes,
                colorsPerPalette: palette.colorsPerPalette,
                platformName: "Apple IIgs Packed",
                scbMapping: palette.scbMapping
            )
        }

        return nil
    }

    /// Extract palette from Paintworks format (PNT $0000)
    /// Paintworks stores a single 16-color palette at offset 0x00-0x1F
    private static func extractPaintworksPalette(from data: Data) -> PaletteInfo? {
        // Paintworks needs at least 32 bytes for palette
        guard data.count >= 32 else { return nil }

        // Read Super Hi-Res Palette (offset +$00 to +$1F)
        // Format: 2 bytes per color, 16 colors
        // Low byte: GB (green in high nibble, blue in low nibble)
        // High byte: 0R (red in low nibble)
        var colors: [PaletteColor] = []
        for i in 0..<16 {
            let low = data[i * 2]
            let high = data[i * 2 + 1]
            let red = UInt8((high & 0x0F) * 17)
            let green = UInt8(((low >> 4) & 0x0F) * 17)
            let blue = UInt8((low & 0x0F) * 17)
            colors.append(PaletteColor(r: red, g: green, b: blue))
        }

        return PaletteInfo(
            singlePalette: colors,
            platformName: "Apple IIgs Paintworks"
        )
    }

    /// Extract 3200-color mode palette (200 palettes, one per scanline)
    private static func extract3200ColorPalette(from data: Data) -> PaletteInfo? {
        let brooksPaletteOffset = 32000

        guard data.count >= brooksPaletteOffset + (200 * 32) else { return nil }

        var palettes: [[PaletteColor]] = []

        // Read 200 palettes (one per scanline)
        for y in 0..<200 {
            let pOffset = brooksPaletteOffset + (y * 32)
            if pOffset + 32 <= data.count {
                let palette = readAppleIIgsPalette(from: data, offset: pOffset, reverseOrder: true)
                palettes.append(palette)
            }
        }

        return PaletteInfo(
            type: .perScanline,
            palettes: palettes,
            colorsPerPalette: 16,
            platformName: "Apple IIgs 3200"
        )
    }

    /// Extract 3201 format palette (compressed 3200-color)
    /// Layout: +$00/4: "APP\0" (high-ASCII), +$04/6400: palettes (200×16×2), +$1904/xx: PackBytes pixels
    private static func extract3201Palette(from data: Data) -> PaletteInfo? {
        // Check minimum size: 4 (header) + 6400 (palettes)
        guard data.count > 6404 else { return nil }

        // Verify "APP\0" header (high-ASCII: 0xC1, 0xD0, 0xD0, 0x00)
        let hasAppHeader = (data[0] == 0xC1 && data[1] == 0xD0 && data[2] == 0xD0 && data[3] == 0x00)
        guard hasAppHeader else { return nil }

        let paletteOffset = 4

        // Parse 200 palettes (one per scanline, 16 colors each, 2 bytes per color)
        // Note: Colors are stored in reverse order (color 0 in file = color 15 in use)
        var palettes: [[PaletteColor]] = []
        for line in 0..<200 {
            var linePalette = [PaletteColor](repeating: PaletteColor(r: 0, g: 0, b: 0), count: 16)
            for color in 0..<16 {
                let offset = paletteOffset + (line * 32) + (color * 2)
                guard offset + 1 < data.count else { break }
                let low = data[offset]
                let high = data[offset + 1]
                // SHR palette format: low byte = GB, high byte = 0R
                let r = UInt8((high & 0x0F) * 17)
                let g = UInt8(((low >> 4) & 0x0F) * 17)
                let b = UInt8((low & 0x0F) * 17)
                // Store in reverse order: file color 0 -> slot 15, file color 1 -> slot 14, etc.
                linePalette[15 - color] = PaletteColor(r: r, g: g, b: b)
            }
            palettes.append(linePalette)
        }

        return PaletteInfo(
            type: .perScanline,
            palettes: palettes,
            colorsPerPalette: 16,
            platformName: "Apple IIgs 3201"
        )
    }

    /// Extract DreamGrafix palette
    private static func extractDreamGrafixPalette(from data: Data, mode: String) -> PaletteInfo? {
        // DreamGrafix footer at end of file (17 bytes)
        guard data.count >= 17 else { return nil }

        let footerOffset = data.count - 17

        // Verify "DreamWorld" signature
        guard data[footerOffset + 6] == 10 else { return nil }  // String length = 10
        let signatureData = data.subdata(in: (footerOffset + 7)..<(footerOffset + 17))
        guard String(data: signatureData, encoding: .ascii) == "DreamWorld" else { return nil }

        // Get color mode from footer
        let colorMode = UInt16(data[footerOffset]) | (UInt16(data[footerOffset + 1]) << 8)
        let is3200Color = colorMode == 1

        // Try to decompress LZW data to get palettes
        let compressedData = data.subdata(in: 0..<(data.count - 17))
        guard let decompressedData = decompressDreamGrafixLZW(data: compressedData) else {
            // If decompression fails, try as unpacked data
            return extractDreamGrafixPaletteFromUnpacked(data: compressedData, is3200Color: is3200Color)
        }

        return extractDreamGrafixPaletteFromUnpacked(data: decompressedData, is3200Color: is3200Color)
    }

    /// Extract palette from decompressed/unpacked DreamGrafix data
    private static func extractDreamGrafixPaletteFromUnpacked(data: Data, is3200Color: Bool) -> PaletteInfo? {
        if is3200Color {
            // 3200-color: 32000 pixels + 6400 bytes palette (200 lines × 16 colors × 2 bytes)
            let paletteOffset = 32000
            guard data.count >= paletteOffset + 6400 else { return nil }

            var palettes: [[PaletteColor]] = []
            for line in 0..<200 {
                var colors: [PaletteColor] = []
                for colorIdx in 0..<16 {
                    let offset = paletteOffset + (line * 32) + (colorIdx * 2)
                    guard offset + 1 < data.count else {
                        colors.append(PaletteColor(r: 0, g: 0, b: 0))
                        continue
                    }
                    let low = data[offset]
                    let high = data[offset + 1]
                    let r = UInt8((high & 0x0F) * 17)
                    let g = UInt8(((low >> 4) & 0x0F) * 17)
                    let b = UInt8((low & 0x0F) * 17)
                    colors.append(PaletteColor(r: r, g: g, b: b))
                }
                palettes.append(colors)
            }

            return PaletteInfo(
                type: .perScanline,
                palettes: palettes,
                colorsPerPalette: 16,
                platformName: "DreamGrafix 3200"
            )
        } else {
            // 256-color: 32000 pixels + 256 SCB + 512 bytes palette (16 palettes × 16 colors × 2 bytes)
            let scbOffset = 32000
            let paletteOffset = scbOffset + 256
            guard data.count >= paletteOffset + 512 else { return nil }

            var palettes: [[PaletteColor]] = []
            for paletteIdx in 0..<16 {
                var colors: [PaletteColor] = []
                for colorIdx in 0..<16 {
                    let offset = paletteOffset + (paletteIdx * 32) + (colorIdx * 2)
                    guard offset + 1 < data.count else {
                        colors.append(PaletteColor(r: 0, g: 0, b: 0))
                        continue
                    }
                    let low = data[offset]
                    let high = data[offset + 1]
                    let r = UInt8((high & 0x0F) * 17)
                    let g = UInt8(((low >> 4) & 0x0F) * 17)
                    let b = UInt8((low & 0x0F) * 17)
                    colors.append(PaletteColor(r: r, g: g, b: b))
                }
                palettes.append(colors)
            }

            // Read SCB mapping
            var scbMapping: [Int] = []
            for y in 0..<200 {
                if scbOffset + y < data.count {
                    let scb = data[scbOffset + y]
                    scbMapping.append(Int(scb & 0x0F))
                } else {
                    scbMapping.append(0)
                }
            }

            return PaletteInfo(
                type: .multiPalette,
                palettes: palettes,
                colorsPerPalette: 16,
                platformName: "DreamGrafix",
                scbMapping: scbMapping
            )
        }
    }

    /// Decompress DreamGrafix LZW data (GIF-style variable width 9-12 bits)
    private static func decompressDreamGrafixLZW(data: Data) -> Data? {
        guard data.count > 0 else { return nil }

        var output = Data()
        output.reserveCapacity(65536)

        let clearCode = 256
        let endCode = 257
        let maxCode = 4095

        var codeWidth = 9
        var nextCodeWidthThreshold = 512

        var dictionary: [[UInt8]] = []

        func resetDictionary() {
            dictionary = []
            for i in 0..<256 {
                dictionary.append([UInt8(i)])
            }
            dictionary.append([])  // clear code
            dictionary.append([])  // end code
            codeWidth = 9
            nextCodeWidthThreshold = 512
        }

        resetDictionary()

        var bitBuffer: UInt32 = 0
        var bitsInBuffer = 0
        var bytePos = 0

        func readCode() -> Int? {
            while bitsInBuffer < codeWidth && bytePos < data.count {
                bitBuffer |= UInt32(data[bytePos]) << bitsInBuffer
                bitsInBuffer += 8
                bytePos += 1
            }
            guard bitsInBuffer >= codeWidth else { return nil }
            let mask = (1 << codeWidth) - 1
            let code = Int(bitBuffer) & mask
            bitBuffer >>= codeWidth
            bitsInBuffer -= codeWidth
            return code
        }

        guard let firstCodeValue = readCode() else { return nil }

        var prevCode: Int

        if firstCodeValue == clearCode {
            guard let nextCode = readCode() else { return nil }
            if nextCode == endCode { return output }
            if nextCode < 256 { output.append(UInt8(nextCode)) }
            prevCode = nextCode
        } else if firstCodeValue < 256 {
            output.append(UInt8(firstCodeValue))
            prevCode = firstCodeValue
        } else {
            return nil
        }

        if prevCode == endCode { return output }

        while let code = readCode() {
            if code == endCode { break }

            if code == clearCode {
                resetDictionary()
                guard let nextCode = readCode() else { break }
                if nextCode == endCode { break }
                if nextCode < 256 {
                    output.append(UInt8(nextCode))
                    prevCode = nextCode
                }
                continue
            }

            var sequence: [UInt8]

            if code < dictionary.count {
                sequence = dictionary[code]
            } else if code == dictionary.count {
                if prevCode < dictionary.count {
                    let prevSequence = dictionary[prevCode]
                    sequence = prevSequence + [prevSequence[0]]
                } else {
                    break
                }
            } else {
                break
            }

            output.append(contentsOf: sequence)

            if dictionary.count <= maxCode && prevCode < dictionary.count {
                let prevSequence = dictionary[prevCode]
                dictionary.append(prevSequence + [sequence[0]])

                if dictionary.count == nextCodeWidthThreshold && codeWidth < 12 {
                    codeWidth += 1
                    nextCodeWidthThreshold *= 2
                }
            }

            prevCode = code

            if output.count > 50000 { break }
        }

        return output.isEmpty ? nil : output
    }

    /// Extract palette from Apple Preferred Format (APF) data
    private static func extractAPFPalette(from data: Data, is3200: Bool) -> PaletteInfo? {
        // Parse APF blocks to find MAIN block with color tables
        var pos = 0

        while pos + 5 <= data.count {
            let blockLength = Int(data[pos]) |
                            (Int(data[pos + 1]) << 8) |
                            (Int(data[pos + 2]) << 16) |
                            (Int(data[pos + 3]) << 24)

            guard blockLength >= 5 && pos + blockLength <= data.count else { break }

            let nameLength = Int(data[pos + 4])
            guard nameLength > 0 && nameLength <= 20 && pos + 5 + nameLength <= data.count else { break }

            let nameData = data[(pos + 5)..<(pos + 5 + nameLength)]
            guard let blockName = String(data: nameData, encoding: .ascii) else { break }

            let dataOffset = pos + 5 + nameLength
            let dataLength = blockLength - 5 - nameLength

            if blockName == "MAIN" && dataLength > 6 {
                // Parse MAIN block to extract color tables
                let blockData = data.subdata(in: dataOffset..<(dataOffset + dataLength))
                return parseAPFMainBlockPalette(from: blockData, is3200: is3200)
            }

            if blockName == "MULTIPAL" && is3200 && dataLength > 0 {
                // Parse MULTIPAL block for 3200-color mode
                let blockData = data.subdata(in: dataOffset..<(dataOffset + dataLength))
                return parseMultipalBlock(from: blockData)
            }

            pos += blockLength
        }

        return nil
    }

    /// Parse palette from APF MAIN block
    private static func parseAPFMainBlockPalette(from data: Data, is3200: Bool) -> PaletteInfo? {
        var pos = 0

        guard pos + 6 <= data.count else { return nil }

        // Skip masterMode and pixelsPerScanLine
        pos += 4
        let numColorTables = Int(data[pos]) | (Int(data[pos + 1]) << 8)
        pos += 2

        guard numColorTables > 0 && numColorTables <= 16 else { return nil }

        // Read color tables (each is 32 bytes = 16 colors x 2 bytes)
        var palettes: [[PaletteColor]] = []
        for _ in 0..<numColorTables {
            guard pos + 32 <= data.count else { break }
            let palette = readAPFColorTable(from: data, at: pos)
            palettes.append(palette)
            pos += 32
        }

        guard !palettes.isEmpty else { return nil }

        // Read numScanLines to create SCB mapping
        guard pos + 2 <= data.count else {
            return PaletteInfo(
                type: .multiPalette,
                palettes: palettes,
                colorsPerPalette: 16,
                platformName: "Apple IIgs APF"
            )
        }

        let numScanLines = Int(data[pos]) | (Int(data[pos + 1]) << 8)
        pos += 2

        // Read scan line directory to get SCB mapping
        var scbMapping: [Int] = []
        for _ in 0..<numScanLines {
            guard pos + 4 <= data.count else { break }
            // Skip packedBytes (2 bytes), read mode (2 bytes)
            pos += 2
            let mode = UInt16(data[pos]) | (UInt16(data[pos + 1]) << 8)
            let paletteIndex = Int(mode & 0x0F)
            scbMapping.append(min(paletteIndex, palettes.count - 1))
            pos += 2
        }

        return PaletteInfo(
            type: .multiPalette,
            palettes: palettes,
            colorsPerPalette: 16,
            platformName: "Apple IIgs APF",
            scbMapping: scbMapping.isEmpty ? nil : scbMapping
        )
    }

    /// Parse MULTIPAL block for 3200-color mode
    private static func parseMultipalBlock(from data: Data) -> PaletteInfo? {
        // MULTIPAL contains 200 palettes (one per scanline), each with 32 bytes (16 colors x 2 bytes)
        let numScanLines = 200
        var palettes: [[PaletteColor]] = []

        for y in 0..<numScanLines {
            let offset = y * 32
            guard offset + 32 <= data.count else { break }
            let palette = readAPFColorTable(from: data, at: offset)
            palettes.append(palette)
        }

        guard palettes.count >= 200 else { return nil }

        return PaletteInfo(
            type: .perScanline,
            palettes: palettes,
            colorsPerPalette: 16,
            platformName: "Apple IIgs APF 3200"
        )
    }

    /// Read color table from APF format (same as IIgs palette format)
    private static func readAPFColorTable(from data: Data, at offset: Int) -> [PaletteColor] {
        var colors: [PaletteColor] = []

        for i in 0..<16 {
            guard offset + (i * 2) + 1 < data.count else {
                colors.append(PaletteColor(r: 0, g: 0, b: 0))
                continue
            }

            let byte1 = data[offset + (i * 2)]
            let byte2 = data[offset + (i * 2) + 1]

            // IIgs format: byte1 = 0G0B, byte2 = 000R (4-bit values)
            let red4   = (byte2 & 0x0F)
            let green4 = (byte1 & 0xF0) >> 4
            let blue4  = (byte1 & 0x0F)

            colors.append(PaletteColor(
                r: red4 * 17,
                g: green4 * 17,
                b: blue4 * 17
            ))
        }
        return colors
    }

    /// Read Apple IIgs palette (16 colors, 2 bytes each in $0RGB format)
    private static func readAppleIIgsPalette(from data: Data, offset: Int, reverseOrder: Bool) -> [PaletteColor] {
        var colors = [PaletteColor](repeating: PaletteColor(r: 0, g: 0, b: 0), count: 16)

        for i in 0..<16 {
            let colorIdx = reverseOrder ? (15 - i) : i
            guard offset + (i * 2) + 1 < data.count else { continue }

            let byte1 = data[offset + (i * 2)]
            let byte2 = data[offset + (i * 2) + 1]

            let red4   = (byte2 & 0x0F)
            let green4 = (byte1 & 0xF0) >> 4
            let blue4  = (byte1 & 0x0F)

            colors[colorIdx] = PaletteColor(
                r: red4 * 17,
                g: green4 * 17,
                b: blue4 * 17
            )
        }
        return colors
    }

    // MARK: - Apple II Fixed Palettes

    /// Create HGR palette (6 colors)
    private static func createHGRPalette() -> PaletteInfo {
        let colors: [PaletteColor] = [
            PaletteColor(r: 0, g: 0, b: 0),       // Black
            PaletteColor(r: 255, g: 255, b: 255), // White
            PaletteColor(r: 32, g: 192, b: 32),   // Green
            PaletteColor(r: 160, g: 32, b: 240),  // Purple
            PaletteColor(r: 255, g: 100, b: 0),   // Orange
            PaletteColor(r: 60, g: 60, b: 255)    // Blue
        ]
        return PaletteInfo(singlePalette: colors, platformName: "Apple II HGR")
    }

    /// Create DHGR palette (16 colors)
    private static func createDHGRPalette() -> PaletteInfo {
        let colors: [PaletteColor] = [
            PaletteColor(r: 0, g: 0, b: 0),           // 0: Black
            PaletteColor(r: 134, g: 18, b: 192),      // 1: Magenta
            PaletteColor(r: 0, g: 101, b: 43),        // 2: Dark Green
            PaletteColor(r: 48, g: 48, b: 255),       // 3: Blue
            PaletteColor(r: 165, g: 95, b: 0),        // 4: Brown
            PaletteColor(r: 172, g: 172, b: 172),     // 5: Light Gray
            PaletteColor(r: 0, g: 226, b: 0),         // 6: Light Green
            PaletteColor(r: 0, g: 255, b: 146),       // 7: Aqua
            PaletteColor(r: 224, g: 0, b: 39),        // 8: Red
            PaletteColor(r: 223, g: 17, b: 212),      // 9: Pink
            PaletteColor(r: 81, g: 81, b: 81),        // 10: Dark Gray
            PaletteColor(r: 78, g: 158, b: 255),      // 11: Light Blue
            PaletteColor(r: 255, g: 39, b: 0),        // 12: Orange
            PaletteColor(r: 255, g: 150, b: 153),     // 13: Light Pink
            PaletteColor(r: 255, g: 253, b: 0),       // 14: Yellow
            PaletteColor(r: 255, g: 255, b: 255)      // 15: White
        ]
        return PaletteInfo(singlePalette: colors, platformName: "Apple II DHGR")
    }

    // MARK: - Commodore 64 Palette

    private static func createC64Palette() -> PaletteInfo {
        let colors: [PaletteColor] = [
            PaletteColor(r: 0x00, g: 0x00, b: 0x00),  // 0: Black
            PaletteColor(r: 0xFF, g: 0xFF, b: 0xFF),  // 1: White
            PaletteColor(r: 0x68, g: 0x37, b: 0x2B),  // 2: Red
            PaletteColor(r: 0x70, g: 0xA4, b: 0xB2),  // 3: Cyan
            PaletteColor(r: 0x6F, g: 0x3D, b: 0x86),  // 4: Purple
            PaletteColor(r: 0x58, g: 0x8D, b: 0x43),  // 5: Green
            PaletteColor(r: 0x35, g: 0x28, b: 0x79),  // 6: Blue
            PaletteColor(r: 0xB8, g: 0xC7, b: 0x6F),  // 7: Yellow
            PaletteColor(r: 0x6F, g: 0x4F, b: 0x25),  // 8: Orange
            PaletteColor(r: 0x43, g: 0x39, b: 0x00),  // 9: Brown
            PaletteColor(r: 0x9A, g: 0x67, b: 0x59),  // 10: Light Red
            PaletteColor(r: 0x44, g: 0x44, b: 0x44),  // 11: Dark Grey
            PaletteColor(r: 0x6C, g: 0x6C, b: 0x6C),  // 12: Grey
            PaletteColor(r: 0x9A, g: 0xD2, b: 0x84),  // 13: Light Green
            PaletteColor(r: 0x6C, g: 0x5E, b: 0xB5),  // 14: Light Blue
            PaletteColor(r: 0x95, g: 0x95, b: 0x95)   // 15: Light Grey
        ]
        return PaletteInfo(singlePalette: colors, platformName: "Commodore 64")
    }

    // MARK: - Amiga IFF Palette

    private static func extractIFFPalette(from data: Data) -> PaletteInfo? {
        // Parse IFF chunks to find CMAP and detect HAM/EHB mode
        var offset = 12  // Skip FORM header
        var colors: [PaletteColor] = []
        var isHAM = false
        var isEHB = false
        var numPlanes = 0

        while offset + 8 < data.count {
            let chunkType = String(data: data[offset..<offset+4], encoding: .ascii) ?? ""
            let chunkSize = Int(ImageHelpers.readBigEndianUInt32(data: data, offset: offset + 4))

            switch chunkType {
            case "BMHD":
                // Get number of bitplanes
                if chunkSize >= 9 && offset + 8 + 8 < data.count {
                    numPlanes = Int(data[offset + 8 + 8])
                }

            case "CAMG":
                // Amiga viewport mode flags
                if chunkSize >= 4 {
                    let camgFlags = ImageHelpers.readBigEndianUInt32(data: data, offset: offset + 8)
                    isHAM = (camgFlags & 0x0800) != 0
                    isEHB = (camgFlags & 0x0080) != 0
                }

            case "CMAP":
                let numColors = chunkSize / 3
                for i in 0..<numColors {
                    let colorOffset = offset + 8 + (i * 3)
                    if colorOffset + 2 < data.count {
                        colors.append(PaletteColor(
                            r: data[colorOffset],
                            g: data[colorOffset + 1],
                            b: data[colorOffset + 2]
                        ))
                    }
                }

            default:
                break
            }

            offset += 8 + chunkSize
            if chunkSize % 2 != 0 { offset += 1 }  // Padding
        }

        guard !colors.isEmpty else { return nil }

        // For HAM mode, extract actual colors from the decoded image
        if isHAM {
            let hamType = numPlanes == 8 ? "HAM8" : "HAM6"
            let maxColors = numPlanes == 8 ? "262144" : "4096"
            let platformName = "Amiga \(hamType) (\(maxColors) colors)"

            // Decode the image to extract actual colors
            let (cgImage, _) = AmigaIFFDecoder.decode(data: data)
            if let image = cgImage {
                let extractedColors = extractColorsFromImage(image, maxColors: 256)
                if !extractedColors.isEmpty {
                    return PaletteInfo(
                        fixedPalette: extractedColors,
                        platformName: platformName
                    )
                }
            }

            // Fallback to base palette if extraction fails
            return PaletteInfo(
                fixedPalette: colors,
                platformName: platformName + " (base palette)"
            )
        }

        // Determine platform name based on mode
        let platformName: String
        if isEHB {
            platformName = "Amiga EHB"
        } else {
            platformName = "Amiga"
        }

        return PaletteInfo(
            singlePalette: colors,
            platformName: platformName
        )
    }

    /// Extract unique colors from a CGImage (for HAM and other generated palettes)
    private static func extractColorsFromImage(_ image: CGImage, maxColors: Int) -> [PaletteColor] {
        let width = image.width
        let height = image.height

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return []
        }

        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let data = context.data else { return [] }
        let pixels = data.bindMemory(to: UInt8.self, capacity: width * height * 4)

        // Count color occurrences
        var colorCounts: [UInt32: Int] = [:]
        for i in 0..<(width * height) {
            let offset = i * 4
            let r = pixels[offset]
            let g = pixels[offset + 1]
            let b = pixels[offset + 2]
            let colorKey = UInt32(r) << 16 | UInt32(g) << 8 | UInt32(b)
            colorCounts[colorKey, default: 0] += 1
        }

        // Sort by frequency and take top colors
        let sortedColors = colorCounts.sorted { $0.value > $1.value }
        let topColors = sortedColors.prefix(maxColors)

        return topColors.map { (colorKey, _) in
            let r = UInt8((colorKey >> 16) & 0xFF)
            let g = UInt8((colorKey >> 8) & 0xFF)
            let b = UInt8(colorKey & 0xFF)
            return PaletteColor(r: r, g: g, b: b)
        }
    }

    // MARK: - Atari ST Degas Palette

    private static func extractDegasPalette(from data: Data, resolution: String) -> PaletteInfo? {
        guard data.count >= 34 else { return nil }

        let numColors: Int
        switch resolution {
        case "Low": numColors = 16
        case "Medium": numColors = 4
        case "High": numColors = 2
        default: numColors = 16
        }

        var colors: [PaletteColor] = []

        for i in 0..<numColors {
            let colorWord = ImageHelpers.readBigEndianUInt16(data: data, offset: 2 + (i * 2))

            // Atari ST 3-bit RGB
            let r3 = (colorWord >> 8) & 0x07
            let g3 = (colorWord >> 4) & 0x07
            let b3 = colorWord & 0x07

            colors.append(PaletteColor(
                r: UInt8((Int(r3) * 255) / 7),
                g: UInt8((Int(g3) * 255) / 7),
                b: UInt8((Int(b3) * 255) / 7)
            ))
        }

        return PaletteInfo(
            singlePalette: colors,
            platformName: "Atari ST"
        )
    }

    // MARK: - ZX Spectrum Palette

    private static func createZXSpectrumPalette() -> PaletteInfo {
        // ZX Spectrum has 8 colors, each with normal and bright variants
        let colors: [PaletteColor] = [
            // Normal colors
            PaletteColor(r: 0, g: 0, b: 0),       // Black
            PaletteColor(r: 0, g: 0, b: 205),     // Blue
            PaletteColor(r: 205, g: 0, b: 0),     // Red
            PaletteColor(r: 205, g: 0, b: 205),   // Magenta
            PaletteColor(r: 0, g: 205, b: 0),     // Green
            PaletteColor(r: 0, g: 205, b: 205),   // Cyan
            PaletteColor(r: 205, g: 205, b: 0),   // Yellow
            PaletteColor(r: 205, g: 205, b: 205), // White
            // Bright colors
            PaletteColor(r: 0, g: 0, b: 0),       // Black (bright)
            PaletteColor(r: 0, g: 0, b: 255),     // Blue (bright)
            PaletteColor(r: 255, g: 0, b: 0),     // Red (bright)
            PaletteColor(r: 255, g: 0, b: 255),   // Magenta (bright)
            PaletteColor(r: 0, g: 255, b: 0),     // Green (bright)
            PaletteColor(r: 0, g: 255, b: 255),   // Cyan (bright)
            PaletteColor(r: 255, g: 255, b: 0),   // Yellow (bright)
            PaletteColor(r: 255, g: 255, b: 255)  // White (bright)
        ]
        return PaletteInfo(singlePalette: colors, platformName: "ZX Spectrum")
    }

    // MARK: - Amstrad CPC Palette

    private static func createAmstradCPCPalette(mode: Int) -> PaletteInfo {
        // Amstrad CPC has a 27-color hardware palette, but we'll return the commonly used colors
        let colors: [PaletteColor]

        switch mode {
        case 0: // 16 colors
            colors = createCPCMode0Palette()
        case 1: // 4 colors
            colors = createCPCMode1Palette()
        case 2: // 2 colors
            colors = [
                PaletteColor(r: 0, g: 0, b: 0),
                PaletteColor(r: 255, g: 255, b: 255)
            ]
        default:
            colors = createCPCMode0Palette()
        }

        return PaletteInfo(singlePalette: colors, platformName: "Amstrad CPC")
    }

    private static func createCPCMode0Palette() -> [PaletteColor] {
        return [
            PaletteColor(r: 0, g: 0, b: 0),       // Black
            PaletteColor(r: 0, g: 0, b: 128),     // Blue
            PaletteColor(r: 0, g: 0, b: 255),     // Bright Blue
            PaletteColor(r: 128, g: 0, b: 0),     // Red
            PaletteColor(r: 128, g: 0, b: 128),   // Magenta
            PaletteColor(r: 128, g: 0, b: 255),   // Mauve
            PaletteColor(r: 255, g: 0, b: 0),     // Bright Red
            PaletteColor(r: 255, g: 0, b: 128),   // Purple
            PaletteColor(r: 255, g: 0, b: 255),   // Bright Magenta
            PaletteColor(r: 0, g: 128, b: 0),     // Green
            PaletteColor(r: 0, g: 128, b: 128),   // Cyan
            PaletteColor(r: 0, g: 128, b: 255),   // Sky Blue
            PaletteColor(r: 128, g: 128, b: 0),   // Yellow
            PaletteColor(r: 128, g: 128, b: 128), // White
            PaletteColor(r: 128, g: 128, b: 255), // Pastel Blue
            PaletteColor(r: 255, g: 128, b: 0)    // Orange
        ]
    }

    private static func createCPCMode1Palette() -> [PaletteColor] {
        return [
            PaletteColor(r: 0, g: 0, b: 128),     // Blue
            PaletteColor(r: 255, g: 255, b: 0),   // Yellow
            PaletteColor(r: 0, g: 255, b: 255),   // Cyan
            PaletteColor(r: 255, g: 0, b: 0)      // Red
        ]
    }

    // MARK: - PCX Palette

    private static func extractPCXPalette(from data: Data, bitsPerPixel: Int) -> PaletteInfo? {
        guard data.count >= 128, data[0] == 0x0A else { return nil }

        // Read header info
        let headerBitsPerPixel = Int(data[3])
        let xMin = Int(data[4]) | (Int(data[5]) << 8)
        let xMax = Int(data[8]) | (Int(data[9]) << 8)
        let width = xMax - xMin + 1
        let numPlanes = Int(data[65])
        let bytesPerLine = Int(data[66]) | (Int(data[67]) << 8)

        // Detect CGA header mismatch (header says 1bpp but bytesPerLine indicates 2bpp)
        let calculatedBitsPerPixel = width > 0 ? (bytesPerLine * 8) / width : headerBitsPerPixel
        let isCGA4Color = headerBitsPerPixel == 1 && numPlanes == 1 && calculatedBitsPerPixel == 2

        // Read header palette (16 colors at offset 16-63)
        var headerPalette: [PaletteColor] = []
        for i in 0..<16 {
            let offset = 16 + i * 3
            if offset + 2 < data.count {
                headerPalette.append(PaletteColor(
                    r: data[offset],
                    g: data[offset + 1],
                    b: data[offset + 2]
                ))
            }
        }

        // CGA 4-color mode (2bpp, 1 plane)
        if isCGA4Color {
            let cgaPalette: [PaletteColor]
            if !headerPalette.isEmpty && headerPalette.count >= 4 {
                cgaPalette = Array(headerPalette.prefix(4))
            } else {
                // Default CGA palette 1 (cyan, magenta, white)
                cgaPalette = [
                    PaletteColor(r: 0, g: 0, b: 0),
                    PaletteColor(r: 0, g: 170, b: 170),
                    PaletteColor(r: 170, g: 0, b: 170),
                    PaletteColor(r: 170, g: 170, b: 170)
                ]
            }
            return PaletteInfo(singlePalette: cgaPalette, platformName: "PCX CGA")
        }

        // EGA 16-color planar mode (1bpp, 4 planes)
        if headerBitsPerPixel == 1 && numPlanes == 4 {
            let egaPalette = !headerPalette.isEmpty ? headerPalette : createEGAPalette()
            return PaletteInfo(singlePalette: egaPalette, platformName: "PCX EGA 16-color")
        }

        // EGA 64-color planar mode (2bpp, 4 planes)
        if headerBitsPerPixel == 2 && numPlanes == 4 {
            let ega64Palette = createEGA64Palette()
            return PaletteInfo(singlePalette: ega64Palette, platformName: "PCX EGA 64-color")
        }

        // 4-bit single plane (16 colors)
        if headerBitsPerPixel == 4 && numPlanes == 1 {
            let egaPalette = !headerPalette.isEmpty ? headerPalette : createEGAPalette()
            return PaletteInfo(singlePalette: egaPalette, platformName: "PCX 16-color")
        }

        // Monochrome (1bpp, 1 plane)
        if headerBitsPerPixel == 1 && numPlanes == 1 {
            let monoPalette: [PaletteColor]
            if headerPalette.count >= 2 {
                monoPalette = Array(headerPalette.prefix(2))
            } else {
                monoPalette = [
                    PaletteColor(r: 0, g: 0, b: 0),
                    PaletteColor(r: 255, g: 255, b: 255)
                ]
            }
            return PaletteInfo(singlePalette: monoPalette, platformName: "PCX Monochrome")
        }

        // VGA 256-color mode (8bpp, 1 plane) - palette at end of file
        if headerBitsPerPixel == 8 && numPlanes == 1 && data.count > 769 {
            let markerOffset = data.count - 769
            if data[markerOffset] == 0x0C {
                var colors: [PaletteColor] = []
                for i in 0..<256 {
                    let offset = markerOffset + 1 + (i * 3)
                    if offset + 2 < data.count {
                        colors.append(PaletteColor(
                            r: data[offset],
                            g: data[offset + 1],
                            b: data[offset + 2]
                        ))
                    }
                }
                return PaletteInfo(singlePalette: colors, platformName: "PCX VGA")
            }
        }

        // Fallback: use header palette if available
        if !headerPalette.isEmpty {
            return PaletteInfo(singlePalette: headerPalette, platformName: "PCX")
        }

        return nil
    }

    // MARK: - PCX Palette Helpers

    private static func createEGAPalette() -> [PaletteColor] {
        return [
            PaletteColor(r: 0, g: 0, b: 0),       // 0: Black
            PaletteColor(r: 0, g: 0, b: 170),     // 1: Blue
            PaletteColor(r: 0, g: 170, b: 0),     // 2: Green
            PaletteColor(r: 0, g: 170, b: 170),   // 3: Cyan
            PaletteColor(r: 170, g: 0, b: 0),     // 4: Red
            PaletteColor(r: 170, g: 0, b: 170),   // 5: Magenta
            PaletteColor(r: 170, g: 85, b: 0),    // 6: Brown
            PaletteColor(r: 170, g: 170, b: 170), // 7: Light Gray
            PaletteColor(r: 85, g: 85, b: 85),    // 8: Dark Gray
            PaletteColor(r: 85, g: 85, b: 255),   // 9: Light Blue
            PaletteColor(r: 85, g: 255, b: 85),   // 10: Light Green
            PaletteColor(r: 85, g: 255, b: 255),  // 11: Light Cyan
            PaletteColor(r: 255, g: 85, b: 85),   // 12: Light Red
            PaletteColor(r: 255, g: 85, b: 255),  // 13: Light Magenta
            PaletteColor(r: 255, g: 255, b: 85),  // 14: Yellow
            PaletteColor(r: 255, g: 255, b: 255)  // 15: White
        ]
    }

    private static func createEGA64Palette() -> [PaletteColor] {
        var palette: [PaletteColor] = []
        for i in 0..<64 {
            // EGA 64-color: RrGgBb format (2 bits each)
            let r = ((i >> 5) & 1) * 170 + ((i >> 2) & 1) * 85
            let g = ((i >> 4) & 1) * 170 + ((i >> 1) & 1) * 85
            let b = ((i >> 3) & 1) * 170 + (i & 1) * 85
            palette.append(PaletteColor(r: UInt8(r), g: UInt8(g), b: UInt8(b)))
        }
        return palette
    }

    // MARK: - BMP Palette

    private static func extractBMPPalette(from data: Data, bitsPerPixel: Int) -> PaletteInfo? {
        guard bitsPerPixel <= 8, data.count > 54 else { return nil }

        // Read DIB header size to find correct palette offset
        let dibHeaderSize = Int(data[14]) | (Int(data[15]) << 8) | (Int(data[16]) << 16) | (Int(data[17]) << 24)
        let paletteOffset = 14 + dibHeaderSize

        // Check if file specifies number of colors used (at offset 46 for BITMAPINFOHEADER)
        var numColors = 1 << bitsPerPixel
        if dibHeaderSize >= 40 && data.count > 50 {
            let colorsUsed = Int(data[46]) | (Int(data[47]) << 8) | (Int(data[48]) << 16) | (Int(data[49]) << 24)
            if colorsUsed > 0 && colorsUsed < numColors {
                numColors = colorsUsed
            }
        }

        guard paletteOffset + (numColors * 4) <= data.count else { return nil }

        var colors: [PaletteColor] = []

        for i in 0..<numColors {
            let offset = paletteOffset + (i * 4)  // BGRA format (4 bytes per color)
            if offset + 3 < data.count {
                colors.append(PaletteColor(
                    r: data[offset + 2],  // R
                    g: data[offset + 1],  // G
                    b: data[offset]       // B
                ))
            }
        }

        return PaletteInfo(singlePalette: colors, platformName: "BMP")
    }

    // MARK: - MacPaint Palette

    private static func createMacPaintPalette() -> PaletteInfo {
        let colors = [
            PaletteColor(r: 255, g: 255, b: 255),  // White
            PaletteColor(r: 0, g: 0, b: 0)         // Black
        ]
        return PaletteInfo(singlePalette: colors, platformName: "MacPaint")
    }

    // MARK: - MSX Palette (TMS9918)

    private static func createMSXPalette(mode: Int) -> PaletteInfo {
        let colors: [PaletteColor] = [
            PaletteColor(r: 0x00, g: 0x00, b: 0x00),  // 0: Transparent (rendered as black)
            PaletteColor(r: 0x00, g: 0x00, b: 0x00),  // 1: Black
            PaletteColor(r: 0x21, g: 0xC8, b: 0x42),  // 2: Medium Green
            PaletteColor(r: 0x5E, g: 0xDC, b: 0x78),  // 3: Light Green
            PaletteColor(r: 0x54, g: 0x55, b: 0xED),  // 4: Dark Blue
            PaletteColor(r: 0x7D, g: 0x76, b: 0xFC),  // 5: Light Blue
            PaletteColor(r: 0xD4, g: 0x52, b: 0x4D),  // 6: Dark Red
            PaletteColor(r: 0x42, g: 0xEB, b: 0xF5),  // 7: Cyan
            PaletteColor(r: 0xFC, g: 0x55, b: 0x54),  // 8: Medium Red
            PaletteColor(r: 0xFF, g: 0x79, b: 0x78),  // 9: Light Red
            PaletteColor(r: 0xD4, g: 0xC1, b: 0x54),  // 10: Dark Yellow
            PaletteColor(r: 0xE6, g: 0xCE, b: 0x80),  // 11: Light Yellow
            PaletteColor(r: 0x21, g: 0xB0, b: 0x3B),  // 12: Dark Green
            PaletteColor(r: 0xC9, g: 0x5B, b: 0xBA),  // 13: Magenta
            PaletteColor(r: 0xCC, g: 0xCC, b: 0xCC),  // 14: Gray
            PaletteColor(r: 0xFF, g: 0xFF, b: 0xFF)   // 15: White
        ]
        return PaletteInfo(singlePalette: colors, platformName: "MSX Screen \(mode)")
    }

    // MARK: - BBC Micro Palette

    private static func createBBCMicroPalette(mode: Int) -> PaletteInfo {
        let fullPalette: [PaletteColor] = [
            PaletteColor(r: 0x00, g: 0x00, b: 0x00),  // 0: Black
            PaletteColor(r: 0xFF, g: 0x00, b: 0x00),  // 1: Red
            PaletteColor(r: 0x00, g: 0xFF, b: 0x00),  // 2: Green
            PaletteColor(r: 0xFF, g: 0xFF, b: 0x00),  // 3: Yellow
            PaletteColor(r: 0x00, g: 0x00, b: 0xFF),  // 4: Blue
            PaletteColor(r: 0xFF, g: 0x00, b: 0xFF),  // 5: Magenta
            PaletteColor(r: 0x00, g: 0xFF, b: 0xFF),  // 6: Cyan
            PaletteColor(r: 0xFF, g: 0xFF, b: 0xFF)   // 7: White
        ]

        let colors: [PaletteColor]
        switch mode {
        case 0, 4:  // 2 colors
            colors = [fullPalette[0], fullPalette[7]]
        case 1, 5:  // 4 colors
            colors = [fullPalette[0], fullPalette[1], fullPalette[3], fullPalette[7]]
        case 2:     // 16 logical colors (8 physical + flash)
            colors = fullPalette + fullPalette  // Duplicate for flash colors
        default:
            colors = fullPalette
        }

        return PaletteInfo(singlePalette: colors, platformName: "BBC Micro MODE \(mode)")
    }

    // MARK: - TRS-80 / CoCo Palette

    private static func createTRS80Palette(model: String) -> PaletteInfo {
        if model.contains("CoCo") {
            // Color Computer palette
            let colors: [PaletteColor] = [
                PaletteColor(r: 0x00, g: 0xFF, b: 0x00),  // 0: Green
                PaletteColor(r: 0xFF, g: 0xFF, b: 0x00),  // 1: Yellow
                PaletteColor(r: 0x00, g: 0x00, b: 0xFF),  // 2: Blue
                PaletteColor(r: 0xFF, g: 0x00, b: 0x00),  // 3: Red
                PaletteColor(r: 0xFF, g: 0xFF, b: 0xFF),  // 4: Buff (White)
                PaletteColor(r: 0x00, g: 0xFF, b: 0xFF),  // 5: Cyan
                PaletteColor(r: 0xFF, g: 0x00, b: 0xFF),  // 6: Magenta
                PaletteColor(r: 0xFF, g: 0x80, b: 0x00),  // 7: Orange
                PaletteColor(r: 0x00, g: 0x00, b: 0x00),  // 8: Black
                PaletteColor(r: 0x00, g: 0x80, b: 0x00),  // 9: Dark Green
                PaletteColor(r: 0x00, g: 0x00, b: 0x80),  // 10: Dark Blue
                PaletteColor(r: 0x80, g: 0x00, b: 0x00),  // 11: Dark Red
                PaletteColor(r: 0x80, g: 0x80, b: 0x80),  // 12: Gray
                PaletteColor(r: 0x00, g: 0x80, b: 0x80),  // 13: Dark Cyan
                PaletteColor(r: 0x80, g: 0x00, b: 0x80),  // 14: Dark Magenta
                PaletteColor(r: 0x80, g: 0x40, b: 0x00)   // 15: Brown
            ]
            return PaletteInfo(singlePalette: colors, platformName: "TRS-80 \(model)")
        } else {
            // Model I/III - green phosphor
            let colors: [PaletteColor] = [
                PaletteColor(r: 0x00, g: 0x20, b: 0x00),  // Off (dark green)
                PaletteColor(r: 0x33, g: 0xFF, b: 0x33)   // On (bright green)
            ]
            return PaletteInfo(singlePalette: colors, platformName: "TRS-80 \(model)")
        }
    }
}
