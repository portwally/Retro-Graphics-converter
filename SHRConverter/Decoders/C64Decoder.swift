import Foundation
import CoreGraphics

// MARK: - Commodore 64 Decoder

class C64Decoder {
    
    // C64 Color Palette (16 colors)
    static let palette: [(r: UInt8, g: UInt8, b: UInt8)] = [
        (0x00, 0x00, 0x00),  // 0: Black
        (0xFF, 0xFF, 0xFF),  // 1: White
        (0x68, 0x37, 0x2B),  // 2: Red
        (0x70, 0xA4, 0xB2),  // 3: Cyan
        (0x6F, 0x3D, 0x86),  // 4: Purple
        (0x58, 0x8D, 0x43),  // 5: Green
        (0x35, 0x28, 0x79),  // 6: Blue
        (0xB8, 0xC7, 0x6F),  // 7: Yellow
        (0x6F, 0x4F, 0x25),  // 8: Orange
        (0x43, 0x39, 0x00),  // 9: Brown
        (0x9A, 0x67, 0x59),  // 10: Light Red
        (0x44, 0x44, 0x44),  // 11: Dark Grey
        (0x6C, 0x6C, 0x6C),  // 12: Grey
        (0x9A, 0xD2, 0x84),  // 13: Light Green
        (0x6C, 0x5E, 0xB5),  // 14: Light Blue
        (0x95, 0x95, 0x95)   // 15: Light Grey
    ]
    
    // MARK: - Koala Painter (.KOA, .KLA) - 10003 bytes
    
    static func decodeKoala(data: Data) -> (image: CGImage?, type: AppleIIImageType) {
        guard data.count >= 10003 && data.count <= 10010 else {
            return (nil, .Unknown)
        }
        
        let width = 320
        let height = 200
        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)
        
        let bitmapOffset = 2
        let screenRAMOffset = 8002
        let colorRAMOffset = 9002
        let backgroundOffset = 10002
        
        let backgroundColor = data[backgroundOffset] & 0x0F
        
