import Foundation
import CoreGraphics
import AppKit

// MARK: - Palette Renderer

/// Re-renders images using modified palette colors for live preview
struct PaletteRenderer {

    // MARK: - Main Re-render Function

    /// Re-renders an image using a modified palette
    /// - Parameters:
    ///   - data: Original image data
    ///   - type: The image type
    ///   - palette: Modified palette to use for rendering
    /// - Returns: New NSImage rendered with the modified palette, or nil if not supported
    static func rerenderWithPalette(data: Data, type: AppleIIImageType, palette: PaletteInfo) -> NSImage? {
        var cgImage: CGImage?

        switch type {
        case .SHR(let mode, _, _):
            if mode.contains("3200") {
                cgImage = renderSHR3200(data: data, palettes: palette.palettes, mode: mode)
            } else if mode.contains("Paintworks") {
                cgImage = renderPaintworks(data: data, palette: palette)
            } else if mode.contains("Packed") {
                cgImage = renderPackedSHR(data: data, palette: palette)
            } else {
                cgImage = renderStandardSHR(data: data, palette: palette)
            }

        case .DHGR:
            cgImage = renderDHGR(data: data, palette: palette)

        case .HGR:
            cgImage = renderHGR(data: data, palette: palette)

        case .C64:
            cgImage = renderC64(data: data, palette: palette)

        case .IFF(_, _, _):
            cgImage = renderIFF(data: data, palette: palette)

        case .DEGAS(_, _):
            cgImage = renderDegas(data: data, palette: palette)

        case .PCX(_, _, let bpp):
            if bpp <= 8 {
                cgImage = renderPCX(data: data, palette: palette, bitsPerPixel: bpp)
            }

        case .BMP(_, _, let bpp):
            if bpp <= 8 {
                cgImage = renderBMP(data: data, palette: palette, bitsPerPixel: bpp)
            }

        case .ZXSpectrum:
            cgImage = renderZXSpectrum(data: data, palette: palette)

        case .MacPaint:
            cgImage = renderMacPaint(data: data, palette: palette)

        case .MSX(let mode, _):
            cgImage = renderMSX(data: data, palette: palette, mode: mode)

        default:
            return nil
        }

        if let cgImage = cgImage {
            return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
        }
        return nil
    }

    // MARK: - SHR Standard Renderer

    private static func renderStandardSHR(data: Data, palette: PaletteInfo) -> CGImage? {
        let width = 320
        let height = 200
        var rgbaBuffer = [UInt8](repeating: 255, count: width * height * 4)

        let pixelDataStart = 0
        let scbOffset = 32000

        guard data.count >= 32000 else { return nil }

        // Convert PaletteInfo palettes to the tuple format used by renderer
        let palettes: [[(r: UInt8, g: UInt8, b: UInt8)]] = palette.palettes.map { paletteColors in
            paletteColors.map { ($0.r, $0.g, $0.b) }
        }

        // Ensure we have at least one palette
        guard !palettes.isEmpty else { return nil }

        for y in 0..<height {
            let scb: UInt8
            if scbOffset + y < data.count {
                scb = data[scbOffset + y]
            } else {
                scb = 0
            }
            let paletteIndex = Int(scb & 0x0F)
            let currentPalette = paletteIndex < palettes.count ? palettes[paletteIndex] : palettes[0]
            renderSHRLine(y: y, data: data, pixelStart: pixelDataStart, palette: currentPalette, to: &rgbaBuffer, width: width)
        }

        return ImageHelpers.createCGImage(from: rgbaBuffer, width: width, height: height)
    }

    // MARK: - SHR 3200 Color Renderer

    private static func renderSHR3200(data: Data, palettes: [[PaletteColor]], mode: String) -> CGImage? {
        let width = 320
        let height = 200
        var rgbaBuffer = [UInt8](repeating: 255, count: width * height * 4)

        guard palettes.count >= 200 else { return nil }

        // Get pixel data based on format
        let pixelData: Data

        if mode.contains("Packed") || mode.contains("3201") {
            // 3201 format: header (4) + palettes (6400) + compressed pixels
            // Need to decompress PackBytes data
            guard data.count > 6404 else { return nil }
            let compressedData = data.subdata(in: 6404..<data.count)
            let decompressed = PackedSHRDecoder.unpackBytes(data: compressedData, maxOutputSize: 32000)
            guard decompressed.count >= 32000 else { return nil }
            pixelData = Data(decompressed)
        } else if mode.contains("DreamGrafix") {
            // DreamGrafix: LZW compressed, pixels at start of decompressed data
            guard data.count >= 17 else { return nil }
            let compressedData = data.subdata(in: 0..<(data.count - 17))
            if let decompressed = decompressDreamGrafixLZW(data: compressedData), decompressed.count >= 32000 {
                pixelData = decompressed.subdata(in: 0..<32000)
            } else if data.count >= 32000 {
                // Try using raw data if decompression fails
                pixelData = data.subdata(in: 0..<32000)
            } else {
                return nil
            }
        } else {
            // Standard 3200 format: pixel data at offset 0
            guard data.count >= 32000 else { return nil }
            pixelData = data.subdata(in: 0..<32000)
        }

        for y in 0..<height {
            let currentPalette: [(r: UInt8, g: UInt8, b: UInt8)] = palettes[y].map { ($0.r, $0.g, $0.b) }
            renderSHRLineFromData(y: y, pixelData: pixelData, palette: currentPalette, to: &rgbaBuffer, width: width)
        }

        return ImageHelpers.createCGImage(from: rgbaBuffer, width: width, height: height)
    }

    private static func renderSHRLineFromData(y: Int, pixelData: Data, palette: [(r: UInt8, g: UInt8, b: UInt8)], to buffer: inout [UInt8], width: Int) {
        let bytesPerLine = 160
        let lineStart = y * bytesPerLine

        guard lineStart + bytesPerLine <= pixelData.count else { return }

        for xByte in 0..<bytesPerLine {
            let byte = pixelData[lineStart + xByte]

            let idx1 = Int((byte & 0xF0) >> 4)
            let idx2 = Int(byte & 0x0F)

            let c1 = idx1 < palette.count ? palette[idx1] : (r: UInt8(0), g: UInt8(0), b: UInt8(0))
            let bufferIdx1 = (y * width + (xByte * 2)) * 4
            buffer[bufferIdx1]     = c1.r
            buffer[bufferIdx1 + 1] = c1.g
            buffer[bufferIdx1 + 2] = c1.b
            buffer[bufferIdx1 + 3] = 255

            let c2 = idx2 < palette.count ? palette[idx2] : (r: UInt8(0), g: UInt8(0), b: UInt8(0))
            let bufferIdx2 = (y * width + (xByte * 2) + 1) * 4
            buffer[bufferIdx2]     = c2.r
            buffer[bufferIdx2 + 1] = c2.g
            buffer[bufferIdx2 + 2] = c2.b
            buffer[bufferIdx2 + 3] = 255
        }
    }

