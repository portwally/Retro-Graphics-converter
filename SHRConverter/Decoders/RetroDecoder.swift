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
    
    static let amstradCPCPalette: [(r: UInt8, g: UInt8, b: UInt8)] = [
        (0x00, 0x00, 0x00), (0x00, 0x00, 0x80), (0x00, 0x00, 0xFF), (0x80, 0x00, 0x00),
        (0x80, 0x00, 0x80), (0x80, 0x00, 0xFF), (0xFF, 0x00, 0x00), (0xFF, 0x00, 0x80),
        (0xFF, 0x00, 0xFF), (0x00, 0x80, 0x00), (0x00, 0x80, 0x80), (0x00, 0x80, 0xFF),
        (0x80, 0x80, 0x00), (0x80, 0x80, 0x80), (0x80, 0x80, 0xFF), (0xFF, 0x80, 0x00),
        (0xFF, 0x80, 0x80), (0xFF, 0x80, 0xFF), (0x00, 0xFF, 0x00), (0x00, 0xFF, 0x80),
        (0x00, 0xFF, 0xFF), (0x80, 0xFF, 0x00), (0x80, 0xFF, 0x80), (0x80, 0xFF, 0xFF),
        (0xFF, 0xFF, 0x00), (0xFF, 0xFF, 0x80), (0xFF, 0xFF, 0xFF)
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
        guard data.count == 16384 else { return (nil, .Unknown) }
        if let result = decodeAmstradCPCMode1(data: data) { return result }
        if let result = decodeAmstradCPCMode0(data: data) { return result }
        return (nil, .Unknown)
    }
    
    private static func decodeAmstradCPCMode0(data: Data) -> (image: CGImage?, type: AppleIIImageType)? {
        let width = 160, height = 200
        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)
        let defaultPalette: [Int] = [1, 24, 20, 6, 0, 26, 18, 8, 13, 25, 23, 17, 22, 16, 15, 14]
        
        for y in 0..<height {
            let lineOffset = (y / 8 * 2048) + (y % 8 * 80)
            for xByte in 0..<80 {
                if lineOffset + xByte >= data.count { continue }
                let dataByte = data[lineOffset + xByte]
                for pixel in 0..<2 {
                    let x = xByte * 2 + pixel
                    if x >= width { continue }
                    let nibble: UInt8 = pixel == 0 ?
                        ((dataByte >> 7) & 1) << 3 | ((dataByte >> 5) & 1) << 2 | ((dataByte >> 3) & 1) << 1 | ((dataByte >> 1) & 1) :
                        ((dataByte >> 6) & 1) << 3 | ((dataByte >> 4) & 1) << 2 | ((dataByte >> 2) & 1) << 1 | (dataByte & 1)
                    let rgb = amstradCPCPalette[defaultPalette[Int(nibble)]]
                    let bufferIdx = (y * width + x) * 4
                    rgbaBuffer[bufferIdx] = rgb.r; rgbaBuffer[bufferIdx + 1] = rgb.g
                    rgbaBuffer[bufferIdx + 2] = rgb.b; rgbaBuffer[bufferIdx + 3] = 255
                }
            }
        }
        guard let cgImage = ImageHelpers.createCGImage(from: rgbaBuffer, width: width, height: height) else { return nil }
        return (cgImage, .AmstradCPC(mode: 0, colors: 16))
    }
    
    private static func decodeAmstradCPCMode1(data: Data) -> (image: CGImage?, type: AppleIIImageType)? {
        let width = 320, height = 200
        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)
        let defaultPalette: [Int] = [1, 24, 20, 6]
        
        for y in 0..<height {
            let lineOffset = (y / 8 * 2048) + (y % 8 * 80)
            for xByte in 0..<80 {
                if lineOffset + xByte >= data.count { continue }
                let dataByte = data[lineOffset + xByte]
                for pixel in 0..<4 {
                    let x = xByte * 4 + pixel
                    if x >= width { continue }
                    let bitPair: UInt8
                    switch pixel {
                    case 0: bitPair = ((dataByte >> 7) & 1) << 1 | ((dataByte >> 3) & 1)
                    case 1: bitPair = ((dataByte >> 6) & 1) << 1 | ((dataByte >> 2) & 1)
                    case 2: bitPair = ((dataByte >> 5) & 1) << 1 | ((dataByte >> 1) & 1)
                    default: bitPair = ((dataByte >> 4) & 1) << 1 | (dataByte & 1)
                    }
                    let rgb = amstradCPCPalette[defaultPalette[Int(bitPair)]]
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
        
        var compressed = Array(data[512...])
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