        for cellY in 0..<25 {
            for cellX in 0..<40 {
                let cellIndex = cellY * 40 + cellX
                
                let screenByte = data[screenRAMOffset + cellIndex]
                let colorByte = data[colorRAMOffset + cellIndex]
                
                let color0 = backgroundColor
                let color1 = (screenByte >> 4) & 0x0F
                let color2 = screenByte & 0x0F
                let color3 = colorByte & 0x0F
                
                let colors = [color0, color1, color2, color3]
                
                for row in 0..<8 {
                    let bitmapByteOffset = bitmapOffset + (cellIndex * 8) + row
                    if bitmapByteOffset >= data.count { continue }
                    
                    let bitmapByte = data[bitmapByteOffset]
                    let y = cellY * 8 + row
                    
                    for pixelPair in 0..<4 {
                        let x = cellX * 8 + (pixelPair * 2)
                        let bitShift = 6 - (pixelPair * 2)
                        let colorIndex = Int((bitmapByte >> bitShift) & 0x03)
                        
                        let c64Color = Int(colors[colorIndex])
                        let rgb = palette[c64Color]
                        
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
        
        guard let cgImage = ImageHelpers.createCGImage(from: rgbaBuffer, width: width, height: height) else {
            return (nil, .Unknown)
        }
        
        return (cgImage, .C64(format: "Koala Painter"))
    }
    
    // MARK: - Art Studio (.ART, .OCP) - 10018 bytes
    
    static func decodeArtStudio(data: Data) -> (image: CGImage?, type: AppleIIImageType) {
        guard data.count == 10018 else {
            return (nil, .Unknown)
        }
        
        let width = 320
        let height = 200
        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)
        
        let bitmapOffset = 2
        let screenRAMOffset = 8002
        let colorRAMOffset = 9002
        let backgroundOffset = 10002
        
        let backgroundColor = data[backgroundOffset] & 0x0F
        
        for cellY in 0..<25 {
            for cellX in 0..<40 {
                let cellIndex = cellY * 40 + cellX
                
                let screenByte = data[screenRAMOffset + cellIndex]
                let colorByte = data[colorRAMOffset + cellIndex]
                
                let color0 = backgroundColor
                let color1 = (screenByte >> 4) & 0x0F
                let color2 = screenByte & 0x0F
                let color3 = colorByte & 0x0F
                
                let colors = [color0, color1, color2, color3]
                
                for row in 0..<8 {
                    let bitmapByteOffset = bitmapOffset + (cellIndex * 8) + row
                    if bitmapByteOffset >= data.count { continue }
                    
                    let bitmapByte = data[bitmapByteOffset]
                    let y = cellY * 8 + row
                    
                    for pixelPair in 0..<4 {
                        let x = cellX * 8 + (pixelPair * 2)
                        let bitShift = 6 - (pixelPair * 2)
                        let colorIndex = Int((bitmapByte >> bitShift) & 0x03)
                        
                        let c64Color = Int(colors[colorIndex])
                        let rgb = palette[c64Color]
                        
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
        
        guard let cgImage = ImageHelpers.createCGImage(from: rgbaBuffer, width: width, height: height) else {
            return (nil, .Unknown)
        }
        
        return (cgImage, .C64(format: "C64 Multicolor (10018 bytes)"))
    }
    
    // MARK: - Art Studio Hi-Res (.ART) - 9002 bytes

    static func decodeArtStudioHires(data: Data) -> (image: CGImage?, type: AppleIIImageType) {
        guard data.count == 9002 else {
            return (nil, .Unknown)
        }

        let width = 320
        let height = 200
        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)

        let bitmapOffset = 2      // After 2-byte load address
        let screenRAMOffset = 8002  // After bitmap (8000 bytes)

        for cellY in 0..<25 {
            for cellX in 0..<40 {
                let cellIndex = cellY * 40 + cellX

                let screenByte = data[screenRAMOffset + cellIndex]
                let fgColor = Int((screenByte >> 4) & 0x0F)
                let bgColor = Int(screenByte & 0x0F)

                for row in 0..<8 {
                    let bitmapByteOffset = bitmapOffset + (cellIndex * 8) + row
                    if bitmapByteOffset >= data.count { continue }

                    let bitmapByte = data[bitmapByteOffset]
                    let y = cellY * 8 + row

                    for bit in 0..<8 {
                        let x = cellX * 8 + bit
                        let bitVal = (bitmapByte >> (7 - bit)) & 1
                        let colorIndex = (bitVal == 1) ? fgColor : bgColor

                        let rgb = palette[colorIndex]
                        let bufferIdx = (y * width + x) * 4

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

        guard let cgImage = ImageHelpers.createCGImage(from: rgbaBuffer, width: width, height: height) else {
            return (nil, .Unknown)
        }

        return (cgImage, .C64(format: "Art Studio Hi-Res"))
    }

    // MARK: - HIRES - 9009 bytes

    static func decodeHires(data: Data) -> (image: CGImage?, type: AppleIIImageType) {
        guard data.count == 9009 else {
            return (nil, .Unknown)
        }
        
        let width = 320
        let height = 200
        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)
        
        let bitmapOffset = 2
        let screenRAMOffset = 8002
        
        for cellY in 0..<25 {
            for cellX in 0..<40 {
                let cellIndex = cellY * 40 + cellX
                
                let screenByte = data[screenRAMOffset + cellIndex]
                let bgColor = Int((screenByte >> 4) & 0x0F)
                let fgColor = Int(screenByte & 0x0F)
                
                for row in 0..<8 {
                    let bitmapByteOffset = bitmapOffset + (cellIndex * 8) + row
                    if bitmapByteOffset >= data.count { continue }
                    
                    let bitmapByte = data[bitmapByteOffset]
                    let y = cellY * 8 + row
                    
                    for bit in 0..<8 {
                        let x = cellX * 8 + bit
                        let bitVal = (bitmapByte >> (7 - bit)) & 1
                        let colorIndex = (bitVal == 0) ? fgColor : bgColor
                        
                        let rgb = palette[colorIndex]
                        let bufferIdx = (y * width + x) * 4
                        
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
        
        guard let cgImage = ImageHelpers.createCGImage(from: rgbaBuffer, width: width, height: height) else {
            return (nil, .Unknown)
        }
        
        return (cgImage, .C64(format: "C64 HIRES"))
    }
}