    // DreamGrafix LZW decompression (GIF-style variable width 9-12 bits)
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

    private static func renderSHRLine(y: Int, data: Data, pixelStart: Int, palette: [(r: UInt8, g: UInt8, b: UInt8)], to buffer: inout [UInt8], width: Int) {
        let bytesPerLine = 160
        let lineStart = pixelStart + (y * bytesPerLine)

        guard lineStart + bytesPerLine <= data.count else { return }

        for xByte in 0..<bytesPerLine {
            let byte = data[lineStart + xByte]

            let idx1 = Int((byte & 0xF0) >> 4)
            let idx2 = Int(byte & 0x0F)

            let c1 = idx1 < palette.count ? palette[idx1] : (r: UInt8(0), g: UInt8(0), b: UInt8(0))
            let bufferIdx1 = (y * width + (xByte * 2)) * 4
            buffer[bufferIdx1]     = c1.r
            buffer[bufferIdx1 + 1] = c1.g
            buffer[bufferIdx1 + 2] = c1.b
            buffer[bufferIdx1 + 3] = 255

            let c2 = idx2 < palette.count ? palette[idx2] : (r: UInt8(0), g: UInt8(0), b: UInt8(0))
            let bufferIdx2 = (y * width + (xByte * 2) + 1) * 4
            buffer[bufferIdx2]     = c2.r
            buffer[bufferIdx2 + 1] = c2.g
            buffer[bufferIdx2 + 2] = c2.b
            buffer[bufferIdx2 + 3] = 255
        }
    }

    // MARK: - DHGR Renderer

    private static func renderDHGR(data: Data, palette: PaletteInfo) -> CGImage? {
        let width = 560
        let height = 192
        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)

        guard data.count >= 16384 else { return nil }
        let primaryPalette = palette.primaryPalette
        guard primaryPalette.count >= 16 else { return nil }

        let dhgrPalette: [(r: UInt8, g: UInt8, b: UInt8)] = primaryPalette.map { ($0.r, $0.g, $0.b) }

        let mainData = data.subdata(in: 0..<8192)
        let auxData = data.subdata(in: 8192..<16384)

        for y in 0..<height {
            let base = (y & 0x07) << 10
            let row = (y >> 3) & 0x07
            let block = (y >> 6) & 0x03
            let offset = base | (row << 7) | (block * 40)

            guard offset + 40 <= 8192 else { continue }

            var bits: [UInt8] = []
            for xByte in 0..<40 {
                let mainByte = mainData[offset + xByte]
                let auxByte = auxData[offset + xByte]

                for bitPos in 0..<7 {
                    bits.append((mainByte >> bitPos) & 0x1)
                }
                for bitPos in 0..<7 {
                    bits.append((auxByte >> bitPos) & 0x1)
                }
            }

            var pixelX = 0
            var bitIndex = 0

            while bitIndex + 3 < bits.count && pixelX < width {
                let bit0 = bits[bitIndex]
                let bit1 = bits[bitIndex + 1]
                let bit2 = bits[bitIndex + 2]
                let bit3 = bits[bitIndex + 3]

                let colorIndex = Int(bit0 | (bit1 << 1) | (bit2 << 2) | (bit3 << 3))
                let color = colorIndex < dhgrPalette.count ? dhgrPalette[colorIndex] : (r: UInt8(0), g: UInt8(0), b: UInt8(0))

                // Write 4 pixels per color (same as original decoder)
                for _ in 0..<4 {
                    let bufferIdx = (y * width + pixelX) * 4
                    if bufferIdx + 3 < rgbaBuffer.count && pixelX < width {
                        rgbaBuffer[bufferIdx]     = color.r
                        rgbaBuffer[bufferIdx + 1] = color.g
                        rgbaBuffer[bufferIdx + 2] = color.b
                        rgbaBuffer[bufferIdx + 3] = 255
                    }
                    pixelX += 1
                }

                bitIndex += 4
            }
        }

        // Create the 560-wide image, then scale down to 280 (matching original decoder)
        guard let fullImage = ImageHelpers.createCGImage(from: rgbaBuffer, width: width, height: height) else {
            return nil
        }

