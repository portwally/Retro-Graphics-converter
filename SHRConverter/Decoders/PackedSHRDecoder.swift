import Foundation
import CoreGraphics

// MARK: - Packed SHR Decoder (PNT formats)

class PackedSHRDecoder {
    
    // MARK: - PackBytes Decompression
    
    static func decompressPackBytesSafe(data: Data, expectedSize: Int? = nil) -> Data? {
        if data.count >= 31900 && data.count <= 33000 {
            var raw = Data(data)
            if let size = expectedSize, raw.count < size {
                raw.append(contentsOf: repeatElement(0, count: size - raw.count))
            }
            return raw
        }
        
        let input = Data(data)
        var output = Data()
        let limit = expectedSize ?? 2_000_000
        
        if let size = expectedSize { output.reserveCapacity(size) }
        
        let count = input.count
        var pos = 0
        
        while pos < count && output.count < limit {
            let flag = input[pos]
            pos += 1
            
            if flag < 0x20 {
                if pos >= count { break }
                let value = input[pos]
                pos += 1
                let repeatCount = Int(flag) + 3
                let spaceLeft = limit - output.count
                output.append(contentsOf: repeatElement(value, count: min(repeatCount, spaceLeft)))
            } else {
                let literalCount = Int(flag) - 0x1D
                let inputLeft = count - pos
                let outputLeft = limit - output.count
                let copyCount = min(literalCount, min(inputLeft, outputLeft))
                
                if copyCount > 0 {
                    output.append(input.subdata(in: pos..<pos+copyCount))
                    pos += copyCount
                }
                if copyCount < literalCount { pos = count }
            }
        }
        
        if let expected = expectedSize, output.count < expected, output.count > 0 {
            output.append(contentsOf: repeatElement(0, count: expected - output.count))
        }
        
        return output.count > 0 ? output : nil
    }
    
    static func decompressPackBytes(data: Data, expectedSize: Int? = nil) -> Data? {
        return decompressPackBytesSafe(data: data, expectedSize: expectedSize)
    }
    
    static func decompressAPFPixelData(data: Data, expectedSize: Int) -> Data {
        var result = Data()
        result.reserveCapacity(expectedSize)
        
        var i = 0
        let end = data.count
        
        while i < end && result.count < expectedSize {
            let flag = data[i]
            i += 1
            
            let mode = (flag & 0xC0) >> 6
            let count = Int(flag & 0x3F) + 1
            
            if i >= end { break }
            
            switch mode {
            case 0:
                let copyLen = min(count, end - i)
                if copyLen > 0 {
                    result.append(data.subdata(in: i..<i+copyLen))
                    i += copyLen
                }
                
            case 1:
                let val = data[i]
                i += 1
                result.append(contentsOf: repeatElement(val, count: count))
                
            case 2:
                if i + 4 <= end {
                    let group = data.subdata(in: i..<i+4)
                    i += 4
                    for _ in 0..<count {
                        result.append(group)
                    }
                }
                
            case 3:
                let val = data[i]
                i += 1
                let group = Data([val, val, val, val])
                for _ in 0..<count {
                    result.append(group)
                }
                
            default: break
            }
        }
        
        if result.count < expectedSize {
            let diff = expectedSize - result.count
            if diff > 0 {
                result.append(contentsOf: repeatElement(0, count: diff))
            }
        }
        
        return result
    }
    
    // MARK: - PNT Detection
    
    static func detectAndDecodePNT(data: Data) -> (image: CGImage?, type: AppleIIImageType)? {
        let size = data.count
        
        // Check for APF
        if size >= 20 {
            let blockLength = Int(data[0]) |
                            (Int(data[1]) << 8) |
                            (Int(data[2]) << 16) |
                            (Int(data[3]) << 24)
            
            if blockLength >= 100 && blockLength <= size && blockLength < size {
                let nameLength = Int(data[4])
                
                if nameLength >= 4 && nameLength <= 15 && data.count >= 5 + nameLength {
                    let nameData = data[5..<(5 + nameLength)]
                    if let blockName = String(data: nameData, encoding: .ascii) {
                        let validBlockNames = ["MAIN", "PATS", "SCIB", "PALETTES", "MASK", "MULTIPAL", "NOTE"]
                        
                        if validBlockNames.contains(blockName) {
                            return decodePNT0002(data: data)
                        }
                    }
                }
            }
        }
        
        // Check for Paintworks
        if size >= 0x222 {
            var validPalette = true
            for i in 0..<16 {
                if i * 2 + 1 < data.count {
                    let highByte = data[i * 2 + 1]
                    if (highByte & 0xF0) != 0 {
                        validPalette = false
                        break
                    }
                }
            }
            
            if validPalette && size > 0x222 {
                let patternData = data[0x22..<min(0x100, data.count)]
                if Set(patternData).count > 50 {
                    return decodePNT0000(data: data)
                }
            }
        }
        
        // Try PackBytes
        if let decompressed = decompressPackBytes(data: data, expectedSize: nil) {
            if decompressed.count >= 32768 && decompressed.count <= 32800 {
                return decodePNT0001(data: data)
            }
        }
        
        return nil
    }
    
