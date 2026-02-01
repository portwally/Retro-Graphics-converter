import Foundation
import CoreGraphics

// MARK: - Retro Platform Decoder (ZX Spectrum, Amstrad CPC, MacPaint)

class RetroDecoder {
    
    static let zxSpectrumPalette: [(r: UInt8, g: UInt8, b: UInt8)] = [
        (0x00, 0x00, 0x00), (0x00, 0x00, 0xD7), (0xD7, 0x00, 0x00), (0xD7, 0x00, 0xD7),
        (0x00, 0xD7, 0x00), (0x00, 0xD7, 0xD7), (0xD7, 0xD7, 0x00), (0xD7, 0xD7, 0xD7),
        (0x00, 0x00, 0x00), (0x00, 0x00, 0xFF), (0xFF, 0x00, 0x00), (0xFF, 0x00, 0xFF),
        (0x00, 0xFF, 0x00), (0x00, 0xFF, 0xFF), (0xFF, 0xFF, 0x00), (0xFF, 0xFF, 0xFF)
    ]
    
    // Amstrad CPC 27-color hardware palette (matching BitPast for compatibility)
    // BitPast treats its palette array as [R,G,B] even though values are stored as BGR.
    // For compatibility, we use the exact same values and interpretation as BitPast.
    // This ensures .scr files exported from BitPast display correctly when imported here.
    static let amstradCPCPalette: [(r: UInt8, g: UInt8, b: UInt8)] = [
        (0x01, 0x02, 0x00),  // 0: Black
        (0x6B, 0x02, 0x00),  // 1: Blue
        (0xF4, 0x02, 0x0C),  // 2: Bright Blue
        (0x01, 0x02, 0x6C),  // 3: Red
        (0x68, 0x02, 0x69),  // 4: Magenta
        (0xF2, 0x02, 0x6C),  // 5: Mauve
        (0x06, 0x05, 0xF3),  // 6: Bright Red
        (0x68, 0x02, 0xF0),  // 7: Purple
        (0xF4, 0x02, 0xF3),  // 8: Bright Magenta
        (0x01, 0x78, 0x02),  // 9: Green
        (0x68, 0x78, 0x00),  // 10: Cyan
        (0xF4, 0x7B, 0x0C),  // 11: Sky Blue
        (0x01, 0x7B, 0x6E),  // 12: Yellow
        (0x6B, 0x7D, 0x6E),  // 13: White
        (0xF6, 0x7B, 0x6E),  // 14: Pastel Blue
        (0x0D, 0x7D, 0xF3),  // 15: Orange
        (0x6B, 0x7D, 0xF3),  // 16: Pink
        (0xF9, 0x80, 0xFA),  // 17: Pastel Magenta
        (0x01, 0xF0, 0x02),  // 18: Bright Green
        (0x6B, 0xF3, 0x00),  // 19: Sea Green
        (0xF2, 0xF3, 0x0F),  // 20: Bright Cyan
        (0x04, 0xF5, 0x71),  // 21: Lime
        (0x6B, 0xF3, 0x71),  // 22: Pastel Green
        (0xF4, 0xF3, 0x71),  // 23: Pastel Cyan
        (0x0D, 0xF3, 0xF3),  // 24: Bright Yellow
        (0x6D, 0xF3, 0xF3),  // 25: Pastel Yellow
        (0xF9, 0xF3, 0xFF)   // 26: Bright White
    ]
    
    static func decodeZXSpectrum(data: Data) -> (image: CGImage?, type: AppleIIImageType) {
        guard data.count == 6912 else { return (nil, .Unknown) }
        
        let width = 256, height = 192
        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)
        