        return SHRDecoder.scaleCGImage(fullImage, to: CGSize(width: 280, height: 192))
    }

    // MARK: - HGR Renderer

    private static func renderHGR(data: Data, palette: PaletteInfo) -> CGImage? {
        let width = 280
        let height = 192
        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)

        guard data.count >= 8184 else { return nil }

        let primaryPalette = palette.primaryPalette
        guard primaryPalette.count >= 6 else { return nil }

        // HGR palette order: Black, White, Green, Violet, Orange, Blue
        let hgrPalette: [(r: UInt8, g: UInt8, b: UInt8)] = primaryPalette.prefix(6).map { ($0.r, $0.g, $0.b) }

        for y in 0..<height {
            let i = y % 8
            let j = (y / 8) % 8
            let k = y / 64

            let fileOffset = (i * 1024) + (j * 128) + (k * 40)

            guard fileOffset + 40 <= data.count else { continue }

            for xByte in 0..<40 {
                let currentByte = data[fileOffset + xByte]
                let nextByte: UInt8 = (xByte + 1 < 40) ? data[fileOffset + xByte + 1] : 0

                let highBit = (currentByte >> 7) & 0x1

                for bitIndex in 0..<7 {
                    let pixelIndex = (xByte * 7) + bitIndex
                    let bufferIdx = (y * width + pixelIndex) * 4

                    let bitA = (currentByte >> bitIndex) & 0x1

                    let bitB: UInt8
                    if bitIndex == 6 {
                        bitB = (nextByte >> 0) & 0x1
                    } else {
                        bitB = (currentByte >> (bitIndex + 1)) & 0x1
                    }

                    var colorIndex = 0

                    if bitA == 0 && bitB == 0 {
                        colorIndex = 0  // Black
                    } else if bitA == 1 && bitB == 1 {
                        colorIndex = 1  // White
                    } else {
                        let isEvenColumn = (pixelIndex % 2) == 0

                        if highBit == 1 {
                            if isEvenColumn {
                                colorIndex = (bitA == 1) ? 5 : 4  // Blue or Orange
                            } else {
                                colorIndex = (bitA == 1) ? 4 : 5  // Orange or Blue
                            }
                        } else {
                            if isEvenColumn {
                                colorIndex = (bitA == 1) ? 3 : 2  // Violet or Green
                            } else {
                                colorIndex = (bitA == 1) ? 2 : 3  // Green or Violet
                            }
                        }
                    }

                    let c = colorIndex < hgrPalette.count ? hgrPalette[colorIndex] : (r: UInt8(0), g: UInt8(0), b: UInt8(0))
                    rgbaBuffer[bufferIdx] = c.r
                    rgbaBuffer[bufferIdx + 1] = c.g
                    rgbaBuffer[bufferIdx + 2] = c.b
                    rgbaBuffer[bufferIdx + 3] = 255
                }
            }
        }

        return ImageHelpers.createCGImage(from: rgbaBuffer, width: width, height: height)
    }

    // MARK: - IFF Renderer

    private static func renderIFF(data: Data, palette: PaletteInfo) -> CGImage? {
        guard data.count >= 12 else { return nil }

        // Parse IFF structure
        guard let formHeader = String(data: data.subdata(in: 0..<4), encoding: .ascii),
              formHeader == "FORM",
              let ilbmType = String(data: data.subdata(in: 8..<12), encoding: .ascii),
              ilbmType == "ILBM" else {
            return nil
        }

        var offset = 12
        var width = 0
        var height = 0
        var numPlanes = 0
        var compression: UInt8 = 0
        var bodyOffset = 0
        var bodySize = 0

        // Parse chunks
        while offset + 8 <= data.count {
            guard let chunkID = String(data: data.subdata(in: offset..<offset+4), encoding: .ascii) else {
                break
            }

            let chunkSize = Int(ImageHelpers.readBigEndianUInt32(data: data, offset: offset + 4))
            offset += 8

            if offset + chunkSize > data.count {
                break
            }

            switch chunkID {
            case "BMHD":
                if chunkSize >= 20 {
                    width = Int(ImageHelpers.readBigEndianUInt16(data: data, offset: offset))
                    height = Int(ImageHelpers.readBigEndianUInt16(data: data, offset: offset + 2))
                    numPlanes = Int(data[offset + 8])
                    compression = data[offset + 10]
                }
            case "BODY":
                bodyOffset = offset
                bodySize = chunkSize
            default:
                break
            }

            offset += chunkSize
            if chunkSize % 2 == 1 {
                offset += 1
            }
        }

        guard width > 0, height > 0, numPlanes > 0, numPlanes <= 8, bodyOffset > 0 else {
            return nil
        }

        let primaryPalette = palette.primaryPalette
        guard !primaryPalette.isEmpty else { return nil }

        let iffPalette: [(r: UInt8, g: UInt8, b: UInt8)] = primaryPalette.map { ($0.r, $0.g, $0.b) }

        let bytesPerRow = ((width + 15) / 16) * 2
        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)

        var srcOffset = bodyOffset

        for y in 0..<height {
            var planeBits: [[UInt8]] = Array(repeating: [], count: numPlanes)

            for plane in 0..<numPlanes {
                var rowData: [UInt8] = []

                if compression == 1 {
                    // PackBits decompression
                    var bytesRead = 0
                    while bytesRead < bytesPerRow && srcOffset < bodyOffset + bodySize {
                        let cmd = Int8(bitPattern: data[srcOffset])
                        srcOffset += 1

                        if cmd >= 0 {
                            let count = Int(cmd) + 1
                            for _ in 0..<count {
                                if srcOffset < bodyOffset + bodySize && bytesRead < bytesPerRow {
                                    rowData.append(data[srcOffset])
                                    srcOffset += 1
                                    bytesRead += 1
                                }
                            }
                        } else if cmd != -128 {
                            let count = Int(-cmd) + 1
                            if srcOffset < bodyOffset + bodySize {
                                let repeatByte = data[srcOffset]
                                srcOffset += 1
                                for _ in 0..<count {
                                    if bytesRead < bytesPerRow {
                                        rowData.append(repeatByte)
                                        bytesRead += 1
                                    }
                                }
                            }
                        }
                    }
                } else {
                    // Uncompressed
                    for _ in 0..<bytesPerRow {
                        if srcOffset < bodyOffset + bodySize {
                            rowData.append(data[srcOffset])
                            srcOffset += 1
                        }
                    }
                }

                planeBits[plane] = rowData
            }

            // Extract pixels from bitplanes
            for x in 0..<width {
                let byteIndex = x / 8
                let bitIndex = 7 - (x % 8)

                var colorIndex = 0
                for plane in 0..<numPlanes {
                    if byteIndex < planeBits[plane].count {
                        let bit = (planeBits[plane][byteIndex] >> bitIndex) & 1
                        colorIndex |= Int(bit) << plane
                    }
                }

                let color = colorIndex < iffPalette.count ? iffPalette[colorIndex] : (r: UInt8(0), g: UInt8(0), b: UInt8(0))
                let bufferIdx = (y * width + x) * 4

                rgbaBuffer[bufferIdx] = color.r
                rgbaBuffer[bufferIdx + 1] = color.g
                rgbaBuffer[bufferIdx + 2] = color.b
                rgbaBuffer[bufferIdx + 3] = 255
            }
        }

        return ImageHelpers.createCGImage(from: rgbaBuffer, width: width, height: height)
    }

    // MARK: - Degas Renderer

    private static func renderDegas(data: Data, palette: PaletteInfo) -> CGImage? {
        guard data.count >= 34 else { return nil }
        let primaryPalette = palette.primaryPalette
        guard !primaryPalette.isEmpty else { return nil }

        let resolutionWord = ImageHelpers.readBigEndianUInt16(data: data, offset: 0)

        let width: Int
        let height: Int
        let numPlanes: Int

        switch resolutionWord {
        case 0:  // Low resolution
            width = 320
            height = 200
            numPlanes = 4
        case 1:  // Medium resolution
            width = 640
            height = 200
            numPlanes = 2
        case 2:  // High resolution
            width = 640
            height = 400
            numPlanes = 1
        default:
            return nil
        }

        let degasPalette: [(r: UInt8, g: UInt8, b: UInt8)] = primaryPalette.map { ($0.r, $0.g, $0.b) }

        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)
        let imageDataOffset = 34

        // Degas uses interleaved bitplanes within each 16-pixel word group
        let wordsPerLine = width / 16
        let bytesPerLine = wordsPerLine * numPlanes * 2

        for y in 0..<height {
            let lineOffset = imageDataOffset + (y * bytesPerLine)

            for wordIdx in 0..<wordsPerLine {
                // Read plane words for this 16-pixel group (interleaved)
                var planeWords: [UInt16] = []
                for plane in 0..<numPlanes {
                    let offset = lineOffset + (wordIdx * numPlanes * 2) + (plane * 2)
                    if offset + 1 < data.count {
                        planeWords.append(ImageHelpers.readBigEndianUInt16(data: data, offset: offset))
                    } else {
                        planeWords.append(0)
                    }
                }

                // Extract 16 pixels from the plane words
                for bit in 0..<16 {
                    let x = wordIdx * 16 + bit
                    if x >= width { break }

                    let bitPos = 15 - bit
                    var colorIndex = 0

                    for plane in 0..<numPlanes {
                        let bitVal = (planeWords[plane] >> bitPos) & 1
                        colorIndex |= Int(bitVal) << plane
                    }

                    let color = colorIndex < degasPalette.count ? degasPalette[colorIndex] : (r: UInt8(0), g: UInt8(0), b: UInt8(0))
                    let bufferIdx = (y * width + x) * 4

                    rgbaBuffer[bufferIdx] = color.r
                    rgbaBuffer[bufferIdx + 1] = color.g
                    rgbaBuffer[bufferIdx + 2] = color.b
                    rgbaBuffer[bufferIdx + 3] = 255
                }
            }
        }

        return ImageHelpers.createCGImage(from: rgbaBuffer, width: width, height: height)
    }

    // MARK: - PCX Renderer

    private static func renderPCX(data: Data, palette: PaletteInfo, bitsPerPixel: Int) -> CGImage? {
        guard data.count >= 128, data[0] == 0x0A else { return nil }

        let headerBitsPerPixel = Int(data[3])
        let xMin = Int(data[4]) | (Int(data[5]) << 8)
        let yMin = Int(data[6]) | (Int(data[7]) << 8)
        let xMax = Int(data[8]) | (Int(data[9]) << 8)
        let yMax = Int(data[10]) | (Int(data[11]) << 8)
        let width = xMax - xMin + 1
        let height = yMax - yMin + 1
        let numPlanes = Int(data[65])
        let bytesPerLine = Int(data[66]) | (Int(data[67]) << 8)

        guard width > 0, height > 0, width < 10000, height < 10000 else { return nil }

        // Detect CGA header mismatch (header says 1bpp but bytesPerLine indicates 2bpp)
        let calculatedBitsPerPixel = width > 0 ? (bytesPerLine * 8) / width : headerBitsPerPixel
        let isCGA4Color = headerBitsPerPixel == 1 && numPlanes == 1 && calculatedBitsPerPixel == 2

        let primaryPalette = palette.primaryPalette
        guard !primaryPalette.isEmpty else { return nil }

        let pcxPalette: [(r: UInt8, g: UInt8, b: UInt8)] = primaryPalette.map { ($0.r, $0.g, $0.b) }

        // Decompress RLE data
        var decompressedData: [UInt8] = []
        var offset = 128
        let scanlineSize = bytesPerLine * numPlanes
        let expectedSize = scanlineSize * height

        while offset < data.count && decompressedData.count < expectedSize {
            let byte = data[offset]
            offset += 1
            if (byte & 0xC0) == 0xC0 {
                let count = Int(byte & 0x3F)
                if offset < data.count {
                    let value = data[offset]
                    offset += 1
                    for _ in 0..<count {
                        decompressedData.append(value)
                    }
                }
            } else {
                decompressedData.append(byte)
            }
        }

        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)

        // VGA 256-color mode (8bpp, 1 plane)
        if headerBitsPerPixel == 8 && numPlanes == 1 {
            for y in 0..<height {
                for x in 0..<width {
                    let dataIndex = y * bytesPerLine + x
                    let paletteIndex = dataIndex < decompressedData.count ? min(Int(decompressedData[dataIndex]), pcxPalette.count - 1) : 0
                    let color = pcxPalette[paletteIndex]
                    let bufferIdx = (y * width + x) * 4
                    rgbaBuffer[bufferIdx] = color.r
                    rgbaBuffer[bufferIdx + 1] = color.g
                    rgbaBuffer[bufferIdx + 2] = color.b
                    rgbaBuffer[bufferIdx + 3] = 255
                }
            }
        }
        // EGA 16-color planar (1bpp, 4 planes)
        else if headerBitsPerPixel == 1 && numPlanes == 4 {
            for y in 0..<height {
                let rowOffset = y * scanlineSize
                for x in 0..<width {
                    let byteIndex = x / 8
                    let bitIndex = 7 - (x % 8)

                    var colorIndex = 0
                    for plane in 0..<4 {
                        let planeOffset = rowOffset + plane * bytesPerLine + byteIndex
                        if planeOffset < decompressedData.count {
                            let bit = (decompressedData[planeOffset] >> bitIndex) & 1
                            colorIndex |= Int(bit) << plane
                        }
                    }

                    let color = pcxPalette[min(colorIndex, pcxPalette.count - 1)]
                    let bufferIdx = (y * width + x) * 4
                    rgbaBuffer[bufferIdx] = color.r
                    rgbaBuffer[bufferIdx + 1] = color.g
                    rgbaBuffer[bufferIdx + 2] = color.b
                    rgbaBuffer[bufferIdx + 3] = 255
                }
            }
        }
        // EGA 64-color planar (2bpp, 4 planes)
        else if headerBitsPerPixel == 2 && numPlanes == 4 {
            for y in 0..<height {
                let rowOffset = y * scanlineSize
                for x in 0..<width {
                    let byteIndex = x / 4
                    let pixelInByte = 3 - (x % 4)
                    let shift = pixelInByte * 2

                    var colorIndex = 0
                    for plane in 0..<4 {
                        let planeOffset = rowOffset + plane * bytesPerLine + byteIndex
                        if planeOffset < decompressedData.count {
                            let bits = (decompressedData[planeOffset] >> shift) & 0x03
                            colorIndex |= Int(bits) << (plane * 2)
                        }
                    }

                    let color = pcxPalette[min(colorIndex, pcxPalette.count - 1)]
                    let bufferIdx = (y * width + x) * 4
                    rgbaBuffer[bufferIdx] = color.r
                    rgbaBuffer[bufferIdx + 1] = color.g
                    rgbaBuffer[bufferIdx + 2] = color.b
                    rgbaBuffer[bufferIdx + 3] = 255
                }
            }
        }
        // CGA 4-color (2bpp, 1 plane) - including header mismatch detection
        else if isCGA4Color || (headerBitsPerPixel == 2 && numPlanes == 1) {
            for y in 0..<height {
                for x in 0..<width {
                    let byteIndex = y * bytesPerLine + (x / 4)
                    let pixelInByte = 3 - (x % 4)
                    if byteIndex < decompressedData.count {
                        let colorIndex = Int((decompressedData[byteIndex] >> (pixelInByte * 2)) & 0x03)
                        let color = pcxPalette[min(colorIndex, pcxPalette.count - 1)]
                        let bufferIdx = (y * width + x) * 4
                        rgbaBuffer[bufferIdx] = color.r
                        rgbaBuffer[bufferIdx + 1] = color.g
                        rgbaBuffer[bufferIdx + 2] = color.b
                        rgbaBuffer[bufferIdx + 3] = 255
                    }
                }
            }
        }
        // Monochrome (1bpp, 1 plane)
        else if headerBitsPerPixel == 1 && numPlanes == 1 {
            for y in 0..<height {
                for x in 0..<width {
                    let byteIndex = y * bytesPerLine + (x / 8)
                    let bitIndex = 7 - (x % 8)
                    if byteIndex < decompressedData.count {
                        let bit = Int((decompressedData[byteIndex] >> bitIndex) & 1)
                        let color = pcxPalette[min(bit, pcxPalette.count - 1)]
                        let bufferIdx = (y * width + x) * 4
                        rgbaBuffer[bufferIdx] = color.r
                        rgbaBuffer[bufferIdx + 1] = color.g
                        rgbaBuffer[bufferIdx + 2] = color.b
                        rgbaBuffer[bufferIdx + 3] = 255
                    }
                }
            }
        }
        // 4-bit single plane (16 colors, 2 pixels per byte)
        else if headerBitsPerPixel == 4 && numPlanes == 1 {
            for y in 0..<height {
                for x in 0..<width {
                    let byteIndex = y * bytesPerLine + (x / 2)
                    if byteIndex < decompressedData.count {
                        let colorIndex: Int
                        if x % 2 == 0 {
                            colorIndex = Int(decompressedData[byteIndex] >> 4)
                        } else {
                            colorIndex = Int(decompressedData[byteIndex] & 0x0F)
                        }
                        let color = pcxPalette[min(colorIndex, pcxPalette.count - 1)]
                        let bufferIdx = (y * width + x) * 4
                        rgbaBuffer[bufferIdx] = color.r
                        rgbaBuffer[bufferIdx + 1] = color.g
                        rgbaBuffer[bufferIdx + 2] = color.b
                        rgbaBuffer[bufferIdx + 3] = 255
                    }
                }
            }
        }

        return ImageHelpers.createCGImage(from: rgbaBuffer, width: width, height: height)
    }

    // MARK: - BMP Renderer

    private static func renderBMP(data: Data, palette: PaletteInfo, bitsPerPixel: Int) -> CGImage? {
        guard data.count >= 54, data[0] == 0x42, data[1] == 0x4D else { return nil }

        let width = Int(data[18]) | (Int(data[19]) << 8) | (Int(data[20]) << 16) | (Int(data[21]) << 24)
        var height = Int(data[22]) | (Int(data[23]) << 8) | (Int(data[24]) << 16) | (Int(data[25]) << 24)
        let topDown = height < 0
        if topDown { height = -height }

        let pixelDataOffset = Int(data[10]) | (Int(data[11]) << 8) | (Int(data[12]) << 16) | (Int(data[13]) << 24)

        guard width > 0, height > 0, width < 10000, height < 10000 else { return nil }

        let primaryPalette = palette.primaryPalette
        guard !primaryPalette.isEmpty else { return nil }

        let bmpPalette: [(r: UInt8, g: UInt8, b: UInt8)] = primaryPalette.map { ($0.r, $0.g, $0.b) }

        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)
        let rowSize = ((bitsPerPixel * width + 31) / 32) * 4

        for y in 0..<height {
            let actualY = topDown ? y : (height - 1 - y)
            let rowOffset = pixelDataOffset + (y * rowSize)

            for x in 0..<width {
                var colorIndex = 0

                switch bitsPerPixel {
                case 8:
                    let pixelOffset = rowOffset + x
                    if pixelOffset < data.count {
                        colorIndex = Int(data[pixelOffset])
                    }
                case 4:
                    let byteOffset = rowOffset + (x / 2)
                    if byteOffset < data.count {
                        colorIndex = (x % 2 == 0) ? Int(data[byteOffset] >> 4) : Int(data[byteOffset] & 0x0F)
                    }
                case 1:
                    let byteOffset = rowOffset + (x / 8)
                    if byteOffset < data.count {
                        colorIndex = Int((data[byteOffset] >> (7 - (x % 8))) & 1)
                    }
                default:
                    break
                }

                let color = colorIndex < bmpPalette.count ? bmpPalette[colorIndex] : (r: UInt8(0), g: UInt8(0), b: UInt8(0))
                let bufferIdx = (actualY * width + x) * 4
                rgbaBuffer[bufferIdx] = color.r
                rgbaBuffer[bufferIdx + 1] = color.g
                rgbaBuffer[bufferIdx + 2] = color.b
                rgbaBuffer[bufferIdx + 3] = 255
            }
        }

        return ImageHelpers.createCGImage(from: rgbaBuffer, width: width, height: height)
    }

    // MARK: - ZX Spectrum Renderer

    private static func renderZXSpectrum(data: Data, palette: PaletteInfo) -> CGImage? {
        guard data.count == 6912 else { return nil }

        let primaryPalette = palette.primaryPalette
        guard primaryPalette.count >= 16 else { return nil }

        let zxPalette: [(r: UInt8, g: UInt8, b: UInt8)] = primaryPalette.map { ($0.r, $0.g, $0.b) }

        let width = 256
        let height = 192
        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)

        for y in 0..<height {
            // ZX Spectrum screen memory layout
            let third = y / 64
            let lineInThird = y % 64
            let octave = lineInThird / 8
            let lineInOctave = lineInThird % 8
            let bitmapLineOffset = (third * 2048) + (lineInOctave * 256) + (octave * 32)
            let attrY = y / 8

            for x in 0..<width {
                let xByte = x / 8
                let xBit = 7 - (x % 8)
                let bitmapByte = data[bitmapLineOffset + xByte]
                let pixelBit = (bitmapByte >> xBit) & 1

                let attrByte = data[6144 + (attrY * 32) + xByte]
                let bright = (attrByte >> 6) & 1
                let paper = (attrByte >> 3) & 0x07
                let ink = attrByte & 0x07

                // Color index: ink (0-7) or paper (0-7), +8 if bright
                let colorIndex = (pixelBit == 1) ? Int(ink) + (bright == 1 ? 8 : 0) : Int(paper) + (bright == 1 ? 8 : 0)
                let color = colorIndex < zxPalette.count ? zxPalette[colorIndex] : (r: UInt8(0), g: UInt8(0), b: UInt8(0))

                let bufferIdx = (y * width + x) * 4
                rgbaBuffer[bufferIdx] = color.r
                rgbaBuffer[bufferIdx + 1] = color.g
                rgbaBuffer[bufferIdx + 2] = color.b
                rgbaBuffer[bufferIdx + 3] = 255
            }
        }

        return ImageHelpers.createCGImage(from: rgbaBuffer, width: width, height: height)
    }

    // MARK: - C64 Renderer

    private static func renderC64(data: Data, palette: PaletteInfo) -> CGImage? {
        // Support Koala format (10003-10010 bytes) and Art Studio (10018 bytes)
        let isKoala = data.count >= 10003 && data.count <= 10010
        let isArtStudio = data.count == 10018

        guard isKoala || isArtStudio else { return nil }

        let primaryPalette = palette.primaryPalette
        guard primaryPalette.count >= 16 else { return nil }

        let c64Palette: [(r: UInt8, g: UInt8, b: UInt8)] = primaryPalette.map { ($0.r, $0.g, $0.b) }

        let width = 320
        let height = 200
        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)

        let bitmapOffset = 2
        let screenRAMOffset = 8002
        let colorRAMOffset = 9002
        let backgroundOffset = 10002

        guard backgroundOffset < data.count else { return nil }
        let backgroundColor = Int(data[backgroundOffset] & 0x0F)

        for cellY in 0..<25 {
            for cellX in 0..<40 {
                let cellIndex = cellY * 40 + cellX

                guard screenRAMOffset + cellIndex < data.count,
                      colorRAMOffset + cellIndex < data.count else { continue }

                let screenByte = data[screenRAMOffset + cellIndex]
                let colorByte = data[colorRAMOffset + cellIndex]

                let color0 = backgroundColor
                let color1 = Int((screenByte >> 4) & 0x0F)
                let color2 = Int(screenByte & 0x0F)
                let color3 = Int(colorByte & 0x0F)

                let colors = [color0, color1, color2, color3]

                for row in 0..<8 {
                    let bitmapByteOffset = bitmapOffset + (cellIndex * 8) + row
                    guard bitmapByteOffset < data.count else { continue }

                    let bitmapByte = data[bitmapByteOffset]
                    let y = cellY * 8 + row

                    for pixelPair in 0..<4 {
                        let x = cellX * 8 + (pixelPair * 2)
                        let bitShift = 6 - (pixelPair * 2)
                        let colorIndex = Int((bitmapByte >> bitShift) & 0x03)

                        let c64Color = colors[colorIndex]
                        let rgb = c64Color < c64Palette.count ? c64Palette[c64Color] : (r: UInt8(0), g: UInt8(0), b: UInt8(0))

                        for dx in 0..<2 {
                            let bufferIdx = (y * width + x + dx) * 4
                            if bufferIdx + 3 < rgbaBuffer.count {
                                rgbaBuffer[bufferIdx] = rgb.r
                                rgbaBuffer[bufferIdx + 1] = rgb.g
                                rgbaBuffer[bufferIdx + 2] = rgb.b
                                rgbaBuffer[bufferIdx + 3] = 255
                            }
                        }
                    }
                }
            }
        }

        return ImageHelpers.createCGImage(from: rgbaBuffer, width: width, height: height)
    }

    // MARK: - MacPaint Renderer

    private static func renderMacPaint(data: Data, palette: PaletteInfo) -> CGImage? {
        let width = 576
        let height = 720
        let bytesPerRow = 72  // 576 pixels / 8 bits per byte

        let primaryPalette = palette.primaryPalette
        guard primaryPalette.count >= 2 else { return nil }

        // MacPaint palette: index 0 = background (white), index 1 = foreground (black)
        let color0 = (r: primaryPalette[0].r, g: primaryPalette[0].g, b: primaryPalette[0].b)
        let color1 = (r: primaryPalette[1].r, g: primaryPalette[1].g, b: primaryPalette[1].b)

        var rgbaBuffer = [UInt8](repeating: 255, count: width * height * 4)

        // Skip 512-byte header
        let headerSize = 512
        guard data.count > headerSize else { return nil }

        // Decompress PackBits data
        var decompressedData: [UInt8] = []
        let expectedSize = bytesPerRow * height  // 51,840 bytes
        var offset = headerSize

        while offset < data.count && decompressedData.count < expectedSize {
            let cmd = Int8(bitPattern: data[offset])
            offset += 1

            if cmd >= 0 {
                // Literal run: copy next (cmd + 1) bytes
                let count = Int(cmd) + 1
                for _ in 0..<count {
                    if offset < data.count && decompressedData.count < expectedSize {
                        decompressedData.append(data[offset])
                        offset += 1
                    }
                }
            } else if cmd != -128 {
                // Repeat run: repeat next byte (-cmd + 1) times
                let count = Int(-cmd) + 1
                if offset < data.count {
                    let repeatByte = data[offset]
                    offset += 1
                    for _ in 0..<count {
                        if decompressedData.count < expectedSize {
                            decompressedData.append(repeatByte)
                        }
                    }
                }
            }
            // cmd == -128 is a no-op
        }

        // Render the 1-bit image
        for y in 0..<height {
            for x in 0..<width {
                let byteIndex = y * bytesPerRow + (x / 8)
                let bitIndex = 7 - (x % 8)  // MSB first

                let bufferIdx = (y * width + x) * 4

                if byteIndex < decompressedData.count {
                    let bit = (decompressedData[byteIndex] >> bitIndex) & 1
                    // bit 0 = white (palette[0]), bit 1 = black (palette[1])
                    let color = bit == 0 ? color0 : color1
                    rgbaBuffer[bufferIdx] = color.r
                    rgbaBuffer[bufferIdx + 1] = color.g
                    rgbaBuffer[bufferIdx + 2] = color.b
                } else {
                    // Default to white if data runs out
                    rgbaBuffer[bufferIdx] = color0.r
                    rgbaBuffer[bufferIdx + 1] = color0.g
                    rgbaBuffer[bufferIdx + 2] = color0.b
                }
                rgbaBuffer[bufferIdx + 3] = 255
            }
        }

        return ImageHelpers.createCGImage(from: rgbaBuffer, width: width, height: height)
    }

    // MARK: - MSX Renderer

    private static func renderMSX(data: Data, palette: PaletteInfo, mode: Int) -> CGImage? {
        switch mode {
        case 5:
            return renderMSXScreen5(data: data, palette: palette)
        case 8:
            return renderMSXScreen8(data: data, palette: palette)
        default:
            // For other modes (1, 2), use Screen 2 renderer as fallback
            return renderMSXScreen2(data: data, palette: palette)
        }
    }

    private static func renderMSXScreen5(data: Data, palette: PaletteInfo) -> CGImage? {
        let width = 256
        let height = 212

        var offset = 0

        // Check for BSAVE header
        if data.count >= 7 && data[0] == 0xFE {
            offset = 7
        }

        let dataSize = data.count - offset
        guard dataSize >= 27136 else { return nil }

        let primaryPalette = palette.primaryPalette
        guard primaryPalette.count >= 16 else { return nil }

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
                let color1 = pixel1 < primaryPalette.count ? primaryPalette[pixel1] : primaryPalette[0]
                rgbaBuffer[bufferIdx1] = color1.r
                rgbaBuffer[bufferIdx1 + 1] = color1.g
                rgbaBuffer[bufferIdx1 + 2] = color1.b
                rgbaBuffer[bufferIdx1 + 3] = 255

                // Second pixel
                let bufferIdx2 = (y * width + x * 2 + 1) * 4
                let color2 = pixel2 < primaryPalette.count ? primaryPalette[pixel2] : primaryPalette[0]
                rgbaBuffer[bufferIdx2] = color2.r
                rgbaBuffer[bufferIdx2 + 1] = color2.g
                rgbaBuffer[bufferIdx2 + 2] = color2.b
                rgbaBuffer[bufferIdx2 + 3] = 255
            }
        }

        return ImageHelpers.createCGImage(from: rgbaBuffer, width: width, height: height)
    }

    private static func renderMSXScreen8(data: Data, palette: PaletteInfo) -> CGImage? {
        // Screen 8 is 256 colors, fixed palette (GGGRRRBB format)
        // Palette editing doesn't apply since colors are direct
        let width = 256
        let height = 212

        var offset = 0

        if data.count >= 7 && data[0] == 0xFE {
            offset = 7
        }

        let dataSize = data.count - offset
        guard dataSize >= 54272 else { return nil }

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

        return ImageHelpers.createCGImage(from: rgbaBuffer, width: width, height: height)
    }

    private static func renderMSXScreen2(data: Data, palette: PaletteInfo) -> CGImage? {
        let width = 256
        let height = 192

        var offset = 0

        if data.count >= 7 && data[0] == 0xFE {
            offset = 7
        }

        let dataSize = data.count - offset
        guard dataSize >= 6912 else { return nil }

        let primaryPalette = palette.primaryPalette
        guard primaryPalette.count >= 16 else { return nil }

        // Determine layout based on file size
        let patternNameTableOffset: Int
        let patternGeneratorOffset: Int
        let colorTableOffset: Int

        if dataSize >= 16384 {
            patternNameTableOffset = offset + 0x1800
            patternGeneratorOffset = offset + 0x0000
            colorTableOffset = offset + 0x2000
        } else if dataSize >= 14336 {
            patternNameTableOffset = offset
            patternGeneratorOffset = offset + 768
            colorTableOffset = offset + 768 + 6144
        } else {
            patternNameTableOffset = offset
            patternGeneratorOffset = offset
            colorTableOffset = offset + 6144
        }

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

                let bank = tileRow / 8
                let patternOffset = patternGeneratorOffset + (bank * 2048) + (patternNum * 8)
                let colorOffset = colorTableOffset + (bank * 2048) + (patternNum * 8)

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

                    let fgColorIdx = Int((colorByte >> 4) & 0x0F)
                    let bgColorIdx = Int(colorByte & 0x0F)

                    for pixel in 0..<8 {
                        let bit = (patternByte >> (7 - pixel)) & 1
                        let colorIdx = bit == 1 ? fgColorIdx : bgColorIdx
                        let actualColorIdx = colorIdx == 0 ? 1 : colorIdx

                        let x = tileCol * 8 + pixel
                        let y = tileRow * 8 + line
                        let bufferIdx = (y * width + x) * 4

                        let color = actualColorIdx < primaryPalette.count ? primaryPalette[actualColorIdx] : primaryPalette[0]
                        rgbaBuffer[bufferIdx] = color.r
                        rgbaBuffer[bufferIdx + 1] = color.g
                        rgbaBuffer[bufferIdx + 2] = color.b
                        rgbaBuffer[bufferIdx + 3] = 255
                    }
                }
            }
        }

        return ImageHelpers.createCGImage(from: rgbaBuffer, width: width, height: height)
    }

    // MARK: - Paintworks Renderer

    private static func renderPaintworks(data: Data, palette: PaletteInfo) -> CGImage? {
        guard data.count >= 0x222 else { return nil }

        // Paintworks format:
        // Offset 0x00-0x1F: Palette (16 colors x 2 bytes) - we ignore this and use modified palette
        // Offset 0x20-0x21: Background color
        // Offset 0x22-0x221: Patterns
        // Offset 0x222+: Compressed pixel data

        let startOffset = 0x222
        guard data.count > startOffset else { return nil }

        let remainingData = data.subdata(in: startOffset..<data.count)
        let width = 320
        let bytesPerLine = 160

        // Try different decompression methods (same as PackedSHRDecoder)
        var unpackedData: Data?
        var decodedHeight = 200

        // Method 1: Apple IIgs PackBytes
        let packedBytes = PackedSHRDecoder.unpackBytes(data: remainingData, maxOutputSize: 64000)
        if packedBytes.count >= 32000 {
            unpackedData = packedBytes
            decodedHeight = min(packedBytes.count / bytesPerLine, 396)
        }

        // Method 2: PackBits
        if unpackedData == nil || unpackedData!.count < 32000 {
            let packed = PackedSHRDecoder.unpackBits(data: remainingData, maxOutputSize: 64000)
            if packed.count >= 32000 {
                unpackedData = packed
                decodedHeight = min(packed.count / bytesPerLine, 396)
            }
        }

        // Method 3: Check if already uncompressed
        if unpackedData == nil || unpackedData!.count < 32000 {
            if remainingData.count >= 32000 && remainingData.count <= 33000 {
                unpackedData = Data(remainingData.prefix(32000))
                decodedHeight = 200
            }
        }

        guard let finalData = unpackedData, finalData.count >= bytesPerLine else {
            return nil
        }

        let height = min(decodedHeight, finalData.count / bytesPerLine)
        guard height > 0 else { return nil }

        let primaryPalette = palette.primaryPalette
        guard primaryPalette.count >= 16 else { return nil }

        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)

        for y in 0..<height {
            for xByte in 0..<bytesPerLine {
                let dataIndex = y * bytesPerLine + xByte
                guard dataIndex < finalData.count else { continue }
                let byte = finalData[dataIndex]

                let x = xByte * 2

                // First pixel (high nibble)
                let colorIdx1 = Int((byte >> 4) & 0x0F)
                let color1 = colorIdx1 < primaryPalette.count ? primaryPalette[colorIdx1] : primaryPalette[0]
                let bufIdx1 = (y * width + x) * 4
                rgbaBuffer[bufIdx1] = color1.r
                rgbaBuffer[bufIdx1 + 1] = color1.g
                rgbaBuffer[bufIdx1 + 2] = color1.b
                rgbaBuffer[bufIdx1 + 3] = 255

                // Second pixel (low nibble)
                let colorIdx2 = Int(byte & 0x0F)
                let color2 = colorIdx2 < primaryPalette.count ? primaryPalette[colorIdx2] : primaryPalette[0]
                let bufIdx2 = (y * width + x + 1) * 4
                rgbaBuffer[bufIdx2] = color2.r
                rgbaBuffer[bufIdx2 + 1] = color2.g
                rgbaBuffer[bufIdx2 + 2] = color2.b
                rgbaBuffer[bufIdx2 + 3] = 255
            }
        }

        return ImageHelpers.createCGImage(from: rgbaBuffer, width: width, height: height)
    }

    // MARK: - Packed SHR Renderer

    private static func renderPackedSHR(data: Data, palette: PaletteInfo) -> CGImage? {
        // Decompress the packed data first
        let decompressedData = PackedSHRDecoder.unpackBytes(data: data, maxOutputSize: 65536)

        guard decompressedData.count >= 32768 else { return nil }

        let width = 320
        let height = 200
        var rgbaBuffer = [UInt8](repeating: 255, count: width * height * 4)

        let pixelDataStart = 0
        let scbOffset = 32000

        // Convert PaletteInfo palettes to the tuple format used by renderer
        let palettes: [[(r: UInt8, g: UInt8, b: UInt8)]] = palette.palettes.map { paletteColors in
            paletteColors.map { ($0.r, $0.g, $0.b) }
        }

        guard !palettes.isEmpty else { return nil }

        for y in 0..<height {
            let scb: UInt8
            if scbOffset + y < decompressedData.count {
                scb = decompressedData[scbOffset + y]
            } else {
                scb = 0
            }
            let paletteIndex = Int(scb & 0x0F)
            let currentPalette = paletteIndex < palettes.count ? palettes[paletteIndex] : palettes[0]

            // Render the line using decompressed data
            for x in 0..<(width / 2) {
                let byteOffset = pixelDataStart + y * 160 + x
                guard byteOffset < decompressedData.count else { continue }

                let byte = decompressedData[byteOffset]
                let pixel1 = Int((byte >> 4) & 0x0F)
                let pixel2 = Int(byte & 0x0F)

                let bufferIdx1 = (y * width + x * 2) * 4
                let color1 = pixel1 < currentPalette.count ? currentPalette[pixel1] : currentPalette[0]
                rgbaBuffer[bufferIdx1] = color1.r
                rgbaBuffer[bufferIdx1 + 1] = color1.g
                rgbaBuffer[bufferIdx1 + 2] = color1.b
                rgbaBuffer[bufferIdx1 + 3] = 255

                let bufferIdx2 = (y * width + x * 2 + 1) * 4
                let color2 = pixel2 < currentPalette.count ? currentPalette[pixel2] : currentPalette[0]
                rgbaBuffer[bufferIdx2] = color2.r
                rgbaBuffer[bufferIdx2 + 1] = color2.g
                rgbaBuffer[bufferIdx2 + 2] = color2.b
                rgbaBuffer[bufferIdx2 + 3] = 255
            }
        }

        return ImageHelpers.createCGImage(from: rgbaBuffer, width: width, height: height)
    }
}
