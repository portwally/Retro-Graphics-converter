import Foundation
import CoreGraphics

// MARK: - Packed SHR Decoder (PNT formats)
// Implements Apple IIgs packed picture formats:
// - $C0/0000: Paintworks
// - $C0/0001: PackBytes compressed
// - $C0/0002: Apple Preferred Format (APF)

class PackedSHRDecoder {
    
    // MARK: - Apple IIgs PackBytes Decompression
    //
    // This is NOT the same as PackBits (MacPaint format)!
    // Apple IIgs PackBytes uses a different encoding:
    //
    // Flag byte format (high 2 bits determine mode):
    //   00xxxxxx (0x00-0x3F): Literal - copy next (N+1) bytes directly
    //   01xxxxxx (0x40-0x7F): Repeat next byte (N+1) times
    //   10xxxxxx (0x80-0xBF): Repeat next 4 bytes (N+1) times = (N+1)*4 output bytes
    //   11xxxxxx (0xC0-0xFF): Repeat next byte (N+1)*4 times
    //
    // Where N = flag & 0x3F (low 6 bits), so N ranges from 0-63
    //
    // Reference: Apple IIgs Tech Note #94 "Packing It In (and Out)"
    //            CiderPress2 source code (ApplePack.cs)
    
    static func unpackBytes(data: Data, maxOutputSize: Int = 65536) -> Data {
        var output = Data()
        output.reserveCapacity(min(maxOutputSize, data.count * 4))
        
        var pos = 0
        
        while pos < data.count && output.count < maxOutputSize {
            let flag = data[pos]
            pos += 1
            
            let flagCount = Int(flag & 0x3F) + 1  // Low 6 bits + 1 = 1-64
            let mode = flag & 0xC0  // High 2 bits
            
            switch mode {
            case 0x00:  // Literal: copy next flagCount bytes
                let bytesToCopy = min(flagCount, data.count - pos, maxOutputSize - output.count)
                if bytesToCopy > 0 {
                    output.append(data.subdata(in: pos..<(pos + bytesToCopy)))
                    pos += bytesToCopy
                }
                
            case 0x40:  // Repeat 8-bit value flagCount times
                if pos < data.count {
                    let repeatByte = data[pos]
                    pos += 1
                    let bytesToWrite = min(flagCount, maxOutputSize - output.count)
                    output.append(contentsOf: repeatElement(repeatByte, count: bytesToWrite))
                }
                
            case 0x80:  // Repeat 32-bit pattern flagCount times = flagCount * 4 bytes
                if pos + 4 <= data.count {
                    let pattern = Array(data[pos..<(pos + 4)])
                    pos += 4
                    for _ in 0..<flagCount {
                        if output.count + 4 <= maxOutputSize {
                            output.append(contentsOf: pattern)
                        } else {
                            let remaining = maxOutputSize - output.count
                            output.append(contentsOf: pattern.prefix(remaining))
                            break
                        }
                    }
                }
                
            case 0xC0:  // Repeat 8-bit value flagCount * 4 times
                if pos < data.count {
                    let repeatByte = data[pos]
                    pos += 1
                    let bytesToWrite = min(flagCount * 4, maxOutputSize - output.count)
                    output.append(contentsOf: repeatElement(repeatByte, count: bytesToWrite))
                }
                
            default:
                break  // Should never happen
            }
        }
        
        return output
    }
    
    // MARK: - PNT/$0002 Apple Preferred Format Decoder
    
    static func decodePNT0002(data: Data) -> (image: CGImage?, type: AppleIIImageType) {
        // Parse all blocks
        var blocks: [APFBlock] = []
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
            
            if dataLength > 0 && dataOffset + dataLength <= data.count {
                let blockData = data.subdata(in: dataOffset..<(dataOffset + dataLength))
                blocks.append(APFBlock(name: blockName, data: blockData))
            }
            
            pos += blockLength
        }
        
        guard !blocks.isEmpty else { return (nil, .Unknown) }
        
        // Find MAIN block
        guard let mainBlock = blocks.first(where: { $0.name == "MAIN" }) else {
            return (nil, .Unknown)
        }
        
