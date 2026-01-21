import Foundation
import CoreGraphics

// MARK: - DreamGrafix Decoder
// Implements DreamGrafix image format decoding:
// - PNT/$8005: Packed (12-bit LZW compressed)
// - PIC/$8003: Unpacked (raw data)
//
// File structure:
// - Main data (compressed or uncompressed)
// - 17-byte footer at end of file:
//   +$00-01: Color mode (0=256-color, 1=3200-color)
//   +$02-03: Height in pixels (typically 200)
//   +$04-05: Width in pixels (typically 320)
//   +$06: Length byte for "DreamWorld" string (10)
//   +$07-10: "DreamWorld" ASCII string
//
// Reference: CiderPress2 formatdoc/SuperHiRes-notes.html

class DreamGrafixDecoder {

    // MARK: - Footer Structure

    private struct DreamGrafixFooter {
        let colorMode: UInt16    // 0 = 256-color, 1 = 3200-color
        let height: UInt16       // Typically 200
        let width: UInt16        // Typically 320
        let signature: String    // "DreamWorld"

        var is3200Color: Bool { colorMode == 1 }
    }

    // MARK: - Public Decode Methods

    /// Decode DreamGrafix PNT/$8005 (LZW compressed)
    static func decodeDreamGrafixPacked(data: Data) -> (image: CGImage?, type: AppleIIImageType) {
        guard let footer = parseFooter(data: data) else {
            return (nil, .Unknown)
        }

        // Data without footer
        let compressedData = data.subdata(in: 0..<(data.count - 17))

        // Decompress using 12-bit LZW
        guard let decompressedData = decompressLZW12(data: compressedData) else {
            return (nil, .Unknown)
        }

        return renderDreamGrafix(data: decompressedData, footer: footer)
    }

    /// Decode DreamGrafix PIC/$8003 (uncompressed)
    static func decodeDreamGrafixUnpacked(data: Data) -> (image: CGImage?, type: AppleIIImageType) {
        guard let footer = parseFooter(data: data) else {
            return (nil, .Unknown)
        }

        // Data without footer
        let rawData = data.subdata(in: 0..<(data.count - 17))

        return renderDreamGrafix(data: rawData, footer: footer)
    }

    /// Detect if data has DreamGrafix signature
    static func isDreamGrafixFormat(_ data: Data) -> Bool {
        return parseFooter(data: data) != nil
    }

    // MARK: - Footer Parsing

    private static func parseFooter(data: Data) -> DreamGrafixFooter? {
        guard data.count >= 17 else { return nil }

        let footerOffset = data.count - 17

        // Read color mode (little-endian)
        let colorMode = UInt16(data[footerOffset]) | (UInt16(data[footerOffset + 1]) << 8)

        // Read height (little-endian)
        let height = UInt16(data[footerOffset + 2]) | (UInt16(data[footerOffset + 3]) << 8)

        // Read width (little-endian)
        let width = UInt16(data[footerOffset + 4]) | (UInt16(data[footerOffset + 5]) << 8)

        // Check length byte (should be 10 for "DreamWorld")
        let stringLength = Int(data[footerOffset + 6])
        guard stringLength == 10 else { return nil }

        // Read and verify "DreamWorld" signature
        guard footerOffset + 7 + 10 <= data.count else { return nil }
        let signatureData = data.subdata(in: (footerOffset + 7)..<(footerOffset + 17))
        guard let signature = String(data: signatureData, encoding: .ascii),
              signature == "DreamWorld" else {
            return nil
        }

        // Validate dimensions
        guard width > 0 && width <= 640 && height > 0 && height <= 400 else {
            return nil
        }

        // Validate color mode
        guard colorMode <= 1 else { return nil }

        return DreamGrafixFooter(
            colorMode: colorMode,
            height: height,
            width: width,
            signature: signature
        )
    }

    // MARK: - Variable-width LZW Decompression (GIF-style)
    // DreamGrafix uses GIF-style LZW with variable bit width (9-12 bits)
    // Starts at 9 bits, increases when dictionary fills up

