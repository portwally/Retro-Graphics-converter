import Foundation
import CoreGraphics
import ImageIO

// MARK: - Modern Image Decoder (PNG, JPEG, GIF, etc.)

class ModernImageDecoder {
    
    static func decode(data: Data, format: String) -> (image: CGImage?, type: AppleIIImageType) {
        guard let imageSource = CGImageSourceCreateWithData(data as CFData, nil),
              CGImageSourceGetCount(imageSource) > 0,
              let cgImage = CGImageSourceCreateImageAtIndex(imageSource, 0, nil) else {
            return (nil, .Unknown)
        }
        
        let width = cgImage.width
        let height = cgImage.height
        let formatName = format.uppercased()
        
        return (cgImage, .ModernImage(format: formatName, width: width, height: height))
    }
}