        guard let mainData = parseMAINBlock(mainBlock.data) else {
            return (nil, .Unknown)
        }
        
        // Check for MULTIPAL (3200 color mode)
        var palettes3200: [[(r: UInt8, g: UInt8, b: UInt8)]]? = nil
        if let multipalBlock = blocks.first(where: { $0.name == "MULTIPAL" }) {
            palettes3200 = parseMULTIPALBlock(multipalBlock.data)
        }
        
        // Render image
        let image: CGImage?
        let modeString: String
        if let palettes = palettes3200, palettes.count >= mainData.numScanLines {
            image = renderSHR3200(mainData: mainData, palettes: palettes)
            modeString = "APF 3200"
        } else {
            image = renderSHRStandard(mainData: mainData)
            modeString = "APF"
        }
        
        return (image, .SHR(mode: modeString, width: mainData.pixelsPerScanLine, height: mainData.numScanLines))
    }
    
    // MARK: - Structures
    
    private struct APFBlock {
        let name: String
        let data: Data
    }
    
    private struct MAINBlockData {
        let masterMode: UInt16
        let pixelsPerScanLine: Int
        let colorTables: [[(r: UInt8, g: UInt8, b: UInt8)]]
        let numScanLines: Int
        let scanLineDirectory: [(packedBytes: Int, mode: UInt16)]
        let pixels: Data
    }
    
    // MARK: - Parse MAIN Block
    
    private static func parseMAINBlock(_ data: Data) -> MAINBlockData? {
        var pos = 0
        
        guard pos + 6 <= data.count else { return nil }
        
        let masterMode = UInt16(data[pos]) | (UInt16(data[pos + 1]) << 8)
        let pixelsPerScanLine = Int(data[pos + 2]) | (Int(data[pos + 3]) << 8)
        let numColorTables = Int(data[pos + 4]) | (Int(data[pos + 5]) << 8)
        pos += 6
        
        guard pixelsPerScanLine > 0 && pixelsPerScanLine <= 1280 else { return nil }
        
        // Read color tables
        var colorTables: [[(r: UInt8, g: UInt8, b: UInt8)]] = []
        for _ in 0..<numColorTables {
            guard pos + 32 <= data.count else { break }
            colorTables.append(readColorTable(from: data, at: pos))
            pos += 32
        }
        
        guard pos + 2 <= data.count else { return nil }
        let numScanLines = Int(data[pos]) | (Int(data[pos + 1]) << 8)
        pos += 2
        
        guard numScanLines > 0 && numScanLines <= 400 else { return nil }
        
        // Read scan line directory
        var scanLineDirectory: [(packedBytes: Int, mode: UInt16)] = []
        for _ in 0..<numScanLines {
            guard pos + 4 <= data.count else { break }
            let packedBytes = Int(data[pos]) | (Int(data[pos + 1]) << 8)
            let mode = UInt16(data[pos + 2]) | (UInt16(data[pos + 3]) << 8)
            scanLineDirectory.append((packedBytes: packedBytes, mode: mode))
            pos += 4
        }
        
        guard scanLineDirectory.count == numScanLines else { return nil }
        
        // Unpack all scan lines
        let bytesPerLine = pixelsPerScanLine / 2
        var allPixels = Data()
        allPixels.reserveCapacity(bytesPerLine * numScanLines)
        
        for entry in scanLineDirectory {
            guard pos + entry.packedBytes <= data.count else {
                // Pad with zeros for missing data
                allPixels.append(contentsOf: repeatElement(UInt8(0), count: bytesPerLine))
                continue
            }
            
            let packedLine = data.subdata(in: pos..<(pos + entry.packedBytes))
            pos += entry.packedBytes
            
            // Unpack this line using the corrected PackBytes algorithm
            var unpackedLine = unpackBytes(data: packedLine, maxOutputSize: bytesPerLine)
            
            // Ensure exactly bytesPerLine bytes
            if unpackedLine.count < bytesPerLine {
                unpackedLine.append(contentsOf: repeatElement(UInt8(0), count: bytesPerLine - unpackedLine.count))
            }
            
            allPixels.append(unpackedLine.prefix(bytesPerLine))
        }
        
        return MAINBlockData(
            masterMode: masterMode,
            pixelsPerScanLine: pixelsPerScanLine,
            colorTables: colorTables,
            numScanLines: numScanLines,
            scanLineDirectory: scanLineDirectory,
            pixels: allPixels
        )
    }
    
    // MARK: - Parse MULTIPAL Block
    
    private static func parseMULTIPALBlock(_ data: Data) -> [[(r: UInt8, g: UInt8, b: UInt8)]]? {
        guard data.count >= 2 else { return nil }
        
        let numColorTables = Int(data[0]) | (Int(data[1]) << 8)
        guard numColorTables > 0 && numColorTables <= 400 else { return nil }
        
        var palettes: [[(r: UInt8, g: UInt8, b: UInt8)]] = []
        var pos = 2
        
        for _ in 0..<numColorTables {
            guard pos + 32 <= data.count else { break }
            palettes.append(readColorTable(from: data, at: pos))
            pos += 32
        }
        
        return palettes.isEmpty ? nil : palettes
    }
    
    // MARK: - Read Color Table
    
    private static func readColorTable(from data: Data, at offset: Int) -> [(r: UInt8, g: UInt8, b: UInt8)] {
        var colors: [(r: UInt8, g: UInt8, b: UInt8)] = []
        
        for i in 0..<16 {
            let entryOffset = offset + (i * 2)
            guard entryOffset + 1 < data.count else {
                colors.append((0, 0, 0))
                continue
            }
            
            let low = data[entryOffset]
            let high = data[entryOffset + 1]
            
            // Format: $0RGB - high byte has 0R, low byte has GB
            let red = high & 0x0F
            let green = (low >> 4) & 0x0F
            let blue = low & 0x0F
            
            colors.append((r: red * 17, g: green * 17, b: blue * 17))
        }
        
        return colors
    }
    
    // MARK: - Render Standard SHR
    
    private static func renderSHRStandard(mainData: MAINBlockData) -> CGImage? {
        let width = mainData.pixelsPerScanLine
        let height = mainData.numScanLines
        let bytesPerLine = width / 2
        
        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)
        
        let defaultPalette: [(r: UInt8, g: UInt8, b: UInt8)] = [
            (0,0,0), (221,0,51), (0,0,153), (221,34,153),
            (0,119,34), (85,85,85), (34,34,255), (102,170,255),
            (136,85,0), (255,102,0), (170,170,170), (255,153,136),
            (17,221,0), (255,255,0), (68,255,153), (255,255,255)
        ]
        
        for y in 0..<height {
            let lineOffset = y * bytesPerLine
            let entry = y < mainData.scanLineDirectory.count ? mainData.scanLineDirectory[y] : (packedBytes: 0, mode: 0)
            let paletteIndex = Int(entry.mode & 0x0F)
            let is640Mode = (entry.mode & 0x80) != 0
            
            let palette = paletteIndex < mainData.colorTables.count ?
                         mainData.colorTables[paletteIndex] :
                         (mainData.colorTables.first ?? defaultPalette)
            
            if is640Mode {
                // 640 mode: 4 pixels per byte, 4 colors
                for xByte in 0..<bytesPerLine {
                    let dataIndex = lineOffset + xByte
                    guard dataIndex < mainData.pixels.count else { continue }
                    let byte = mainData.pixels[dataIndex]
                    
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
                }
            } else {
                // 320 mode: 2 pixels per byte, 16 colors
                for xByte in 0..<bytesPerLine {
                    let dataIndex = lineOffset + xByte
                    guard dataIndex < mainData.pixels.count else { continue }
                    let byte = mainData.pixels[dataIndex]
                    
                    let x = xByte * 2
                    
                    // First pixel (high nibble)
                    let colorIndex1 = Int((byte >> 4) & 0x0F)
                    let color1 = colorIndex1 < palette.count ? palette[colorIndex1] : (0, 0, 0)
                    
                    if x < width {
                        let bufIdx1 = (y * width + x) * 4
                        rgbaBuffer[bufIdx1] = color1.0
                        rgbaBuffer[bufIdx1 + 1] = color1.1
                        rgbaBuffer[bufIdx1 + 2] = color1.2
                        rgbaBuffer[bufIdx1 + 3] = 255
                    }
                    
                    // Second pixel (low nibble)
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
        
        return ImageHelpers.createCGImage(from: rgbaBuffer, width: width, height: height)
    }
    
    // MARK: - Render 3200 Color SHR
    
    private static func renderSHR3200(mainData: MAINBlockData, palettes: [[(r: UInt8, g: UInt8, b: UInt8)]]) -> CGImage? {
        let width = mainData.pixelsPerScanLine
        let height = mainData.numScanLines
        let bytesPerLine = width / 2
        
        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)
        
        for y in 0..<height {
            let lineOffset = y * bytesPerLine
            let palette = y < palettes.count ? palettes[y] : ImageHelpers.generateDefaultPalette()
            
            for xByte in 0..<bytesPerLine {
                let dataIndex = lineOffset + xByte
                guard dataIndex < mainData.pixels.count else { continue }
                let byte = mainData.pixels[dataIndex]
                
                let x = xByte * 2
                
                let colorIndex1 = Int((byte >> 4) & 0x0F)
                let color1 = colorIndex1 < palette.count ? palette[colorIndex1] : (0, 0, 0)
                
                let bufIdx1 = (y * width + x) * 4
                rgbaBuffer[bufIdx1] = color1.0
                rgbaBuffer[bufIdx1 + 1] = color1.1
                rgbaBuffer[bufIdx1 + 2] = color1.2
                rgbaBuffer[bufIdx1 + 3] = 255
                
                let colorIndex2 = Int(byte & 0x0F)
                let color2 = colorIndex2 < palette.count ? palette[colorIndex2] : (0, 0, 0)
                
                let bufIdx2 = (y * width + x + 1) * 4
                rgbaBuffer[bufIdx2] = color2.0
                rgbaBuffer[bufIdx2 + 1] = color2.1
                rgbaBuffer[bufIdx2 + 2] = color2.2
                rgbaBuffer[bufIdx2 + 3] = 255
            }
        }
        
        return ImageHelpers.createCGImage(from: rgbaBuffer, width: width, height: height)
    }
    
    // MARK: - Detection and Legacy Functions
    
    static func detectAndDecodePNT(data: Data) -> (image: CGImage?, type: AppleIIImageType)? {
        if isAPFFormat(data) {
            return decodePNT0002(data: data)
        }
        if isPaintworksFormat(data) {
            return decodePNT0000(data: data)
        }
        if let result = tryDecodePNT0001(data: data) {
            return result
        }
        return nil
    }
    
    static func tryDecodeAPF(data: Data) -> (image: CGImage?, type: AppleIIImageType)? {
        if isAPFFormat(data) {
            return decodePNT0002(data: data)
        }
        return nil
    }
    
    private static func isAPFFormat(_ data: Data) -> Bool {
        guard data.count >= 20 else { return false }
        
        let blockLength = Int(data[0]) | (Int(data[1]) << 8) | (Int(data[2]) << 16) | (Int(data[3]) << 24)
        guard blockLength >= 10 && blockLength <= data.count else { return false }
        
        let nameLength = Int(data[4])
        guard nameLength >= 4 && nameLength <= 15 && 5 + nameLength <= data.count else { return false }
        
        let nameData = data[5..<(5 + nameLength)]
        guard let blockName = String(data: nameData, encoding: .ascii) else { return false }
        
        return ["MAIN", "PATS", "SCIB", "PALETTES", "MASK", "MULTIPAL", "NOTE"].contains(blockName)
    }
    
    static func isPaintworksFormat(_ data: Data) -> Bool {
        guard data.count >= 0x222 else { return false }
        for i in 0..<16 {
            if (data[i * 2 + 1] & 0xF0) != 0 { return false }
        }
        return true
    }
    
    // MARK: - PNT/$0000 (Paintworks)
    // Paintworks can use different compression methods or even store uncompressed data
    
    static func decodePNT0000(data: Data) -> (image: CGImage?, type: AppleIIImageType) {
        guard data.count >= 0x222 else { return (nil, .Unknown) }
        
        // Read Super Hi-Res Palette (offset +$00 to +$1F)
        var palette: [(r: UInt8, g: UInt8, b: UInt8)] = []
        for i in 0..<16 {
            let low = data[i * 2]
            let high = data[i * 2 + 1]
            let red = high & 0x0F
            let green = (low >> 4) & 0x0F
            let blue = low & 0x0F
            palette.append((r: red * 17, g: green * 17, b: blue * 17))
        }
        
        // Skip background color (offset +$20 to +$21) and patterns (offset +$22 to +$221)
        // Data starts at offset +$222
        let startOffset = 0x222
        guard data.count > startOffset else { return (nil, .Unknown) }
        
        let remainingData = data.subdata(in: startOffset..<data.count)
        let width = 320
        let bytesPerLine = 160
        
        // Try different decompression methods
        var unpackedData: Data?
        var decodedHeight = 200
        
        // Method 1: Check if data is already uncompressed (32000 bytes = 320x200)
        if remainingData.count >= 32000 {
            // Might be uncompressed
            unpackedData = remainingData.prefix(32000)
            decodedHeight = 200
        }
        
        // Method 2: Try Apple IIgs PackBytes decompression
        if unpackedData == nil || unpackedData!.count < 1000 {
            let packed = unpackBytes(data: remainingData, maxOutputSize: 64000)
            if packed.count >= 16000 {  // At least half a screen
                unpackedData = packed
                decodedHeight = min(packed.count / bytesPerLine, 396)
            }
        }
        
        // Method 3: Try PackBits (older MacPaint-style compression)
        if unpackedData == nil || unpackedData!.count < 1000 {
            let packed = unpackBits(data: remainingData, maxOutputSize: 64000)
            if packed.count >= 16000 {
                unpackedData = packed
                decodedHeight = min(packed.count / bytesPerLine, 396)
            }
        }
        
        // Method 4: Try QuickDraw II PackBytes (another variant)
        if unpackedData == nil || unpackedData!.count < 1000 {
            let packed = unpackQuickDrawII(data: remainingData, maxOutputSize: 64000)
            if packed.count >= 16000 {
                unpackedData = packed
                decodedHeight = min(packed.count / bytesPerLine, 396)
            }
        }
        
        guard let finalData = unpackedData, finalData.count >= bytesPerLine else {
            return (nil, .Unknown)
        }
        
        let height = min(decodedHeight, finalData.count / bytesPerLine)
        guard height > 0 else { return (nil, .Unknown) }
        
        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)
        
        for y in 0..<height {
            for xByte in 0..<bytesPerLine {
                let dataIndex = y * bytesPerLine + xByte
                guard dataIndex < finalData.count else { continue }
                let byte = finalData[dataIndex]
                
                let x = xByte * 2
                
                // First pixel (high nibble)
                let color1 = palette[Int((byte >> 4) & 0x0F)]
                let bufIdx1 = (y * width + x) * 4
                rgbaBuffer[bufIdx1] = color1.0
                rgbaBuffer[bufIdx1 + 1] = color1.1
                rgbaBuffer[bufIdx1 + 2] = color1.2
                rgbaBuffer[bufIdx1 + 3] = 255
                
                // Second pixel (low nibble)
                let color2 = palette[Int(byte & 0x0F)]
                let bufIdx2 = (y * width + x + 1) * 4
                rgbaBuffer[bufIdx2] = color2.0
                rgbaBuffer[bufIdx2 + 1] = color2.1
                rgbaBuffer[bufIdx2 + 2] = color2.2
                rgbaBuffer[bufIdx2 + 3] = 255
            }
        }
        
        guard let cgImage = ImageHelpers.createCGImage(from: rgbaBuffer, width: width, height: height) else {
            return (nil, .Unknown)
        }
        
        return (cgImage, .SHR(mode: "Paintworks", width: width, height: height))
    }
    
    // MARK: - QuickDraw II PackBytes (alternative variant used in some Paintworks files)
    // This variant is similar to PackBits but uses different byte ranges
    
    static func unpackQuickDrawII(data: Data, maxOutputSize: Int = 65536) -> Data {
        var output = Data()
        output.reserveCapacity(min(maxOutputSize, data.count * 2))
        
        var pos = 0
        
        while pos < data.count && output.count < maxOutputSize {
            guard pos < data.count else { break }
            let flag = data[pos]
            pos += 1
            
            if flag <= 127 {
                // Literal: copy next (flag + 1) bytes
                let count = Int(flag) + 1
                let bytesToCopy = min(count, data.count - pos, maxOutputSize - output.count)
                if bytesToCopy > 0 {
                    output.append(data.subdata(in: pos..<(pos + bytesToCopy)))
                    pos += bytesToCopy
                }
            } else if flag >= 129 {
                // Repeat: repeat next byte (257 - flag) times
                let count = 257 - Int(flag)
                if pos < data.count {
                    let repeatByte = data[pos]
                    pos += 1
                    let bytesToWrite = min(count, maxOutputSize - output.count)
                    output.append(contentsOf: repeatElement(repeatByte, count: bytesToWrite))
                }
            }
            // flag == 128: no-op
        }
        
        return output
    }
    
    // MARK: - PackBits (MacPaint format) - for Paintworks compatibility
    // This is different from PackBytes!
    //
    // PackBits format (signed byte interpretation):
    //   n = 0-127:   Literal run - copy next (n+1) bytes
    //   n = -128:    No operation (skip)
    //   n = -127..-1: Repeat run - repeat next byte (1-n) times, i.e. (257-flag) for unsigned
    
    static func unpackBits(data: Data, maxOutputSize: Int = 65536) -> Data {
        var output = Data()
        output.reserveCapacity(min(maxOutputSize, data.count * 2))
        
        var pos = 0
        
        while pos < data.count && output.count < maxOutputSize {
            let flag = data[pos]
            pos += 1
            
            if flag < 128 {
                // Literal run: copy (flag + 1) bytes
                let count = Int(flag) + 1
                let bytesToCopy = min(count, data.count - pos, maxOutputSize - output.count)
                if bytesToCopy > 0 {
                    output.append(data.subdata(in: pos..<(pos + bytesToCopy)))
                    pos += bytesToCopy
                }
            } else if flag > 128 {
                // Repeat run: repeat next byte (257 - flag) times
                let count = 257 - Int(flag)
                if pos < data.count {
                    let repeatByte = data[pos]
                    pos += 1
                    let bytesToWrite = min(count, maxOutputSize - output.count)
                    output.append(contentsOf: repeatElement(repeatByte, count: bytesToWrite))
                }
            }
            // flag == 128: no-op, just skip
        }
        
        return output
    }
    
    // MARK: - PNT/$0001 (PackBytes)
    
    private static func tryDecodePNT0001(data: Data) -> (image: CGImage?, type: AppleIIImageType)? {
        let unpackedData = unpackBytes(data: data, maxOutputSize: 32768)
        guard unpackedData.count >= 32000 else { return nil }
        
        if let image = AppleIIDecoder.decodeSHR(data: unpackedData, is3200Color: false) {
            return (image, .SHR(mode: "Packed", width: 320, height: 200))
        }
        return nil
    }
    
    static func decodePNT0001(data: Data) -> (image: CGImage?, type: AppleIIImageType) {
        return tryDecodePNT0001(data: data) ?? (nil, .Unknown)
    }
    
    // Legacy compatibility
    static func decompressPackBytes(data: Data, expectedSize: Int? = nil) -> Data? {
        let result = unpackBytes(data: data, maxOutputSize: expectedSize ?? 65536)
        return result.isEmpty ? nil : result
    }
    
    static func decompressPackBytesSafe(data: Data, expectedSize: Int? = nil) -> Data? {
        return decompressPackBytes(data: data, expectedSize: expectedSize)
    }
}