    private static func decompressLZW12(data: Data) -> Data? {
        guard data.count > 0 else { return nil }

        var output = Data()
        output.reserveCapacity(65536)

        // LZW constants
        let clearCode = 256
        let endCode = 257
        let maxCode = 4095  // Max 12 bits

        // Variable code width (starts at 9 bits for 8-bit data)
        var codeWidth = 9
        var nextCodeWidthThreshold = 512  // When to increase code width

        // Dictionary: maps code -> sequence of bytes
        var dictionary: [[UInt8]] = []

        // Initialize dictionary with single-byte entries
        func resetDictionary() {
            dictionary = []
            for i in 0..<256 {
                dictionary.append([UInt8(i)])
            }
            // Add clear and end codes (indices 256, 257)
            dictionary.append([])  // clear code placeholder
            dictionary.append([])  // end code placeholder
            codeWidth = 9
            nextCodeWidthThreshold = 512
        }

        resetDictionary()

        // Bit reader for extracting variable-width codes (LSB-first)
        var bitBuffer: UInt32 = 0
        var bitsInBuffer = 0
        var bytePos = 0

        func readCode() -> Int? {
            // Fill buffer with enough bits
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

        // Read first code (should be clear code)
        guard let firstCodeValue = readCode() else { return nil }

        var prevCode: Int

        if firstCodeValue == clearCode {
            // Handle initial clear code
            guard let nextCode = readCode() else { return nil }
            if nextCode == endCode { return output }
            if nextCode < 256 {
                output.append(UInt8(nextCode))
            }
            prevCode = nextCode
        } else if firstCodeValue < 256 {
            output.append(UInt8(firstCodeValue))
            prevCode = firstCodeValue
        } else {
            return nil  // Invalid first code
        }

        if prevCode == endCode { return output }

        // Main decompression loop
        while let code = readCode() {
            if code == endCode {
                break
            }

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
                // Code is in dictionary
                sequence = dictionary[code]
            } else if code == dictionary.count {
                // Special case: code not yet in dictionary
                // This happens when encoder emits code for string just added
                if prevCode < dictionary.count {
                    let prevSequence = dictionary[prevCode]
                    sequence = prevSequence + [prevSequence[0]]
                } else {
                    // Error case
                    break
                }
            } else {
                // Invalid code
                break
            }

            // Output the sequence
            output.append(contentsOf: sequence)

            // Add new entry to dictionary: previous sequence + first byte of current
            if dictionary.count <= maxCode && prevCode < dictionary.count {
                let prevSequence = dictionary[prevCode]
                let newEntry = prevSequence + [sequence[0]]
                dictionary.append(newEntry)

                // Increase code width when dictionary reaches threshold
                if dictionary.count == nextCodeWidthThreshold && codeWidth < 12 {
                    codeWidth += 1
                    nextCodeWidthThreshold *= 2
                }
            }

            prevCode = code

            // Safety limit for 3200-color mode (38400 bytes max)
            if output.count > 50000 {
                break
            }
        }

        return output.isEmpty ? nil : output
    }

    // MARK: - Rendering

    private static func renderDreamGrafix(data: Data, footer: DreamGrafixFooter) -> (image: CGImage?, type: AppleIIImageType) {
        let width = Int(footer.width)
        let height = Int(footer.height)

        if footer.is3200Color {
            return render3200Color(data: data, width: width, height: height)
        } else {
            return render256Color(data: data, width: width, height: height)
        }
    }

    // MARK: - 256-Color Mode Rendering
    // Layout: 32000 pixels + 256 SCB + 512 palette + 512 optional

    private static func render256Color(data: Data, width: Int, height: Int) -> (image: CGImage?, type: AppleIIImageType) {
        let bytesPerLine = width / 2  // 2 pixels per byte in 320 mode
        let pixelDataSize = bytesPerLine * height
        let scbOffset = pixelDataSize
        let paletteOffset = scbOffset + 256

        guard data.count >= paletteOffset + 512 else {
            // Try rendering with just pixel data and default palette
            if data.count >= pixelDataSize {
                return renderWithDefaultPalette(data: data, width: width, height: height)
            }
            return (nil, .Unknown)
        }

        // Read palettes (16 palettes of 16 colors each)
        var palettes: [[(r: UInt8, g: UInt8, b: UInt8)]] = []
        for paletteIdx in 0..<16 {
            var colors: [(r: UInt8, g: UInt8, b: UInt8)] = []
            for colorIdx in 0..<16 {
                let offset = paletteOffset + (paletteIdx * 32) + (colorIdx * 2)
                guard offset + 1 < data.count else {
                    colors.append((0, 0, 0))
                    continue
                }
                let low = data[offset]
                let high = data[offset + 1]
                let r = UInt8((high & 0x0F) * 17)
                let g = UInt8(((low >> 4) & 0x0F) * 17)
                let b = UInt8((low & 0x0F) * 17)
                colors.append((r: r, g: g, b: b))
            }
            palettes.append(colors)
        }

        // Render image
        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)

