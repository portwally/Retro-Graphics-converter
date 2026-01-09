import Foundation
import CoreGraphics
import ImageIO
import AppKit

// MARK: - SHRDecoder - Main Entry Point

class SHRDecoder {
    
    static func decode(data: Data, filename: String? = nil) -> (image: CGImage?, type: AppleIIImageType) {
        let size = data.count
        let fileExtension = filename?.split(separator: ".").last?.lowercased() ?? ""
        
        // Modern image formats (PNG, JPEG, GIF, etc.)
        let modernFormats = ["png", "jpg", "jpeg", "gif", "tiff", "tif", "heic", "heif", "webp"]
        if modernFormats.contains(fileExtension) {
            return ModernImageDecoder.decode(data: data, format: fileExtension)
        }
        
        // Magic byte detection
        if size >= 8 {
            if data[0] == 0x89 && data[1] == 0x50 && data[2] == 0x4E && data[3] == 0x47 {
                return ModernImageDecoder.decode(data: data, format: "png")
            }
            if data[0] == 0xFF && data[1] == 0xD8 {
                return ModernImageDecoder.decode(data: data, format: "jpeg")
            }
            if data[0] == 0x47 && data[1] == 0x49 && data[2] == 0x46 {
                return ModernImageDecoder.decode(data: data, format: "gif")
            }
        }
        
        // BMP format
        if size >= 14 && data[0] == 0x42 && data[1] == 0x4D {
            return PCImageDecoder.decodeBMP(data: data)
        }
        
        // PCX format
        if size >= 128 && data[0] == 0x0A {
            return PCImageDecoder.decodePCX(data: data)
        }
        
        // Apple IIgs PNT detection
        if let filename = filename?.lowercased() {
            if filename.contains("#c00000") {
                return PackedSHRDecoder.decodePNT0000(data: data)
            }
            if filename.contains("#c00001") {
                return PackedSHRDecoder.decodePNT0001(data: data)
            }
            if filename.contains("#c00002") {
                return PackedSHRDecoder.decodePNT0002(data: data)
            }
            
            if filename.hasSuffix(".pnt") {
                if let result = PackedSHRDecoder.detectAndDecodePNT(data: data) {
                    return result
                }
            }
        }

        // APF by signature
        if let result = PackedSHRDecoder.tryDecodeAPF(data: data) {
            return result
        }

        // IFF format (Amiga)
        if size >= 12 {
            if let headerString = String(data: data.subdata(in: 0..<4), encoding: .ascii), headerString == "FORM" {
                return AmigaIFFDecoder.decode(data: data)
            }
        }
        
        // C64 formats
        if size >= 10003 && size <= 10010 {
            return C64Decoder.decodeKoala(data: data)
        }
        
        switch size {
        case 10018:
            return C64Decoder.decodeArtStudio(data: data)
        case 9009:
            return C64Decoder.decodeHires(data: data)
        case 6912:
            return RetroDecoder.decodeZXSpectrum(data: data)
        case 16384:
            return handleSize16384(data: data, fileExtension: fileExtension)
        default:
            break
        }
        
        // MacPaint
        if fileExtension == "mac" || fileExtension == "pntg" {
            if size >= 512 {
                return RetroDecoder.decodeMacPaint(data: data)
            }
        }
        
        // Degas (Atari ST)
        if size >= 34 {
            let resolutionWord = ImageHelpers.readBigEndianUInt16(data: data, offset: 0)
            let isDegas = (resolutionWord <= 2) && (size == 32034 || size == 32066)
            if isDegas {
                return AtariSTDecoder.decodeDegas(data: data)
            }
        }
        
        // Apple II formats by size
        return decodeAppleIIBySize(data: data, size: size)
    }
    
    private static func handleSize16384(data: Data, fileExtension: String) -> (image: CGImage?, type: AppleIIImageType) {
        if fileExtension == "scr" {
            return RetroDecoder.decodeAmstradCPC(data: data)
        } else if fileExtension == "2mg" || fileExtension == "po" || fileExtension == "dsk" {
            return (AppleIIDecoder.decodeDHGR(data: data), .DHGR)
        }
        
        // Heuristics
        var cpcScore = 0
        var dhgrScore = 0
        
        for blockIdx in 0..<8 {
            let blockStart = blockIdx * 2048
            if blockStart + 100 < data.count {
                let blockData = data[blockStart..<(blockStart + 100)]
                if Set(blockData).count > 50 {
                    cpcScore += 1
                } else {
                    dhgrScore += 1
                }
            }
        }
        
        let firstKB = data.prefix(1024)
        if firstKB.filter({ $0 == 0 }).count > 512 {
            dhgrScore += 3
        }
        
        if cpcScore > dhgrScore + 2 {
            return RetroDecoder.decodeAmstradCPC(data: data)
        } else {
            return (AppleIIDecoder.decodeDHGR(data: data), .DHGR)
        }
    }
    
    private static func decodeAppleIIBySize(data: Data, size: Int) -> (image: CGImage?, type: AppleIIImageType) {
        switch size {
        case 32768:
            return (AppleIIDecoder.decodeSHR(data: data, is3200Color: false), .SHR(mode: "Standard"))
        case 38400...:
            return (AppleIIDecoder.decodeSHR(data: data, is3200Color: true), .SHR(mode: "3200 Color"))
        case 8184...8200:
            return (AppleIIDecoder.decodeHGR(data: data), .HGR)
        case 16384:
            return (AppleIIDecoder.decodeDHGR(data: data), .DHGR)
        default:
            // Last resort: MacPaint
            if size >= 20000 && size <= 100000 && size >= 512 {
                let result = RetroDecoder.decodeMacPaint(data: data)
                if result.image != nil {
                    return result
                }
            }
            return (nil, .Unknown)
        }
    }
    
    // MARK: - Image Scaling
    
    static func upscaleCGImage(_ image: CGImage, factor: Int) -> CGImage? {
        guard factor > 1 else { return image }
        let newWidth = image.width * factor
        let newHeight = image.height * factor
        return scaleCGImage(image, to: CGSize(width: newWidth, height: newHeight))
    }
    
    static func scaleCGImage(_ image: CGImage, to newSize: CGSize) -> CGImage? {
        guard let colorSpace = image.colorSpace else { return nil }

        guard let ctx = CGContext(
            data: nil,
            width: Int(newSize.width),
            height: Int(newSize.height),
            bitsPerComponent: image.bitsPerComponent,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: image.bitmapInfo.rawValue
        ) else { return nil }

        ctx.interpolationQuality = .none
        ctx.draw(image, in: CGRect(origin: .zero, size: newSize))
        return ctx.makeImage()
    }
}
