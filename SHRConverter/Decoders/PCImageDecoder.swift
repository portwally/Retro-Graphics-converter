import Foundation
import CoreGraphics

// MARK: - PC Image Decoder (PCX, BMP)

class PCImageDecoder {
    
    // MARK: - BMP Decoder
    
    static func decodeBMP(data: Data) -> (image: CGImage?, type: AppleIIImageType) {
        guard data.count >= 54, data[0] == 0x42, data[1] == 0x4D else { return (nil, .Unknown) }
        
        let dibHeaderSize = Int(data[14]) | (Int(data[15]) << 8) | (Int(data[16]) << 16) | (Int(data[17]) << 24)
        let width = Int(data[18]) | (Int(data[19]) << 8) | (Int(data[20]) << 16) | (Int(data[21]) << 24)
        var height = Int(data[22]) | (Int(data[23]) << 8) | (Int(data[24]) << 16) | (Int(data[25]) << 24)
        let topDown = height < 0; if topDown { height = -height }
        let bitsPerPixel = Int(data[28]) | (Int(data[29]) << 8)
        let compression = Int(data[30]) | (Int(data[31]) << 8) | (Int(data[32]) << 16) | (Int(data[33]) << 24)
        
        guard compression == 0, width > 0, height > 0, width < 10000, height < 10000 else { return (nil, .Unknown) }
        
        let pixelDataOffset = Int(data[10]) | (Int(data[11]) << 8) | (Int(data[12]) << 16) | (Int(data[13]) << 24)
        
        var palette: [(r: UInt8, g: UInt8, b: UInt8)] = []
        if bitsPerPixel <= 8 {
            let numColors = 1 << bitsPerPixel
            let paletteOffset = 14 + dibHeaderSize
            for i in 0..<numColors {
                let offset = paletteOffset + (i * 4)
                if offset + 3 < data.count {
                    palette.append((data[offset + 2], data[offset + 1], data[offset]))
                }
            }
        }
        
        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)
        let rowSize = ((bitsPerPixel * width + 31) / 32) * 4
        
        for y in 0..<height {
            let actualY = topDown ? y : (height - 1 - y)
            let rowOffset = pixelDataOffset + (y * rowSize)
            
            for x in 0..<width {
                var r: UInt8 = 0, g: UInt8 = 0, b: UInt8 = 0
                
                switch bitsPerPixel {
                case 24:
                    let pixelOffset = rowOffset + (x * 3)
                    if pixelOffset + 2 < data.count { b = data[pixelOffset]; g = data[pixelOffset + 1]; r = data[pixelOffset + 2] }
                case 8:
                    let pixelOffset = rowOffset + x
                    if pixelOffset < data.count, Int(data[pixelOffset]) < palette.count {
                        let c = palette[Int(data[pixelOffset])]; r = c.r; g = c.g; b = c.b
                    }
                case 4:
                    let byteOffset = rowOffset + (x / 2)
                    if byteOffset < data.count {
                        let paletteIndex = (x % 2 == 0) ? Int(data[byteOffset] >> 4) : Int(data[byteOffset] & 0x0F)
                        if paletteIndex < palette.count { let c = palette[paletteIndex]; r = c.r; g = c.g; b = c.b }
                    }
                case 1:
                    let byteOffset = rowOffset + (x / 8)
                    if byteOffset < data.count {
                        let bit = (data[byteOffset] >> (7 - (x % 8))) & 1
                        if Int(bit) < palette.count { let c = palette[Int(bit)]; r = c.r; g = c.g; b = c.b }
                    }
                default: break
                }
                
                let bufferIdx = (actualY * width + x) * 4
                rgbaBuffer[bufferIdx] = r; rgbaBuffer[bufferIdx + 1] = g; rgbaBuffer[bufferIdx + 2] = b; rgbaBuffer[bufferIdx + 3] = 255
            }
        }
        
