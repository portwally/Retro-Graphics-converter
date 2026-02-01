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
    case SHR(mode: String, width: Int?, height: Int?)
    case DHGR
    case HGR
    case IFF(width: Int, height: Int, colors: String)
    case DEGAS(resolution: String, colors: Int)
    case NEOchrome(colors: Int)
    case C64(format: String)
    case Plus4(mode: String, colors: Int)
    case VIC20(mode: String, colors: Int)
    case ZXSpectrum
    case AmstradCPC(mode: Int, colors: Int)
    case PCX(width: Int, height: Int, bitsPerPixel: Int)
    case BMP(width: Int, height: Int, bitsPerPixel: Int)
    case MacPaint
    case MSX(mode: Int, colors: Int)
    case BBCMicro(mode: Int, colors: Int)
    case TRS80(model: String, resolution: String)
    case Atari8bit(mode: String, colors: Int)
    case ModernImage(format: String, width: Int, height: Int)
    case Unknown
    
    var resolution: (width: Int, height: Int) {
        switch self {
        case .SHR(_, let width, let height): 
            return (width ?? 320, height ?? 200)
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
        case .NEOchrome(let colors):
            switch colors {
            case 16: return (320, 200)
            case 4: return (640, 200)
            case 2: return (640, 400)
            default: return (320, 200)
            }
        case .C64: return (320, 200)
        case .Plus4(let mode, _):
            return mode == "Multicolor" ? (160, 200) : (320, 200)
        case .VIC20(let mode, _):
            return mode == "Multicolor" ? (88, 184) : (176, 184)
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
        case .MSX(let mode, _):
            switch mode {
            case 1: return (256, 192)  // Screen 1 (text/tile mode)
            case 2: return (256, 192)  // Screen 2 (Graphics 2)
            case 3: return (64, 48)    // Screen 3 (Multicolor)
            case 4: return (256, 212)  // Screen 4 (Graphics 3)
            case 5: return (256, 212)  // Screen 5 (Graphics 4)
            case 6: return (512, 212)  // Screen 6 (Graphics 5)
            case 7: return (512, 212)  // Screen 7 (Graphics 6)
            case 8: return (256, 212)  // Screen 8 (Graphics 7)
            default: return (256, 192)
            }
        case .BBCMicro(let mode, _):
            switch mode {
            case 0: return (640, 256)  // 2 colors
            case 1: return (320, 256)  // 4 colors
            case 2: return (160, 256)  // 16 colors (logical)
            case 4: return (320, 256)  // 2 colors
            case 5: return (160, 256)  // 4 colors
            default: return (320, 256)
            }
        case .TRS80(_, let resolution):
            if resolution.contains("128x48") { return (128, 48) }
            else if resolution.contains("256x192") { return (256, 192) }
            else if resolution.contains("320x200") { return (320, 200) }  // CoCo
            else if resolution.contains("640x200") { return (640, 200) }  // CoCo 3
            else { return (128, 48) }
        case .Atari8bit(let mode, _):
            switch mode {
            case "GR.8": return (320, 192)   // Hi-res 1-bit
            case "GR.9": return (160, 192)   // GTIA 16 shades (80 native, 2x display)
            case "GR.10": return (160, 192)  // GTIA 9 colors (80 native, 2x display)
            case "GR.11": return (160, 192)  // GTIA 16 colors (80 native, 2x display)
            case "GR.15", "GR.7": return (160, 192)  // 4-color
            case "MIC": return (160, 192)    // MicroIllustrator
            default: return (160, 192)
            }
        case .ModernImage(_, let width, let height): return (width, height)
        case .Unknown: return (0, 0)
        }
    }
    
    var displayName: String {
        switch self {
        case .SHR(let mode, _, _):
            // Format SHR names consistently
            if mode == "3200 Packed" {
                return "SHR 3200 Packed"
            } else if mode == "3200" {
                return "SHR 3200"
            } else if mode.contains("APF") {
                return "SHR (\(mode))"
            } else {
                return "SHR (\(mode))"
            }
        case .DHGR: return "DHGR"
        case .HGR: return "HGR"
        case .IFF(_, _, let colors): return "IFF (\(colors))"
        case .DEGAS(let res, let colors): return "Degas (\(res), \(colors) colors)"
        case .NEOchrome(let colors): return "NEOchrome (\(colors) colors)"
        case .C64(let format): return "C64 (\(format))"
        case .Plus4(let mode, _): return "Plus/4 (\(mode))"
        case .VIC20(let mode, _): return "VIC-20 (\(mode))"
        case .ZXSpectrum: return "ZX Spectrum"
        case .AmstradCPC(let mode, let colors): return "Amstrad CPC (Mode \(mode), \(colors) colors)"
        case .PCX(let width, let height, let bpp): return "PCX (\(width)x\(height), \(bpp)-bit)"
        case .BMP(let width, let height, let bpp): return "BMP (\(width)x\(height), \(bpp)-bit)"
        case .MacPaint: return "MacPaint (576x720, 1-bit)"
        case .MSX(let mode, let colors): return "MSX Screen \(mode) (\(colors) colors)"
        case .BBCMicro(let mode, let colors): return "BBC Micro MODE \(mode) (\(colors) colors)"
        case .TRS80(let model, let resolution): return "TRS-80 \(model) (\(resolution))"
        case .Atari8bit(let mode, let colors): return "Atari 8-bit \(mode) (\(colors) colors)"
        case .ModernImage(let format, let width, let height): return "\(format) (\(width)x\(height))"
        case .Unknown: return "Unknown"
        }
    }

    var colorDepth: String {
        switch self {
        case .SHR(let mode, _, _):
            if mode.contains("3200") {
                return "12-bit (3200 colors)"
            } else if mode.contains("640") {
                return "2-bit (4 colors)"
            } else if mode.contains("DreamGrafix") && !mode.contains("3200") {
                return "8-bit (256 colors)"
            } else {
                return "4-bit (16 colors)"
            }
        case .DHGR: return "4-bit (16 colors)"
        case .HGR: return "1-bit (6 colors)"
        case .IFF(_, _, let colors): return colors
        case .DEGAS(_, let colors): return "\(colors) colors"
        case .NEOchrome(let colors): return "\(colors) colors"
        case .C64(let format):
            if format.contains("FLI") || format.contains("Multicolor") {
                return "4-bit (16 colors)"
            } else {
                return "1-bit (2 colors)"
            }
        case .Plus4(_, let colors): return "\(colors) colors"
        case .VIC20(_, let colors): return "\(colors) colors"
        case .ZXSpectrum: return "3-bit (8 colors)"
        case .AmstradCPC(_, let colors): return "\(colors) colors"
        case .PCX(_, _, let bpp): return "\(bpp)-bit"
        case .BMP(_, _, let bpp): return "\(bpp)-bit"
        case .MacPaint: return "1-bit (2 colors)"
        case .MSX(_, let colors): return "\(colors) colors"
        case .BBCMicro(_, let colors): return "\(colors) colors"
        case .TRS80: return "1-bit (2 colors)"
        case .Atari8bit(_, let colors): return "\(colors) colors"
        case .ModernImage(let format, _, _):
            switch format.uppercased() {
            case "PNG", "TIFF": return "24-bit/32-bit"
            case "JPEG": return "24-bit"
            case "GIF": return "8-bit (256 colors)"
            default: return "24-bit"
            }
        case .Unknown: return "Unknown"
        }
    }
}
