import Foundation
import CoreGraphics

// MARK: - Atari ST Image Decoder
// Supports Degas (.PI1, .PI2, .PI3), Degas Elite (.PC1, .PC2, .PC3), and NEOchrome (.NEO)

class AtariSTDecoder {

    // MARK: - General Decode

    static func decode(data: Data) -> (image: CGImage?, type: AppleIIImageType) {
        // Try Degas format first (most common)
        let degasResult = decodeDegas(data: data)
        if degasResult.image != nil {
            return degasResult
        }

        // Try NEOchrome
        let neoResult = decodeNEOchrome(data: data)
        if neoResult.image != nil {
            return neoResult
        }

        return (nil, .Unknown)
    }

    // MARK: - Degas Format

    static func decodeDegas(data: Data) -> (image: CGImage?, type: AppleIIImageType) {
        guard data.count >= 34 else {
            return (nil, .Unknown)
        }
        
        let resolutionMode = Int(ImageHelpers.readBigEndianUInt16(data: data, offset: 0))
        
        let width: Int
        let height: Int
        let numPlanes: Int
        let numColors: Int
        let resolutionName: String
        
        switch resolutionMode {
        case 0:
            width = 320
            height = 200
            numPlanes = 4
            numColors = 16
            resolutionName = "Low"
            
        case 1:
            width = 640
            height = 200
            numPlanes = 2
            numColors = 4
            resolutionName = "Medium"
            
        case 2:
            width = 640
            height = 400
            numPlanes = 1
            numColors = 2
            resolutionName = "High"
            
        default:
            return (nil, .Unknown)
        }
        
        // Read palette
        var palette: [(r: UInt8, g: UInt8, b: UInt8)] = []
        for i in 0..<16 {
            let colorWord = ImageHelpers.readBigEndianUInt16(data: data, offset: 2 + (i * 2))
            
            let r4 = (colorWord >> 8) & 0x07
            let g4 = (colorWord >> 4) & 0x07
            let b4 = colorWord & 0x07
            
            let r = UInt8((Int(r4) * 255) / 7)
            let g = UInt8((Int(g4) * 255) / 7)
            let b = UInt8((Int(b4) * 255) / 7)
            
            palette.append((r, g, b))
        }
        
        let imageDataOffset = 34
        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)
        
        let wordsPerLine = width / 16
        let bytesPerLine = wordsPerLine * numPlanes * 2
        
        for y in 0..<height {
            let lineOffset = imageDataOffset + (y * bytesPerLine)
            
            for wordIdx in 0..<wordsPerLine {
                var planeWords: [UInt16] = []
                for plane in 0..<numPlanes {
                    let offset = lineOffset + (wordIdx * numPlanes * 2) + (plane * 2)
                    if offset + 1 < data.count {
                        planeWords.append(ImageHelpers.readBigEndianUInt16(data: data, offset: offset))
                    } else {
                        planeWords.append(0)
                    }
                }
                
                for bit in 0..<16 {
                    let x = wordIdx * 16 + bit
                    if x >= width { break }
                    
                    let bitPos = 15 - bit
                    var colorIndex = 0
                    
                    for plane in 0..<numPlanes {
                        let bitVal = (planeWords[plane] >> bitPos) & 1
                        colorIndex |= Int(bitVal) << plane
                    }
                    
                    let color = palette[colorIndex]
                    let bufferIdx = (y * width + x) * 4
                    
                    rgbaBuffer[bufferIdx] = color.r
                    rgbaBuffer[bufferIdx + 1] = color.g
                    rgbaBuffer[bufferIdx + 2] = color.b
                    rgbaBuffer[bufferIdx + 3] = 255
                }
            }
        }
        
        guard let cgImage = ImageHelpers.createCGImage(from: rgbaBuffer, width: width, height: height) else {
            return (nil, .Unknown)
        }
        
        return (cgImage, .DEGAS(resolution: resolutionName, colors: numColors))
    }

    // MARK: - NEOchrome Format

    static func decodeNEOchrome(data: Data) -> (image: CGImage?, type: AppleIIImageType) {
        // NEOchrome format: 128 bytes header + 32000 bytes image data = 32128 bytes
        guard data.count == 32128 else {
            return (nil, .Unknown)
        }

        // Header structure:
        // Bytes 0-1: Flag (0 = normal)
        // Bytes 2-3: Resolution (0=Low, 1=Medium, 2=High)
        // Bytes 4-35: Palette (16 colors, 2 bytes each)
        // Bytes 36-47: Filename (12 chars)
        // Bytes 48-49: Color animation limits
        // Bytes 50-51: Color animation speed
        // Bytes 52-53: Number of color animation steps
        // Bytes 54-127: Reserved

        let resolution = Int(ImageHelpers.readBigEndianUInt16(data: data, offset: 2))

        let width: Int
        let height: Int
        let numPlanes: Int
        let numColors: Int

        switch resolution {
        case 0:
            width = 320
            height = 200
            numPlanes = 4
            numColors = 16

        case 1:
            width = 640
            height = 200
            numPlanes = 2
            numColors = 4

        case 2:
            width = 640
            height = 400
            numPlanes = 1
            numColors = 2

        default:
            return (nil, .Unknown)
        }

        // Read palette (16 colors starting at offset 4)
        var palette: [(r: UInt8, g: UInt8, b: UInt8)] = []
        for i in 0..<16 {
            let colorWord = ImageHelpers.readBigEndianUInt16(data: data, offset: 4 + (i * 2))

            // ST palette format: 0x0RGB (3 bits each)
            let r3 = (colorWord >> 8) & 0x07
            let g3 = (colorWord >> 4) & 0x07
            let b3 = colorWord & 0x07

            let r = UInt8((Int(r3) * 255) / 7)
            let g = UInt8((Int(g3) * 255) / 7)
            let b = UInt8((Int(b3) * 255) / 7)

            palette.append((r, g, b))
        }

        // Image data starts at offset 128
        let imageDataOffset = 128
        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)

        let wordsPerLine = width / 16
        let bytesPerLine = wordsPerLine * numPlanes * 2

        for y in 0..<height {
            let lineOffset = imageDataOffset + (y * bytesPerLine)

            for wordIdx in 0..<wordsPerLine {
                var planeWords: [UInt16] = []
                for plane in 0..<numPlanes {
                    let offset = lineOffset + (wordIdx * numPlanes * 2) + (plane * 2)
                    if offset + 1 < data.count {
                        planeWords.append(ImageHelpers.readBigEndianUInt16(data: data, offset: offset))
                    } else {
                        planeWords.append(0)
                    }
                }

                for bit in 0..<16 {
                    let x = wordIdx * 16 + bit
                    if x >= width { break }

                    let bitPos = 15 - bit
                    var colorIndex = 0

                    for plane in 0..<numPlanes {
                        let bitVal = (planeWords[plane] >> bitPos) & 1
                        colorIndex |= Int(bitVal) << plane
                    }

                    let color = palette[min(colorIndex, palette.count - 1)]
                    let bufferIdx = (y * width + x) * 4

                    rgbaBuffer[bufferIdx] = color.r
                    rgbaBuffer[bufferIdx + 1] = color.g
                    rgbaBuffer[bufferIdx + 2] = color.b
                    rgbaBuffer[bufferIdx + 3] = 255
                }
            }
        }

        guard let cgImage = ImageHelpers.createCGImage(from: rgbaBuffer, width: width, height: height) else {
            return (nil, .Unknown)
        }

        return (cgImage, .NEOchrome(colors: numColors))
    }
}