        for y in 0..<height {
            let third = y / 64, lineInThird = y % 64
            let octave = lineInThird / 8, lineInOctave = lineInThird % 8
            let bitmapLineOffset = (third * 2048) + (lineInOctave * 256) + (octave * 32)
            let attrY = y / 8
            
            for x in 0..<width {
                let xByte = x / 8, xBit = 7 - (x % 8)
                let bitmapByte = data[bitmapLineOffset + xByte]
                let pixelBit = (bitmapByte >> xBit) & 1
                
                let attrByte = data[6144 + (attrY * 32) + (x / 8)]
                let bright = (attrByte >> 6) & 1
                let paper = (attrByte >> 3) & 0x07, ink = attrByte & 0x07
                
                let colorIndex = (pixelBit == 1) ? Int(ink) + (bright == 1 ? 8 : 0) : Int(paper) + (bright == 1 ? 8 : 0)
                let rgb = zxSpectrumPalette[colorIndex]
                
                let bufferIdx = (y * width + x) * 4
                rgbaBuffer[bufferIdx] = rgb.r; rgbaBuffer[bufferIdx + 1] = rgb.g
                rgbaBuffer[bufferIdx + 2] = rgb.b; rgbaBuffer[bufferIdx + 3] = 255
            }
        }
        
        guard let cgImage = ImageHelpers.createCGImage(from: rgbaBuffer, width: width, height: height) else { return (nil, .Unknown) }
        return (cgImage, .ZXSpectrum)
    }
    
    static func decodeAmstradCPC(data: Data) -> (image: CGImage?, type: AppleIIImageType) {
        // Accept 16KB files (allow some tolerance for headers or slight variations)
        guard data.count >= 16000 && data.count <= 17000 else { return (nil, .Unknown) }

        // Check for and skip 128-byte AMSDOS header if present
        // AMSDOS header: byte 0 = user number (0-15), bytes 1-8 = filename
        // File size with header would be ~16512 bytes (16384 + 128)
        var screenData = data
        var embeddedPalette: [Int]? = nil
        var detectedMode: Int? = nil

        if data.count > 16384 {
            // Likely has AMSDOS header - check for embedded palette in bytes 69-84
            embeddedPalette = extractEmbeddedPalette(from: data)
            screenData = data.subdata(in: 128..<data.count)

            // Detect mode from palette: if bytes 73-84 (palette entries 4-15) are all 0, it's Mode 1
            if data.count >= 85 {
                let paletteBytes4to15 = (73..<85).map { Int(data[$0]) }
                if paletteBytes4to15.allSatisfy({ $0 == 0 }) {
                    // Only 4 palette entries used → Mode 1
                    detectedMode = 1
                    // Trim palette to 4 entries for Mode 1
                    if var pal = embeddedPalette {
                        pal = Array(pal.prefix(4))
                        embeddedPalette = pal
                    }
                } else {
                    detectedMode = 0
                }
            }
        }

        // Fall back to pixel analysis if no palette-based detection
        let mode = detectedMode ?? detectCPCMode(data: screenData)

        if mode == 0 {
            if let result = decodeAmstradCPCMode0(data: screenData, palette: embeddedPalette) { return result }
        } else {
            if let result = decodeAmstradCPCMode1(data: screenData, palette: embeddedPalette) { return result }
        }
        return (nil, .Unknown)
    }

    /// Extract embedded palette from AMSDOS header bytes 69-84 (if present)
    private static func extractEmbeddedPalette(from data: Data) -> [Int]? {
        guard data.count >= 85 else { return nil }

        // Check if bytes 69-84 contain valid palette indices (0-26)
        // A valid palette would have all values <= 26
        var palette: [Int] = []
        for i in 69..<85 {
            let value = Int(data[i])
            if value > 26 {
                return nil  // Invalid palette value, no embedded palette
            }
            palette.append(value)
        }

        // Additional check: if all values are 0, it's probably not a real palette
        if palette.allSatisfy({ $0 == 0 }) {
            return nil
        }

        return palette
    }

    private static func detectCPCMode(data: Data) -> Int {
        // Analyze pixel patterns to determine if this is Mode 0 (16 colors) or Mode 1 (4 colors)
        // Mode 0: 2 pixels per byte, each pixel uses 4 bits (values 0-15)
        // Mode 1: 4 pixels per byte, each pixel uses 2 bits (values 0-3)

        // Sample some bytes and extract pixel values for both interpretations
        var mode0UniqueColors = Set<UInt8>()
        var mode1UniqueColors = Set<UInt8>()

        let sampleSize = min(2000, data.count)
        for i in 0..<sampleSize {
            let byte = data[i]

            // Mode 0: extract 2 nibbles (4-bit pixels)
            // CPC bit encoding (matching BitPast): byte bits 7,3,5,1 / 6,2,4,0 → colorIndex bits 0,1,2,3
            let nibble0: UInt8 = ((byte >> 7) & 1) | ((byte >> 3) & 1) << 1 | ((byte >> 5) & 1) << 2 | ((byte >> 1) & 1) << 3
            let nibble1: UInt8 = ((byte >> 6) & 1) | ((byte >> 2) & 1) << 1 | ((byte >> 4) & 1) << 2 | (byte & 1) << 3
            mode0UniqueColors.insert(nibble0)
            mode0UniqueColors.insert(nibble1)

            // Mode 1: extract 4 bit-pairs (2-bit pixels)
            // CPC bit encoding: colorIndex bit 0 → higher byte bit position
            let pair0: UInt8 = ((byte >> 7) & 1) | ((byte >> 3) & 1) << 1
            let pair1: UInt8 = ((byte >> 6) & 1) | ((byte >> 2) & 1) << 1
            let pair2: UInt8 = ((byte >> 5) & 1) | ((byte >> 1) & 1) << 1
            let pair3: UInt8 = ((byte >> 4) & 1) | (byte & 1) << 1
            mode1UniqueColors.insert(pair0)
            mode1UniqueColors.insert(pair1)
            mode1UniqueColors.insert(pair2)
            mode1UniqueColors.insert(pair3)
        }

        // If Mode 0 shows more than 4 unique color values, it's likely Mode 0
        // Mode 1 can only have values 0-3, so if we see more variety in Mode 0, use Mode 0
        if mode0UniqueColors.count > 4 {
            return 0
        }
        return 1
    }

    private static func decodeAmstradCPCMode0(data: Data, palette: [Int]? = nil) -> (image: CGImage?, type: AppleIIImageType)? {
        let width = 160, height = 200
        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)
        // Default CPC Mode 0 palette (standard firmware defaults)
        let defaultPalette: [Int] = [1, 24, 20, 6, 26, 0, 2, 8, 10, 12, 14, 16, 18, 22, 24, 13]
        let usePalette = palette ?? defaultPalette

        // CPC screen memory: lines 0,8,16.. in block 0; lines 1,9,17.. in block 1, etc.
        // Block = y % 8, line within block = y / 8
        for y in 0..<height {
            let lineOffset = (y % 8) * 2048 + (y / 8) * 80
            for xByte in 0..<80 {
                if lineOffset + xByte >= data.count { continue }
                let dataByte = data[lineOffset + xByte]
                for pixel in 0..<2 {
                    let x = xByte * 2 + pixel
                    if x >= width { continue }
                    // CPC Mode 0 bit encoding (matching BitPast):
                    // Pixel 0: byte bits 7,3,5,1 → colorIndex bits 0,1,2,3
                    // Pixel 1: byte bits 6,2,4,0 → colorIndex bits 0,1,2,3
                    let nibble: UInt8 = pixel == 0 ?
                        ((dataByte >> 7) & 1) | ((dataByte >> 3) & 1) << 1 | ((dataByte >> 5) & 1) << 2 | ((dataByte >> 1) & 1) << 3 :
                        ((dataByte >> 6) & 1) | ((dataByte >> 2) & 1) << 1 | ((dataByte >> 4) & 1) << 2 | (dataByte & 1) << 3
                    let colorIndex = Int(nibble)
                    let hardwareColor = colorIndex < usePalette.count ? usePalette[colorIndex] : 0
                    let safeColor = min(hardwareColor, amstradCPCPalette.count - 1)
                    let rgb = amstradCPCPalette[safeColor]
                    let bufferIdx = (y * width + x) * 4
                    rgbaBuffer[bufferIdx] = rgb.r; rgbaBuffer[bufferIdx + 1] = rgb.g
                    rgbaBuffer[bufferIdx + 2] = rgb.b; rgbaBuffer[bufferIdx + 3] = 255
                }
            }
        }
        guard let cgImage = ImageHelpers.createCGImage(from: rgbaBuffer, width: width, height: height) else { return nil }
        return (cgImage, .AmstradCPC(mode: 0, colors: 16))
    }
    
    private static func decodeAmstradCPCMode1(data: Data, palette: [Int]? = nil) -> (image: CGImage?, type: AppleIIImageType)? {
        let width = 320, height = 200
        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)
        // Default CPC Mode 1 palette (standard firmware: blue, yellow, cyan, red)
        let defaultPalette: [Int] = [1, 24, 20, 6]
        let usePalette = palette ?? defaultPalette

        // CPC screen memory: lines 0,8,16.. in block 0; lines 1,9,17.. in block 1, etc.
        for y in 0..<height {
            let lineOffset = (y % 8) * 2048 + (y / 8) * 80
            for xByte in 0..<80 {
                if lineOffset + xByte >= data.count { continue }
                let dataByte = data[lineOffset + xByte]
                for pixel in 0..<4 {
                    let x = xByte * 4 + pixel
                    if x >= width { continue }
                    // CPC Mode 1 bit encoding: colorIndex bit 0 → higher byte bit position
                    // Pixel 0: bits 7,3; Pixel 1: bits 6,2; Pixel 2: bits 5,1; Pixel 3: bits 4,0
                    // bit 7/6/5/4 → colorIndex bit 0, bit 3/2/1/0 → colorIndex bit 1
                    let bitPair: UInt8
                    switch pixel {
                    case 0: bitPair = ((dataByte >> 7) & 1) | ((dataByte >> 3) & 1) << 1
                    case 1: bitPair = ((dataByte >> 6) & 1) | ((dataByte >> 2) & 1) << 1
                    case 2: bitPair = ((dataByte >> 5) & 1) | ((dataByte >> 1) & 1) << 1
                    default: bitPair = ((dataByte >> 4) & 1) | (dataByte & 1) << 1
                    }
                    let colorIndex = Int(bitPair)
                    let hardwareColor = colorIndex < usePalette.count ? usePalette[colorIndex] : 0
                    let safeColor = min(hardwareColor, amstradCPCPalette.count - 1)
                    let rgb = amstradCPCPalette[safeColor]
                    let bufferIdx = (y * width + x) * 4
                    rgbaBuffer[bufferIdx] = rgb.r; rgbaBuffer[bufferIdx + 1] = rgb.g
                    rgbaBuffer[bufferIdx + 2] = rgb.b; rgbaBuffer[bufferIdx + 3] = 255
                }
            }
        }
        guard let cgImage = ImageHelpers.createCGImage(from: rgbaBuffer, width: width, height: height) else { return nil }
        return (cgImage, .AmstradCPC(mode: 1, colors: 4))
    }
    
    static func decodeMacPaint(data: Data) -> (image: CGImage?, type: AppleIIImageType) {
        guard data.count >= 512 else { return (nil, .Unknown) }
        let width = 576, height = 720, bytesPerRow = 72
        let expectedSize = bytesPerRow * height
        
        let compressed = Array(data[512...])
        var decompressed: [UInt8] = []
        var offset = 0
        
        while offset < compressed.count && decompressed.count < expectedSize {
            let byte = compressed[offset]; offset += 1
            if byte >= 128 {
                let count = 257 - Int(byte)
                if offset < compressed.count { let value = compressed[offset]; offset += 1; for _ in 0..<count { decompressed.append(value) } }
            } else {
                let count = Int(byte) + 1
                for _ in 0..<count { if offset < compressed.count { decompressed.append(compressed[offset]); offset += 1 } }
            }
        }
        
        guard decompressed.count >= expectedSize * 4 / 5 else { return (nil, .Unknown) }
        
        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let byteIndex = y * bytesPerRow + (x / 8)
                if byteIndex < decompressed.count {
                    let bit = (decompressed[byteIndex] >> (7 - (x % 8))) & 1
                    let color: UInt8 = (bit == 1) ? 0 : 255
                    let bufferIdx = (y * width + x) * 4
                    rgbaBuffer[bufferIdx] = color; rgbaBuffer[bufferIdx + 1] = color
                    rgbaBuffer[bufferIdx + 2] = color; rgbaBuffer[bufferIdx + 3] = 255
                }
            }
        }
        guard let cgImage = ImageHelpers.createCGImage(from: rgbaBuffer, width: width, height: height) else { return (nil, .Unknown) }
        return (cgImage, .MacPaint)
    }
}
