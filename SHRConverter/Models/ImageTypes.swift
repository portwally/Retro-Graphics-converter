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
        case .original: return "bin" // set dynamically based on file type
        }
    }
}

// MARK: - Apple II Image Type Enum

enum AppleIIImageType: Equatable, Sendable {
    case SHR(mode: String, width: Int?, height: Int?)
    case DHGR
    case HGR
    case IFF(width: Int, height: Int, colors: String)
    case DEGAS(resolution: String, colors: Int)
    case NEOchrome(colors: Int)
    /// Other Atari ST formats (Art Director, GFA Artist, Doodle, Palette Master)
    case AtariSTPicture(format: String, width: Int, height: Int, colors: Int)
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

    var isKnown: Bool {
        if case .Unknown = self { return false }
        return true
    }

    /// Platform group used by the browser's filter menu
    var platformCategory: String {
        switch self {
        case .SHR, .DHGR, .HGR: return "Apple II"
        case .IFF: return "Amiga"
        case .DEGAS, .NEOchrome, .AtariSTPicture: return "Atari ST"
        case .C64: return "C64"
        case .Plus4: return "Plus/4"
        case .VIC20: return "VIC-20"
        case .ZXSpectrum: return "ZX Spectrum"
        case .AmstradCPC: return "CPC"
        case .PCX, .BMP: return "PC"
        case .MacPaint: return "Mac"
        case .MSX: return "MSX"
        case .BBCMicro: return "BBC Micro"
        case .TRS80: return "TRS-80"
        case .Atari8bit: return "Atari 8-bit"
        case .ModernImage: return "Modern"
        case .Unknown: return "Unknown"
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
        case .AtariSTPicture(let format, _, _, let colors): return "\(format) (\(colors) colors)"
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
}