    static func tryDecodeAPF(data: Data) -> (image: CGImage?, type: AppleIIImageType)? {
        let size = data.count
        guard size >= 20 else { return nil }
        
        let blockLength = Int(data[0]) |
                         (Int(data[1]) << 8) |
                         (Int(data[2]) << 16) |
                         (Int(data[3]) << 24)
        
        guard blockLength >= 100 && blockLength <= size && blockLength < size else { return nil }
        
        let nameLength = Int(data[4])
        guard nameLength >= 4 && nameLength <= 15 && data.count >= 5 + nameLength else { return nil }
        
        let nameData = data[5..<(5 + nameLength)]
        guard let blockName = String(data: nameData, encoding: .ascii) else { return nil }
        
        let validBlockNames = ["MAIN", "PATS", "SCIB", "PALETTES", "MASK", "MULTIPAL", "NOTE"]
        guard validBlockNames.contains(blockName) else { return nil }
        
        return decodePNT0002(data: data)
    }
    
    // MARK: - PNT/$0000 (Paintworks)
    
    static func decodePNT0000(data: Data) -> (image: CGImage?, type: AppleIIImageType) {
        guard data.count >= 0x222 else {
            return (nil, .Unknown)
        }
        
        var palette: [(r: UInt8, g: UInt8, b: UInt8)] = []
        for i in 0..<16 {
            let offset = i * 2
            let low = data[offset]
            let high = data[offset + 1]
            
            let blue = low & 0x0F
            let green = (low >> 4) & 0x0F
            let red = high & 0x0F
            
            palette.append((
                r: red * 17,
                g: green * 17,
                b: blue * 17
            ))
        }
        
        let compressedData = data.subdata(in: 0x222..<data.count)
        
        guard let decompressed = decompressPackBytes(data: compressedData, expectedSize: nil) else {
            return (nil, .Unknown)
        }
        
        let height: Int
        if decompressed.count >= 63000 && decompressed.count <= 64000 {
            height = 396
        } else if decompressed.count >= 31500 && decompressed.count <= 32500 {
            height = 200
        } else {
            height = min(decompressed.count / 160, 400)
        }
        
        let width = 320
        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)
        
        for y in 0..<height {
            let lineOffset = y * 160
            
            for x in 0..<width {
                let byteIndex = lineOffset + (x / 2)
                
                guard byteIndex < decompressed.count else { continue }
                
                let byte = decompressed[byteIndex]
                let colorIndex: Int
                
                if x % 2 == 0 {
                    colorIndex = Int((byte >> 4) & 0x0F)
                } else {
                    colorIndex = Int(byte & 0x0F)
                }
                
                let color = palette[min(colorIndex, palette.count - 1)]
                let bufferIdx = (y * width + x) * 4
                
                rgbaBuffer[bufferIdx] = color.r
                rgbaBuffer[bufferIdx + 1] = color.g
                rgbaBuffer[bufferIdx + 2] = color.b
                rgbaBuffer[bufferIdx + 3] = 255
            }
        }
        
        guard let cgImage = ImageHelpers.createCGImage(from: rgbaBuffer, width: width, height: height) else {
            return (nil, .Unknown)
        }
        