        for y in 0..<height {
            // Get SCB for this line
            let scb = y < 256 && scbOffset + y < data.count ? data[scbOffset + y] : 0
            let paletteIndex = Int(scb & 0x0F)
            let is640Mode = (scb & 0x80) != 0
            let palette = paletteIndex < palettes.count ? palettes[paletteIndex] : palettes[0]

            for xByte in 0..<bytesPerLine {
                let dataIndex = y * bytesPerLine + xByte
                guard dataIndex < data.count else { continue }
                let byte = data[dataIndex]

                if is640Mode {
                    // 640 mode: 4 pixels per byte
                    for pixelInByte in 0..<4 {
                        let x = xByte * 4 + pixelInByte
                        if x >= width { break }

                        let highBit = (byte >> (7 - pixelInByte)) & 1
                        let lowBit = (byte >> (3 - pixelInByte)) & 1
                        let colorIndex = Int((highBit << 1) | lowBit)

                        let color = colorIndex < palette.count ? palette[colorIndex] : (0, 0, 0)
                        let bufIdx = (y * width + x) * 4

                        rgbaBuffer[bufIdx] = color.0
                        rgbaBuffer[bufIdx + 1] = color.1
                        rgbaBuffer[bufIdx + 2] = color.2
                        rgbaBuffer[bufIdx + 3] = 255
                    }
                } else {
                    // 320 mode: 2 pixels per byte
                    let x = xByte * 2

                    let colorIndex1 = Int((byte >> 4) & 0x0F)
                    let color1 = colorIndex1 < palette.count ? palette[colorIndex1] : (0, 0, 0)

                    if x < width {
                        let bufIdx1 = (y * width + x) * 4
                        rgbaBuffer[bufIdx1] = color1.0
                        rgbaBuffer[bufIdx1 + 1] = color1.1
                        rgbaBuffer[bufIdx1 + 2] = color1.2
                        rgbaBuffer[bufIdx1 + 3] = 255
                    }

                    let colorIndex2 = Int(byte & 0x0F)
                    let color2 = colorIndex2 < palette.count ? palette[colorIndex2] : (0, 0, 0)

                    if x + 1 < width {
                        let bufIdx2 = (y * width + x + 1) * 4
                        rgbaBuffer[bufIdx2] = color2.0
                        rgbaBuffer[bufIdx2 + 1] = color2.1
                        rgbaBuffer[bufIdx2 + 2] = color2.2
                        rgbaBuffer[bufIdx2 + 3] = 255
                    }
                }
            }
        }

        guard let image = ImageHelpers.createCGImage(from: rgbaBuffer, width: width, height: height) else {
            return (nil, .Unknown)
        }

