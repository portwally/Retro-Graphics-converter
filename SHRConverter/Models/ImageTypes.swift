import Foundation

// MARK: - Export Format Enum

enum ExportFormat: String, CaseIterable {
    case png = "PNG"
    case jpeg = "JPEG"
    case tiff = "TIFF"
    case gif = "GIF"
    case heic = "HEIC (HEIF)"
    case original = "Original"
    
    var fileExtension: String {
        switch self {
        case .png: return "png"
        case .jpeg: return "jpg"
        case .tiff: return "tiff"
        case .gif: return "gif"
        case .heic: return "heic"
        case .original: return "bin" // wird dynamisch basierend auf Dateityp gesetzt
        }
    }
}

// MARK: - Apple II Image Type Enum

enum AppleIIImageType: Equatable {
    case SHR(mode: String)
    case DHGR
    case HGR
    case IFF(width: Int, height: Int, colors: String)
    case DEGAS(resolution: String, colors: Int)
    case C64(format: String)
    case ZXSpectrum
    case AmstradCPC(mode: Int, colors: Int)
    case PCX(width: Int, height: Int, bitsPerPixel: Int)
    case BMP(width: Int, height: Int, bitsPerPixel: Int)
    case MacPaint
    case ModernImage(format: String, width: Int, height: Int)
    case Unknown
    
    var resolution: (width: Int, height: Int) {
        switch self {
        case .SHR: return (320, 200)
        case .DHGR: return (560, 192)
        case .HGR: return (280, 192)
        case .IFF(let width, let height, _): return (width, height)
        case .DEGAS(let res, _):
            switch res {
            case "Low": return (320, 200)
            case "Medium": return (640, 200)
            case "High": return (640, 400)
            default: return (0, 0)
            }
        case .C64: return (320, 200)
        case .ZXSpectrum: return (256, 192)
        case .AmstradCPC(let mode, _):
            switch mode {
            case 0: return (160, 200)
            case 1: return (320, 200)
            case 2: return (640, 200)
            default: return (0, 0)
            }
        case .PCX(let width, let height, _): return (width, height)
        case .BMP(let width, let height, _): return (width, height)
        case .MacPaint: return (576, 720)
        case .ModernImage(_, let width, let height): return (width, height)
        case .Unknown: return (0, 0)
        }
    }
    
    var displayName: String {
        switch self {
        case .SHR(let mode): return "SHR (\(mode))"
        case .DHGR: return "DHGR"
        case .HGR: return "HGR"
        case .IFF(_, _, let colors): return "IFF (\(colors))"
        case .DEGAS(let res, let colors): return "Degas (\(res), \(colors) colors)"
        case .C64(let format): return "C64 (\(format))"
        case .ZXSpectrum: return "ZX Spectrum"
        case .AmstradCPC(let mode, let colors): return "Amstrad CPC (Mode \(mode), \(colors) colors)"
        case .PCX(let width, let height, let bpp): return "PCX (\(width)x\(height), \(bpp)-bit)"
        case .BMP(let width, let height, let bpp): return "BMP (\(width)x\(height), \(bpp)-bit)"
        case .MacPaint: return "MacPaint (576x720, 1-bit)"
        case .ModernImage(let format, let width, let height): return "\(format) (\(width)x\(height))"
        case .Unknown: return "Unknown"
        }
    }
}
