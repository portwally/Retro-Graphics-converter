import Foundation
import CoreGraphics

// MARK: - Image Helper Functions

class ImageHelpers {

    // MARK: - Filename Handling

    /// Lowercased extension of a filename, or "" when the name has no dot.
    /// (Splitting on "." would return the whole name for extension-less files like "PIC".)
    static func fileExtension(of filename: String?) -> String {
        guard let name = filename, let dot = name.lastIndex(of: ".") else { return "" }
        return name[name.index(after: dot)...].lowercased()
    }

    // MARK: - Big Endian Reading
    
    static func readBigEndianUInt32(data: Data, offset: Int) -> UInt32 {
        guard offset + 4 <= data.count else { return 0 }
        return (UInt32(data[offset]) << 24) |
               (UInt32(data[offset + 1]) << 16) |
               (UInt32(data[offset + 2]) << 8) |
               UInt32(data[offset + 3])
    }
    
    static func readBigEndianUInt16(data: Data, offset: Int) -> UInt16 {
        guard offset + 2 <= data.count else { return 0 }
        return (UInt16(data[offset]) << 8) | UInt16(data[offset + 1])
    }
    
    // MARK: - CGImage Creation
    
    static func createCGImage(from buffer: [UInt8], width: Int, height: Int) -> CGImage? {
        let bytesPerPixel = 4
        let bitsPerComponent = 8
        let bytesPerRow = width * bytesPerPixel
        let expectedSize = bytesPerRow * height
        
        guard buffer.count == expectedSize else {
            return nil
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        let bitmapInfo = CGBitmapInfo(rawValue:
            CGImageAlphaInfo.noneSkipLast.rawValue |
            CGBitmapInfo.byteOrder32Big.rawValue)
        
        guard let provider = CGDataProvider(data: Data(buffer) as CFData) else { return nil }
        
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bitsPerPixel: bytesPerPixel * bitsPerComponent,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }
    
    // MARK: - Bitmap Contexts

    /// A drawing context in the image's own pixel format, or plain 8-bit RGBA when Core Graphics
    /// cannot draw into that format (indexed, 16-bit or grayscale-with-alpha sources from PNG/GIF).
    static func makeBitmapContext(matching image: CGImage, width: Int, height: Int) -> CGContext? {
        guard width > 0, height > 0 else { return nil }

        if let colorSpace = image.colorSpace,
           let context = CGContext(data: nil, width: width, height: height,
                                   bitsPerComponent: image.bitsPerComponent, bytesPerRow: 0,
                                   space: colorSpace, bitmapInfo: image.bitmapInfo.rawValue) {
            return context
        }

        return CGContext(data: nil, width: width, height: height,
                         bitsPerComponent: 8, bytesPerRow: 0,
                         space: CGColorSpaceCreateDeviceRGB(),
                         bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
    }

    // MARK: - Palette Reading (Apple IIgs format)
    
    static func readPalette(from data: Data, offset: Int, reverseOrder: Bool) -> [(r: UInt8, g: UInt8, b: UInt8)] {
        var colors = [(r: UInt8, g: UInt8, b: UInt8)](repeating: (0,0,0), count: 16)
        
        for i in 0..<16 {
            let colorIdx = reverseOrder ? (15 - i) : i
            let byte1 = data[offset + (i * 2)]
            let byte2 = data[offset + (i * 2) + 1]
            
            let red4   = (byte2 & 0x0F)
            let green4 = (byte1 & 0xF0) >> 4
            let blue4  = (byte1 & 0x0F)
            
            let r = red4 * 17
            let g = green4 * 17
            let b = blue4 * 17
            
            colors[colorIdx] = (r, g, b)
        }
        return colors
    }
    
    // MARK: - Default Palette Generation
    
    static func generateDefaultPalette() -> [(r: UInt8, g: UInt8, b: UInt8)] {
        var palette: [(r: UInt8, g: UInt8, b: UInt8)] = []
        for i in 0..<16 {
            let gray = UInt8(i * 17)
            palette.append((r: gray, g: gray, b: gray))
        }
        return palette
    }
    
    
}