        return (image, .SHR(mode: "DreamGrafix", width: width, height: height))
    }

    // MARK: - 3200-Color Mode Rendering
    // Layout: 32000 pixels + 6400 per-line palettes (200 lines × 16 colors × 2 bytes)

    private static func render3200Color(data: Data, width: Int, height: Int) -> (image: CGImage?, type: AppleIIImageType) {
        let bytesPerLine = width / 2
        let pixelDataSize = bytesPerLine * height
        let paletteOffset = pixelDataSize

        // Need pixel data + palette data (6400 bytes for 200 lines)
        guard data.count >= paletteOffset + (height * 32) else {
            return (nil, .Unknown)
        }

        // Read per-line palettes (one 16-color palette per scanline)
        var palettes: [[(r: UInt8, g: UInt8, b: UInt8)]] = []
        for line in 0..<height {
            var colors: [(r: UInt8, g: UInt8, b: UInt8)] = []
            for colorIdx in 0..<16 {
                let offset = paletteOffset + (line * 32) + (colorIdx * 2)
                guard offset + 1 < data.count else {
                    colors.append((0, 0, 0))
                    continue
                }
                let low = data[offset]
                let high = data[offset + 1]
                let r = UInt8((high & 0x0F) * 17)
                let g = UInt8(((low >> 4) & 0x0F) * 17)
                let b = UInt8((low & 0x0F) * 17)
                colors.append((r: r, g: g, b: b))
            }
            palettes.append(colors)
        }

        // Render image
        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)

        for y in 0..<height {
            let palette = y < palettes.count ? palettes[y] : palettes[0]

            for xByte in 0..<bytesPerLine {
                let dataIndex = y * bytesPerLine + xByte
                guard dataIndex < data.count else { continue }
                let byte = data[dataIndex]

                let x = xByte * 2

                let colorIndex1 = Int((byte >> 4) & 0x0F)
                let color1 = colorIndex1 < palette.count ? palette[colorIndex1] : (0, 0, 0)

                if x < width {
                    let bufIdx1 = (y * width + x) * 4
                    rgbaBuffer[bufIdx1] = color1.0
                    rgbaBuffer[bufIdx1 + 1] = color1.1
                    rgbaBuffer[bufIdx1 + 2] = color1.2
                    rgbaBuffer[bufIdx1 + 3] = 255
                }

                let colorIndex2 = Int(byte & 0x0F)
                let color2 = colorIndex2 < palette.count ? palette[colorIndex2] : (0, 0, 0)

                if x + 1 < width {
                    let bufIdx2 = (y * width + x + 1) * 4
                    rgbaBuffer[bufIdx2] = color2.0
                    rgbaBuffer[bufIdx2 + 1] = color2.1
                    rgbaBuffer[bufIdx2 + 2] = color2.2
                    rgbaBuffer[bufIdx2 + 3] = 255
                }
            }
        }

        guard let image = ImageHelpers.createCGImage(from: rgbaBuffer, width: width, height: height) else {
            return (nil, .Unknown)
        }

        return (image, .SHR(mode: "DreamGrafix 3200", width: width, height: height))
    }

    // MARK: - Default Palette Rendering

    private static func renderWithDefaultPalette(data: Data, width: Int, height: Int) -> (image: CGImage?, type: AppleIIImageType) {
        let bytesPerLine = width / 2

        let defaultPalette: [(r: UInt8, g: UInt8, b: UInt8)] = [
            (0,0,0), (221,0,51), (0,0,153), (221,34,153),
            (0,119,34), (85,85,85), (34,34,255), (102,170,255),
            (136,85,0), (255,102,0), (170,170,170), (255,153,136),
            (17,221,0), (255,255,0), (68,255,153), (255,255,255)
        ]

        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)

        for y in 0..<height {
            for xByte in 0..<bytesPerLine {
                let dataIndex = y * bytesPerLine + xByte
                guard dataIndex < data.count else { continue }
                let byte = data[dataIndex]

                let x = xByte * 2

                let colorIndex1 = Int((byte >> 4) & 0x0F)
                let color1 = defaultPalette[colorIndex1]

                if x < width {
                    let bufIdx1 = (y * width + x) * 4
                    rgbaBuffer[bufIdx1] = color1.0
                    rgbaBuffer[bufIdx1 + 1] = color1.1
                    rgbaBuffer[bufIdx1 + 2] = color1.2
                    rgbaBuffer[bufIdx1 + 3] = 255
                }

                let colorIndex2 = Int(byte & 0x0F)
                let color2 = defaultPalette[colorIndex2]

                if x + 1 < width {
                    let bufIdx2 = (y * width + x + 1) * 4
                    rgbaBuffer[bufIdx2] = color2.0
                    rgbaBuffer[bufIdx2 + 1] = color2.1
                    rgbaBuffer[bufIdx2 + 2] = color2.2
                    rgbaBuffer[bufIdx2 + 3] = 255
                }
            }
        }

        guard let image = ImageHelpers.createCGImage(from: rgbaBuffer, width: width, height: height) else {
            return (nil, .Unknown)
        }

        return (image, .SHR(mode: "DreamGrafix", width: width, height: height))
    }
}