        return (cgImage, .SHR(mode: "Paintworks"))
    }
    
    // MARK: - PNT/$0001 (PackBytes)
    
    static func decodePNT0001(data: Data) -> (image: CGImage?, type: AppleIIImageType) {
        guard let decompressed = decompressPackBytes(data: data, expectedSize: 32768) else {
            return (nil, .Unknown)
        }
        
        guard decompressed.count >= 32768 else {
            return (nil, .Unknown)
        }
        
        return (AppleIIDecoder.decodeSHR(data: decompressed, is3200Color: false), .SHR(mode: "Packed"))
    }
    
    // MARK: - PNT/$0002 (Apple Preferred Format)
    
    static func decodePNT0002(data: Data) -> (image: CGImage?, type: AppleIIImageType) {
        var blocks: [(name: String, data: Data, offset: Int)] = []
        var pos = 0
        let safeData = Data(data)
        
        while pos + 9 <= safeData.count {
            let bLen = Int(safeData[pos]) | (Int(safeData[pos+1])<<8) | (Int(safeData[pos+2])<<16) | (Int(safeData[pos+3])<<24)
            let nLen = Int(safeData[pos+4])
            if pos + 5 + nLen > safeData.count { break }
            let name = String(data: safeData[(pos+5)..<(pos+5+nLen)], encoding: .ascii) ?? "UNK"
            let cStart = pos + 5 + nLen
            let cLen = bLen - (5 + nLen)
            
            if cStart + cLen <= safeData.count {
                blocks.append((name: name, data: safeData.subdata(in: cStart..<cStart+cLen), offset: pos))
            }
            pos += bLen
        }
        
        var rawContent = Data()
        var detectedMode = "APF"
        
        if let vsmk = blocks.first(where: { $0.name == "VSMK" }) {
            if let unpacked = decompressPackBytesSafe(data: vsmk.data, expectedSize: 64000) {
                rawContent = unpacked
                detectedMode = "APF/VSMK"
            }
        } else if let main = blocks.first(where: { $0.name == "MAIN" }) {
            if let m = parseMAINBlock(data: safeData, blockOffset: main.offset) {
                rawContent = m.pixels
                detectedMode = "APF/MAIN"
            }
        }
        
        var finalPixels = Data()
        var scibData: Data? = nil
        
        if !rawContent.isEmpty {
            let startOffset = 336
            
            if rawContent.count >= 256 {
                let scbStart = rawContent.count - 256
                scibData = rawContent.subdata(in: scbStart..<rawContent.count)
            }
            
            if rawContent.count >= startOffset + 32000 {
                finalPixels = rawContent.subdata(in: startOffset..<startOffset+32000)
            } else if rawContent.count > startOffset {
                finalPixels = rawContent.subdata(in: startOffset..<rawContent.count)
            } else {
                finalPixels = rawContent
            }
            
            if finalPixels.count < 32000 {
                finalPixels.append(contentsOf: repeatElement(0, count: 32000 - finalPixels.count))
            }
        }
        
        let finalSCIB = blocks.first(where: { $0.name == "SCIB" })?.data ?? scibData
        
        var palettes3200: [[(r: UInt8, g: UInt8, b: UInt8)]] = []
        if let multiBlock = blocks.first(where: { $0.name == "MULTIPAL" }) {
            let mData = multiBlock.data
            if mData.count > 2 {
                var pPos = 2
                while pPos + 32 <= mData.count {
                    palettes3200.append(ImageHelpers.readPalette(from: mData, offset: pPos, reverseOrder: false))
                    pPos += 32
                }
            }
        }
        
        if !finalPixels.isEmpty {
             if !palettes3200.isEmpty && finalPixels.count >= 32000 {
                 if let img = decodeSHR3200WithPalettes(pixels: finalPixels, width: 320, height: 200, palettes: palettes3200) {
                      return (img, .SHR(mode: "APF 3200"))
                 }
            }
            
            var usedPalettes: [[(r: UInt8, g: UInt8, b: UInt8)]] = []
            if let main = blocks.first(where: { $0.name == "MAIN" }),
               let p = parseMAINBlockForPalettesOnly(data: safeData, blockOffset: main.offset) {
                usedPalettes = p
            } else {
                usedPalettes = [ImageHelpers.generateDefaultPalette()]
            }

            if let img = decodeSHRWithSCIB(pixels: finalPixels, width: 320, height: 200, palettes: usedPalettes, scib: finalSCIB) {
                return (img, .SHR(mode: detectedMode))
            }
        }
        
        return (nil, .SHR(mode: "APF Error"))
    }
    
    // MARK: - Helper Functions
    
    static func parseMAINBlock(data: Data, blockOffset: Int) -> (scbs: Data, palettes: [[(r: UInt8, g: UInt8, b: UInt8)]], pixels: Data, width: Int, height: Int)? {
        guard blockOffset + 5 <= data.count else { return nil }
        
        let nameLength = Int(data[blockOffset + 4])
        let contentStart = blockOffset + 5 + nameLength
        
        func readUInt32(_ relOffset: Int) -> Int {
            let absOffset = contentStart + relOffset
            if absOffset + 4 > data.count { return 0 }
            let val = data.subdata(in: absOffset..<absOffset+4).withUnsafeBytes { $0.load(as: UInt32.self) }
            return Int(val.littleEndian)
        }
        
        func readUInt16(_ relOffset: Int) -> Int {
            let absOffset = contentStart + relOffset
            if absOffset + 2 > data.count { return 0 }
            let val = data.subdata(in: absOffset..<absOffset+2).withUnsafeBytes { $0.load(as: UInt16.self) }
            return Int(val.littleEndian)
        }

        let lenSCB_32 = readUInt32(2)
        let lenPal_32 = readUInt32(6)
        let lenPix_32 = readUInt32(10)
        
        let lenSCB_16 = readUInt16(2)
        let lenPal_16 = readUInt16(4)

        var lenSCB = 0
        var lenPal = 0
        var lenPix = 0
        var headerSkip = 14
        
        let fileSize = data.count
        if lenSCB_32 < fileSize && lenPal_32 < fileSize && lenPix_32 < fileSize && (lenPix_32 > 0 || lenSCB_32 > 0) {
            lenSCB = lenSCB_32
            lenPal = lenPal_32
            lenPix = lenPix_32
        } else {
            lenSCB = lenSCB_16
            lenPal = lenPal_16
            headerSkip = 6
            lenPix = max(0, fileSize - contentStart - headerSkip - lenSCB - lenPal)
        }
        
        var currentPos = contentStart + headerSkip
        
        var scbs = Data()
        if lenSCB > 0 && currentPos + lenSCB <= data.count {
            let raw = data.subdata(in: currentPos..<currentPos + lenSCB)
            scbs = decompressPackBytesSafe(data: raw, expectedSize: 3200) ?? Data()
            currentPos += lenSCB
        }
        
        var parsedPalettes: [[(r: UInt8, g: UInt8, b: UInt8)]] = []
        if lenPal > 0 && currentPos + lenPal <= data.count {
            let raw = data.subdata(in: currentPos..<currentPos + lenPal)
            if let paletteData = decompressPackBytesSafe(data: raw, expectedSize: 32768) {
                 parsedPalettes = ImageHelpers.convertRawPalettes(paletteData)
            }
            currentPos += lenPal
        }
        
        var pixels = Data()
        if lenPix > 0 && currentPos + lenPix <= data.count {
            let raw = data.subdata(in: currentPos..<currentPos + lenPix)
            pixels = decompressAPFPixelData(data: raw, expectedSize: 32768)
        }
        
        if pixels.isEmpty || pixels.count < 100 {
            return attemptRawDecompression(data: data, start: contentStart + 14, skipHeaderBytes: 0)
        }
        
        return (scbs, parsedPalettes, pixels, 320, 200)
    }
    
    static func attemptRawDecompression(data: Data, start: Int, skipHeaderBytes: Int = 0) -> (Data, [[(r: UInt8, g: UInt8, b: UInt8)]], Data, Int, Int)? {
        let actualStart = start + skipHeaderBytes
        guard actualStart < data.count else { return nil }
        
        let rawData = data.subdata(in: actualStart..<data.count)
        
        if let pixels = decompressPackBytesSafe(data: rawData, expectedSize: 32768) {
            if pixels.count >= 16000 {
                let defaultPalettes = [ImageHelpers.generateDefaultPalette()]
                return (Data(), defaultPalettes, pixels, 320, 200)
            }
        }
        return nil
    }
    
    static func parseMAINBlockForPalettesOnly(data: Data, blockOffset: Int) -> [[(r: UInt8, g: UInt8, b: UInt8)]]? {
        let blockLength = Int(data[blockOffset]) | (Int(data[blockOffset + 1]) << 8) |
                         (Int(data[blockOffset + 2]) << 16) | (Int(data[blockOffset + 3]) << 24)
        let nameLength = Int(data[blockOffset + 4])
        let blockDataStart = blockOffset + 5 + nameLength
        let blockEnd = min(blockOffset + blockLength, data.count)
        
        var pos = blockDataStart
        
        guard pos + 6 <= blockEnd else { return nil }
        
        let numColorTables = Int(data[pos + 4]) | (Int(data[pos + 5]) << 8)
        pos += 6
        
        guard numColorTables > 0 && numColorTables <= 256 else { return nil }
        
        var palettes: [[(r: UInt8, g: UInt8, b: UInt8)]] = []
        
        for _ in 0..<numColorTables {
            guard pos + 32 <= blockEnd else { break }
            
            var palette: [(r: UInt8, g: UInt8, b: UInt8)] = []
            for _ in 0..<16 {
                let low = data[pos]
                let high = data[pos + 1]
                pos += 2
                
                let blue = low & 0x0F
                let green = (low >> 4) & 0x0F
                let red = high & 0x0F
                
                palette.append((r: red * 17, g: green * 17, b: blue * 17))
            }
            
            palettes.append(palette)
        }
        
        return palettes
    }
    
    static func decodeSHRWithSCIB(pixels: Data, width: Int, height: Int,
                                   palettes: [[(r: UInt8, g: UInt8, b: UInt8)]],
                                   scib: Data?) -> CGImage? {
        
        let renderWidth = 320
        let renderHeight = 200
        var rgbaBuffer = [UInt8](repeating: 0, count: renderWidth * renderHeight * 4)
        
        let defaultPalette: [(r: UInt8, g: UInt8, b: UInt8)] = [
            (0,0,0), (114,38,64), (64,51,127), (228,34,204),
            (26,106,90), (128,128,128), (28,78,206), (119,173,255),
            (194,92,30), (230,123,0), (198,189,171), (229,189,209),
            (46,194,22), (163,222,109), (133,212,229), (255,255,255)
        ]
        
        let scibArray = scib.map { Array($0) } ?? []
        
        for y in 0..<renderHeight {
            let lineOffset = y * 160
            
            var scbByte: UInt8 = 0x00
            if y < scibArray.count {
                scbByte = scibArray[y]
            }
            
            let palIdx = Int(scbByte & 0x0F)
            let activePalette = (palIdx < palettes.count) ? palettes[palIdx] : (palettes.first ?? defaultPalette)
            
            let is640 = (scbByte & 0x80) != 0
            
            for x in 0..<160 {
                if lineOffset + x >= pixels.count { break }
                let byte = pixels[lineOffset + x]
                
                if is640 {
                    for sub in 0..<2 {
                        let shift = (3 - (sub*2)) * 2
                        let colorIdx = (byte >> shift) & 0x03
                        let color = activePalette[Int(colorIdx) + (sub * 4)]
                        
                        let bufIdx = (y * renderWidth + (x * 2 + sub)) * 4
                        rgbaBuffer[bufIdx] = color.r
                        rgbaBuffer[bufIdx+1] = color.g
                        rgbaBuffer[bufIdx+2] = color.b
                        rgbaBuffer[bufIdx+3] = 255
                    }
                } else {
                    let c1 = activePalette[Int((byte >> 4) & 0x0F)]
                    let c2 = activePalette[Int(byte & 0x0F)]
                    
                    let bufIdx = (y * renderWidth + (x * 2)) * 4
                    
                    rgbaBuffer[bufIdx] = c1.r
                    rgbaBuffer[bufIdx+1] = c1.g
                    rgbaBuffer[bufIdx+2] = c1.b
                    rgbaBuffer[bufIdx+3] = 255
                    
                    rgbaBuffer[bufIdx+4] = c2.r
                    rgbaBuffer[bufIdx+5] = c2.g
                    rgbaBuffer[bufIdx+6] = c2.b
                    rgbaBuffer[bufIdx+7] = 255
                }
            }
        }
        
        return ImageHelpers.createCGImage(from: rgbaBuffer, width: renderWidth, height: renderHeight)
    }
    
    static func decodeSHR3200WithPalettes(pixels: Data, width: Int, height: Int, palettes: [[(r: UInt8, g: UInt8, b: UInt8)]]) -> CGImage? {
        let actualWidth = 320
        var rgbaBuffer = [UInt8](repeating: 0, count: actualWidth * height * 4)
        
        for y in 0..<height {
            let palette = y < palettes.count ? palettes[y] : ImageHelpers.generateDefaultPalette()
            
            let lineOffset = y * (width / 2)
            
            for x in 0..<actualWidth {
                let byteIndex = lineOffset + (x / 2)
                
                guard byteIndex < pixels.count else { continue }
                
                let byte = pixels[byteIndex]
                let colorIndex: Int
                
                if x % 2 == 0 {
                    colorIndex = Int((byte >> 4) & 0x0F)
                } else {
                    colorIndex = Int(byte & 0x0F)
                }
                
                let color = palette[min(colorIndex, palette.count - 1)]
                let bufferIdx = (y * actualWidth + x) * 4
                
                rgbaBuffer[bufferIdx] = color.r
                rgbaBuffer[bufferIdx + 1] = color.g
                rgbaBuffer[bufferIdx + 2] = color.b
                rgbaBuffer[bufferIdx + 3] = 255
            }
        }
        
        return ImageHelpers.createCGImage(from: rgbaBuffer, width: actualWidth, height: height)
    }
}
