import Foundation
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// MARK: - HEIC Helper

class HEICConverter {
    static func convert(cgImage: CGImage) -> Data? {
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(mutableData, UTType.heic.identifier as CFString, 1, nil) else { return nil }
        
        let options: NSDictionary = [
            kCGImageDestinationLossyCompressionQuality: 0.9
        ]
        
        CGImageDestinationAddImage(destination, cgImage, options)
        
        guard CGImageDestinationFinalize(destination) else { return nil }
        
        return mutableData as Data
    }
}
