import Foundation
import CoreGraphics

// MARK: - Atari ST Degas Decoder

class AtariSTDecoder {
    
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
}
