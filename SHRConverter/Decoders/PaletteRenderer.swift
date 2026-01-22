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

        let xMin = Int(data[4]) | (Int(data[5]) << 8)
        let yMin = Int(data[6]) | (Int(data[7]) << 8)
        let xMax = Int(data[8]) | (Int(data[9]) << 8)
        let yMax = Int(data[10]) | (Int(data[11]) << 8)
        let width = xMax - xMin + 1
        let height = yMax - yMin + 1
        let numPlanes = Int(data[65])
        let bytesPerLine = Int(data[66]) | (Int(data[67]) << 8)

        guard width > 0, height > 0, width < 10000, height < 10000 else { return nil }

        let primaryPalette = palette.primaryPalette
        guard !primaryPalette.isEmpty else { return nil }

        let pcxPalette: [(r: UInt8, g: UInt8, b: UInt8)] = primaryPalette.map { ($0.r, $0.g, $0.b) }

        // Decompress RLE data
        var decompressedData: [UInt8] = []
        var offset = 128
        let expectedSize = numPlanes == 0 ? bytesPerLine * height : bytesPerLine * numPlanes * height

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

        if bitsPerPixel == 8 && numPlanes == 1 {
            // 256-color mode
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
        } else if bitsPerPixel <= 4 {
            // 16-color or less
            for y in 0..<height {
                for x in 0..<width {
                    let byteIndex = y * bytesPerLine + (x / 8)
                    let bitIndex = 7 - (x % 8)
                    if byteIndex < decompressedData.count {
                        let bit = (decompressedData[byteIndex] >> bitIndex) & 1
                        let color = Int(bit) < pcxPalette.count ? pcxPalette[Int(bit)] : (r: UInt8(0), g: UInt8(0), b: UInt8(0))
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
}
