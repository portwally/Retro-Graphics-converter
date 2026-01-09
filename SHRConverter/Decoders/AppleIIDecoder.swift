import Foundation
import CoreGraphics

// MARK: - Apple II Graphics Decoder

class AppleIIDecoder {
    
    // MARK: - SHR Decoder (320x200, 32KB)
    
    static func decodeSHR(data: Data, is3200Color: Bool) -> CGImage? {
        let width = 320
        let height = 200
        var rgbaBuffer = [UInt8](repeating: 255, count: width * height * 4)
        
        let pixelDataStart = 0
        let scbOffset = 32000
        let standardPaletteOffset = 32256
        let brooksPaletteOffset = 32000
        
        if !is3200Color {
            var palettes = [[(r: UInt8, g: UInt8, b: UInt8)]]()
            for i in 0..<16 {
                let pOffset = standardPaletteOffset + (i * 32)
                palettes.append(ImageHelpers.readPalette(from: data, offset: pOffset, reverseOrder: false))
            }
            
            for y in 0..<height {
                let scb = data[scbOffset + y]
                let paletteIndex = Int(scb & 0x0F)
                let currentPalette = palettes[paletteIndex]
                renderLine(y: y, data: data, pixelStart: pixelDataStart, palette: currentPalette, to: &rgbaBuffer, width: width)
            }
            
        } else {
            for y in 0..<height {
                let pOffset = brooksPaletteOffset + (y * 32)
                let currentPalette = ImageHelpers.readPalette(from: data, offset: pOffset, reverseOrder: true)
                renderLine(y: y, data: data, pixelStart: pixelDataStart, palette: currentPalette, to: &rgbaBuffer, width: width)
            }
        }
        
        return ImageHelpers.createCGImage(from: rgbaBuffer, width: width, height: height)
    }
    
    private static func renderLine(y: Int, data: Data, pixelStart: Int, palette: [(r: UInt8, g: UInt8, b: UInt8)], to buffer: inout [UInt8], width: Int) {
        let bytesPerLine = 160
        let lineStart = pixelStart + (y * bytesPerLine)
        
        for xByte in 0..<bytesPerLine {
            let byte = data[lineStart + xByte]
            
            let idx1 = (byte & 0xF0) >> 4
            let idx2 = (byte & 0x0F)
            
            let c1 = palette[Int(idx1)]
            let bufferIdx1 = (y * width + (xByte * 2)) * 4
            buffer[bufferIdx1]     = c1.r
            buffer[bufferIdx1 + 1] = c1.g
            buffer[bufferIdx1 + 2] = c1.b
            buffer[bufferIdx1 + 3] = 255
            
            let c2 = palette[Int(idx2)]
            let bufferIdx2 = (y * width + (xByte * 2) + 1) * 4
            buffer[bufferIdx2]     = c2.r
            buffer[bufferIdx2 + 1] = c2.g
            buffer[bufferIdx2 + 2] = c2.b
            buffer[bufferIdx2 + 3] = 255
        }
    }
    
    // MARK: - DHGR Decoder (560x192, 16KB)
    
    static func decodeDHGR(data: Data) -> CGImage? {
        let width = 560
        let height = 192
        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)
        
        guard data.count >= 16384 else { return nil }
        
        let mainData = data.subdata(in: 0..<8192)
        let auxData = data.subdata(in: 8192..<16384)
        
        let dhgrPalette: [(r: UInt8, g: UInt8, b: UInt8)] = [
            (0, 0, 0),           // 0: Black
            (134, 18, 192),      // 1: Lila/Violett
            (0, 101, 43),        // 2: Dunkelgrün
            (48, 48, 255),       // 3: Blau
            (165, 95, 0),        // 4: Braun
            (172, 172, 172),     // 5: Hellgrau
            (0, 226, 0),         // 6: Hellgrün
            (0, 255, 146),       // 7: Cyan
            (224, 0, 39),        // 8: Rot
            (223, 17, 212),      // 9: Magenta
            (81, 81, 81),        // 10: Dunkelgrau
            (78, 158, 255),      // 11: Hellblau
            (255, 39, 0),        // 12: Orange
            (255, 150, 153),     // 13: Rosa
            (255, 253, 0),       // 14: Gelb
            (255, 255, 255)      // 15: White
        ]
        
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
                let color = dhgrPalette[colorIndex]
                
                for _ in 0..<4 {
                    let bufferIdx = (y * width + pixelX) * 4
                    if bufferIdx + 3 < rgbaBuffer.count && pixelX < width {
                        rgbaBuffer[bufferIdx] = color.r
                        rgbaBuffer[bufferIdx + 1] = color.g
                        rgbaBuffer[bufferIdx + 2] = color.b
                        rgbaBuffer[bufferIdx + 3] = 255
                    }
                    pixelX += 1
                }
                
                bitIndex += 4
            }
        }
        
        guard let fullImage = ImageHelpers.createCGImage(from: rgbaBuffer, width: width, height: height) else {
            return nil
        }
        
        return SHRDecoder.scaleCGImage(fullImage, to: CGSize(width: 280, height: 192))
    }
    
    // MARK: - HGR Decoder (280x192, 8KB)
    
    static func decodeHGR(data: Data) -> CGImage? {
        let width = 280
        let height = 192
        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)
        
        let hgrColors: [(r: UInt8, g: UInt8, b: UInt8)] = [
            (0, 0, 0),       // 0: Schwarz
            (255, 255, 255), // 1: Weiß
            (32, 192, 32),   // 2: Grün
            (160, 32, 240),  // 3: Violett
            (255, 100, 0),   // 4: Orange
            (60, 60, 255)    // 5: Blau
        ]
        
        guard data.count >= 8184 else { return nil }

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
                        colorIndex = 0
                    } else if bitA == 1 && bitB == 1 {
                        colorIndex = 1
                    } else {
                        let isEvenColumn = (pixelIndex % 2) == 0
                        
                        if highBit == 1 {
                            if isEvenColumn {
                                colorIndex = (bitA == 1) ? 5 : 4
                            } else {
                                colorIndex = (bitA == 1) ? 4 : 5
                            }
                        } else {
                            if isEvenColumn {
                                colorIndex = (bitA == 1) ? 3 : 2
                            } else {
                                colorIndex = (bitA == 1) ? 2 : 3
                            }
                        }
                    }
                    
                    let c = hgrColors[colorIndex]
                    rgbaBuffer[bufferIdx] = c.r
                    rgbaBuffer[bufferIdx + 1] = c.g
                    rgbaBuffer[bufferIdx + 2] = c.b
                    rgbaBuffer[bufferIdx + 3] = 255
                }
            }
        }
        
        return ImageHelpers.createCGImage(from: rgbaBuffer, width: width, height: height)
    }
}