        guard let cgImage = ImageHelpers.createCGImage(from: rgbaBuffer, width: width, height: height) else { return (nil, .Unknown) }
        return (cgImage, .BMP(width: width, height: height, bitsPerPixel: bitsPerPixel))
    }
    
    // MARK: - PCX Decoder
    
    static func decodePCX(data: Data) -> (image: CGImage?, type: AppleIIImageType) {
        guard data.count >= 128, data[0] == 0x0A else { return (nil, .Unknown) }
        
        let bitsPerPixel = data[3]
        let xMin = Int(data[4]) | (Int(data[5]) << 8), yMin = Int(data[6]) | (Int(data[7]) << 8)
        let xMax = Int(data[8]) | (Int(data[9]) << 8), yMax = Int(data[10]) | (Int(data[11]) << 8)
        let width = xMax - xMin + 1, height = yMax - yMin + 1
        let numPlanes = data[65], bytesPerLine = Int(data[66]) | (Int(data[67]) << 8)
        
        guard width > 0, height > 0, width < 10000, height < 10000 else { return (nil, .Unknown) }
        
        var totalBitsPerPixel = Int(bitsPerPixel) * Int(numPlanes)
        if totalBitsPerPixel == 0 && bitsPerPixel > 0 { totalBitsPerPixel = Int(bitsPerPixel) }
        
        // Decompress
        var decompressedData: [UInt8] = []
        var offset = 128
        let expectedSize = numPlanes == 0 ? bytesPerLine * height : bytesPerLine * Int(numPlanes) * height
        
        while offset < data.count && decompressedData.count < expectedSize {
            let byte = data[offset]; offset += 1
            if (byte & 0xC0) == 0xC0 {
                let count = Int(byte & 0x3F)
                if offset < data.count { let value = data[offset]; offset += 1; for _ in 0..<count { decompressedData.append(value) } }
            } else { decompressedData.append(byte) }
        }
        
        // Read palette
        var palette: [(r: UInt8, g: UInt8, b: UInt8)] = []
        if totalBitsPerPixel == 8 && data.count >= 769 {
            let paletteMarkerOffset = data.count - 769
            if data[paletteMarkerOffset] == 0x0C {
                for i in 0..<256 {
                    palette.append((data[paletteMarkerOffset + 1 + i*3], data[paletteMarkerOffset + 2 + i*3], data[paletteMarkerOffset + 3 + i*3]))
                }
            }
        }
        if palette.isEmpty {
            if totalBitsPerPixel <= 4 { for i in 0..<16 { palette.append((data[16 + i*3], data[17 + i*3], data[18 + i*3])) } }
            else { for i in 0..<256 { let gray = UInt8(i); palette.append((gray, gray, gray)) } }
        }
        
        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)
        
        if totalBitsPerPixel == 8 && numPlanes == 1 {
            for y in 0..<height {
                for x in 0..<width {
                    let dataIndex = y * bytesPerLine + x
                    let paletteIndex = dataIndex < decompressedData.count ? min(Int(decompressedData[dataIndex]), palette.count - 1) : 0
                    let color = palette[paletteIndex]
                    let bufferIdx = (y * width + x) * 4
                    rgbaBuffer[bufferIdx] = color.r; rgbaBuffer[bufferIdx + 1] = color.g; rgbaBuffer[bufferIdx + 2] = color.b; rgbaBuffer[bufferIdx + 3] = 255
                }
            }
        } else if totalBitsPerPixel == 24 && numPlanes == 3 {
            for y in 0..<height {
                for x in 0..<width {
                    let rOffset = (y * bytesPerLine * 3) + x
                    let gOffset = rOffset + bytesPerLine, bOffset = gOffset + bytesPerLine
                    let r = rOffset < decompressedData.count ? decompressedData[rOffset] : 0
                    let g = gOffset < decompressedData.count ? decompressedData[gOffset] : 0
                    let b = bOffset < decompressedData.count ? decompressedData[bOffset] : 0
                    let bufferIdx = (y * width + x) * 4
                    rgbaBuffer[bufferIdx] = r; rgbaBuffer[bufferIdx + 1] = g; rgbaBuffer[bufferIdx + 2] = b; rgbaBuffer[bufferIdx + 3] = 255
                }
            }
        } else if totalBitsPerPixel == 2 || (Int(bitsPerPixel) == 2 && Int(numPlanes) <= 1) {
            let cgaPalette: [(r: UInt8, g: UInt8, b: UInt8)] = palette.count >= 4 ? Array(palette.prefix(4)) : [(0,0,0), (0,255,255), (255,0,255), (255,255,255)]
            for y in 0..<height {
                for x in 0..<width {
                    let byteIndex = y * bytesPerLine + (x / 4)
                    let pixelInByte = 3 - (x % 4)
                    if byteIndex < decompressedData.count {
                        let colorIndex = Int((decompressedData[byteIndex] >> (pixelInByte * 2)) & 0x03)
                        let color = cgaPalette[min(colorIndex, cgaPalette.count - 1)]
                        let bufferIdx = (y * width + x) * 4
                        rgbaBuffer[bufferIdx] = color.r; rgbaBuffer[bufferIdx + 1] = color.g; rgbaBuffer[bufferIdx + 2] = color.b; rgbaBuffer[bufferIdx + 3] = 255
                    }
                }
            }
        } else if totalBitsPerPixel <= 4 {
            for y in 0..<height {
                for x in 0..<width {
                    let byteIndex = y * bytesPerLine + (x / 8)
                    let bitIndex = 7 - (x % 8)
                    if byteIndex < decompressedData.count {
                        let bit = (decompressedData[byteIndex] >> bitIndex) & 1
                        let color = palette[Int(bit)]
                        let bufferIdx = (y * width + x) * 4
                        rgbaBuffer[bufferIdx] = color.r; rgbaBuffer[bufferIdx + 1] = color.g; rgbaBuffer[bufferIdx + 2] = color.b; rgbaBuffer[bufferIdx + 3] = 255
                    }
                }
            }
        }
        
        guard let cgImage = ImageHelpers.createCGImage(from: rgbaBuffer, width: width, height: height) else { return (nil, .Unknown) }
        return (cgImage, .PCX(width: width, height: height, bitsPerPixel: totalBitsPerPixel))
    }
}
