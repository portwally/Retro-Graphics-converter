import SwiftUI
import UniformTypeIdentifiers
import CoreGraphics
import ImageIO
import AppKit

// MARK: - Export Format Enum

enum ExportFormat: String, CaseIterable {
    case png = "PNG"
    case jpeg = "JPEG"
    case tiff = "TIFF"
    case gif = "GIF"
    case heic = "HEIC (HEIF)"
    
    var fileExtension: String {
        switch self {
        case .png: return "png"
        case .jpeg: return "jpg"
        case .tiff: return "tiff"
        case .gif: return "gif"
        case .heic: return "heic"
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

// MARK: - ProDOS FileType Detection

// ============================================================================
// OFFICIAL PRODOS FILETYPE & AUXTYPE DETECTION
// Based on official Apple ProDOS Technical Reference
// ============================================================================

struct ProDOSFileTypeInfo {
    let shortName: String
    let description: String
    let category: String
    let icon: String
    let isGraphics: Bool
    
    static func getFileTypeInfo(fileType: UInt8, auxType: Int? = nil) -> ProDOSFileTypeInfo {
        
        // Helper function for auxType matching
        func matchesAux(_ expected: Int) -> Bool {
            guard let aux = auxType else { return false }
            return aux == expected
        }
        
        switch fileType {
            
        // MARK: - Graphics Files
            
        case 0x08: // FOT - Graphics
            if let aux = auxType {
                switch aux {
                case 0x4000:
                    return ProDOSFileTypeInfo(shortName: "HGR", description: "Packed Hi-Res", category: "Graphics", icon: "🖼️", isGraphics: true)
                case 0x4001:
                    return ProDOSFileTypeInfo(shortName: "DHGR", description: "Packed Double Hi-Res", category: "Graphics", icon: "🖼️", isGraphics: true)
                case 0x8001:
                    return ProDOSFileTypeInfo(shortName: "HGR", description: "Printographer Packed HGR", category: "Graphics", icon: "🖼️", isGraphics: true)
                case 0x8002:
                    return ProDOSFileTypeInfo(shortName: "DHGR", description: "Printographer Packed DHGR", category: "Graphics", icon: "🖼️", isGraphics: true)
                case 0x8003:
                    return ProDOSFileTypeInfo(shortName: "HGR", description: "Softdisk Hi-Res", category: "Graphics", icon: "🖼️", isGraphics: true)
                case 0x8004:
                    return ProDOSFileTypeInfo(shortName: "DHGR", description: "Softdisk Double Hi-Res", category: "Graphics", icon: "🖼️", isGraphics: true)
                case 0x2000:
                    return ProDOSFileTypeInfo(shortName: "HGR", description: "Hi-Res Graphics", category: "Graphics", icon: "🖼️", isGraphics: true)
                default:
                    break
                }
            }
            return ProDOSFileTypeInfo(shortName: "FOT", description: "Apple II Graphics", category: "Graphics", icon: "🖼️", isGraphics: true)
            
        case 0xC0: // PNT - Packed Super Hi-Res
            if let aux = auxType {
                switch aux {
                case 0x0000:
                    return ProDOSFileTypeInfo(shortName: "PNT", description: "Paintworks Packed", category: "Graphics", icon: "🎨", isGraphics: true)
                case 0x0001:
                    return ProDOSFileTypeInfo(shortName: "SHR", description: "Packed Super Hi-Res", category: "Graphics", icon: "🖼️", isGraphics: true)
                case 0x0002:
                    return ProDOSFileTypeInfo(shortName: "PIC", description: "Apple Preferred Format", category: "Graphics", icon: "🖼️", isGraphics: true)
                case 0x0003:
                    return ProDOSFileTypeInfo(shortName: "PICT", description: "Packed QuickDraw II PICT", category: "Graphics", icon: "🖼️", isGraphics: true)
                case 0x8001:
                    return ProDOSFileTypeInfo(shortName: "PIC", description: "GTv Background", category: "Graphics", icon: "🖼️", isGraphics: true)
                case 0x8005:
                    return ProDOSFileTypeInfo(shortName: "DGX", description: "DreamGrafix", category: "Graphics", icon: "🎨", isGraphics: true)
                case 0x8006:
                    return ProDOSFileTypeInfo(shortName: "GIF", description: "GIF Image", category: "Graphics", icon: "🖼️", isGraphics: true)
                default:
                    break
                }
            }
            return ProDOSFileTypeInfo(shortName: "PNT", description: "Packed Super Hi-Res", category: "Graphics", icon: "🖼️", isGraphics: true)
            
        case 0xC1: // PIC - Super Hi-Res
            if let aux = auxType {
                switch aux {
                case 0x0000:
                    return ProDOSFileTypeInfo(shortName: "SHR", description: "Super Hi-Res Screen", category: "Graphics", icon: "🖼️", isGraphics: true)
                case 0x0001:
                    return ProDOSFileTypeInfo(shortName: "PICT", description: "QuickDraw PICT", category: "Graphics", icon: "🖼️", isGraphics: true)
                case 0x0002:
                    return ProDOSFileTypeInfo(shortName: "SHR", description: "SHR 3200 Color", category: "Graphics", icon: "🌈", isGraphics: true)
                case 0x8001:
                    return ProDOSFileTypeInfo(shortName: "IMG", description: "Allison Raw Image", category: "Graphics", icon: "🖼️", isGraphics: true)
                case 0x8002:
                    return ProDOSFileTypeInfo(shortName: "IMG", description: "ThunderScan", category: "Graphics", icon: "📸", isGraphics: true)
                case 0x8003:
                    return ProDOSFileTypeInfo(shortName: "DGX", description: "DreamGrafix", category: "Graphics", icon: "🎨", isGraphics: true)
                default:
                    break
                }
            }
            return ProDOSFileTypeInfo(shortName: "PIC", description: "Super Hi-Res Picture", category: "Graphics", icon: "🖼️", isGraphics: true)
            
        case 0xC2:
            return ProDOSFileTypeInfo(shortName: "ANI", description: "Paintworks Animation", category: "Graphics", icon: "🎬", isGraphics: true)
        case 0xC3:
            return ProDOSFileTypeInfo(shortName: "PAL", description: "Paintworks Palette", category: "Graphics", icon: "🎨", isGraphics: false)
            
        case 0x53: // DRW - Drawing
            if matchesAux(0x8010) {
                return ProDOSFileTypeInfo(shortName: "DRW", description: "AppleWorks GS Graphics", category: "Graphics", icon: "📐", isGraphics: true)
            }
            return ProDOSFileTypeInfo(shortName: "DRW", description: "Drawing", category: "Graphics", icon: "📐", isGraphics: true)
            
        case 0xC5: // OOG - Object Oriented Graphics
            if let aux = auxType {
                switch aux {
                case 0x8000:
                    return ProDOSFileTypeInfo(shortName: "DRW", description: "Draw Plus", category: "Graphics", icon: "📐", isGraphics: true)
                case 0xC000:
                    return ProDOSFileTypeInfo(shortName: "ARC", description: "DYOH Architecture", category: "Graphics", icon: "🏠", isGraphics: true)
                case 0xC006:
                    return ProDOSFileTypeInfo(shortName: "LND", description: "DYOH Landscape", category: "Graphics", icon: "🏞️", isGraphics: true)
                case 0xC007:
                    return ProDOSFileTypeInfo(shortName: "PYW", description: "PyWare", category: "Graphics", icon: "📐", isGraphics: true)
                default:
                    break
                }
            }
            return ProDOSFileTypeInfo(shortName: "OOG", description: "Object Graphics", category: "Graphics", icon: "📐", isGraphics: true)
            
        // MARK: - Text & Code
            
        case 0x00:
            return ProDOSFileTypeInfo(shortName: "NON", description: "Unknown", category: "General", icon: "❓", isGraphics: false)
        case 0x01:
            return ProDOSFileTypeInfo(shortName: "BAD", description: "Bad Blocks", category: "System", icon: "⚠️", isGraphics: false)
        case 0x04:
            return ProDOSFileTypeInfo(shortName: "TXT", description: "Text File", category: "Text", icon: "📄", isGraphics: false)
        case 0x06:
            return ProDOSFileTypeInfo(shortName: "BIN", description: "Binary", category: "Code", icon: "⚙️", isGraphics: false)
        case 0x07:
            return ProDOSFileTypeInfo(shortName: "FNT", description: "Apple III Font", category: "Font", icon: "🔤", isGraphics: false)
            
        case 0x02:
            return ProDOSFileTypeInfo(shortName: "PCD", description: "Pascal Code (SOS)", category: "Code", icon: "💻", isGraphics: false)
        case 0x03:
            return ProDOSFileTypeInfo(shortName: "PTX", description: "Pascal Text (SOS)", category: "Text", icon: "📄", isGraphics: false)
        case 0x05:
            return ProDOSFileTypeInfo(shortName: "PDA", description: "Pascal Data (SOS)", category: "Data", icon: "📄", isGraphics: false)
        case 0x09:
            return ProDOSFileTypeInfo(shortName: "BA3", description: "Apple III BASIC", category: "Code", icon: "💻", isGraphics: false)
        case 0x0A:
            return ProDOSFileTypeInfo(shortName: "DA3", description: "Apple III Data", category: "Data", icon: "📄", isGraphics: false)
            
        case 0x0B: // WPF - Word Processor
            if let aux = auxType {
                switch aux {
                case 0x8001:
                    return ProDOSFileTypeInfo(shortName: "WTW", description: "Write This Way", category: "Productivity", icon: "📝", isGraphics: false)
                case 0x8002:
                    return ProDOSFileTypeInfo(shortName: "W&P", description: "Writing & Publishing", category: "Productivity", icon: "📝", isGraphics: false)
                default:
                    break
                }
            }
            return ProDOSFileTypeInfo(shortName: "WPF", description: "Word Processor", category: "Productivity", icon: "📝", isGraphics: false)
            
        case 0x0C:
            return ProDOSFileTypeInfo(shortName: "SOS", description: "Apple III SOS System", category: "System", icon: "🗂️", isGraphics: false)
        case 0x0F:
            return ProDOSFileTypeInfo(shortName: "DIR", description: "Folder", category: "System", icon: "📁", isGraphics: false)
            
        case 0x10:
            return ProDOSFileTypeInfo(shortName: "RPD", description: "RPS Data", category: "Data", icon: "📄", isGraphics: false)
        case 0x11:
            return ProDOSFileTypeInfo(shortName: "RPI", description: "RPS Index", category: "Data", icon: "📄", isGraphics: false)
        case 0x12:
            return ProDOSFileTypeInfo(shortName: "AFD", description: "AppleFile Discard", category: "Data", icon: "📄", isGraphics: false)
        case 0x13:
            return ProDOSFileTypeInfo(shortName: "AFM", description: "AppleFile Model", category: "Data", icon: "📄", isGraphics: false)
        case 0x14:
            return ProDOSFileTypeInfo(shortName: "AFR", description: "AppleFile Report", category: "Data", icon: "📄", isGraphics: false)
        case 0x15:
            return ProDOSFileTypeInfo(shortName: "SCL", description: "Screen Library", category: "Data", icon: "📚", isGraphics: false)
            
        case 0x16: // PFS
            if let aux = auxType {
                switch aux {
                case 0x0001:
                    return ProDOSFileTypeInfo(shortName: "PFS", description: "PFS:File", category: "Productivity", icon: "📄", isGraphics: false)
                case 0x0002:
                    return ProDOSFileTypeInfo(shortName: "PFS", description: "PFS:Write", category: "Productivity", icon: "📝", isGraphics: false)
                case 0x0003:
                    return ProDOSFileTypeInfo(shortName: "PFS", description: "PFS:Graph", category: "Productivity", icon: "📊", isGraphics: false)
                case 0x0004:
                    return ProDOSFileTypeInfo(shortName: "PFS", description: "PFS:Plan", category: "Productivity", icon: "📊", isGraphics: false)
                default:
                    break
                }
            }
            return ProDOSFileTypeInfo(shortName: "PFS", description: "PFS Document", category: "Productivity", icon: "📄", isGraphics: false)
            
        // MARK: - AppleWorks (8-bit)
            
        case 0x19:
            return ProDOSFileTypeInfo(shortName: "ADB", description: "AppleWorks Database", category: "Productivity", icon: "🗂️", isGraphics: false)
        case 0x1A:
            return ProDOSFileTypeInfo(shortName: "AWP", description: "AppleWorks Word Proc", category: "Productivity", icon: "📝", isGraphics: false)
        case 0x1B:
            return ProDOSFileTypeInfo(shortName: "ASP", description: "AppleWorks Spreadsheet", category: "Productivity", icon: "📊", isGraphics: false)
            
        case 0x20:
            return ProDOSFileTypeInfo(shortName: "TDM", description: "Desktop Manager", category: "Productivity", icon: "🖥️", isGraphics: false)
            
        // MARK: - Apple II Source/Object Code
            
        case 0x2A:
            return ProDOSFileTypeInfo(shortName: "8SC", description: "Apple II Source Code", category: "Code", icon: "💻", isGraphics: false)
        case 0x2B:
            if matchesAux(0x8001) {
                return ProDOSFileTypeInfo(shortName: "8OB", description: "GBBS Pro Object", category: "Code", icon: "⚙️", isGraphics: false)
            }
            return ProDOSFileTypeInfo(shortName: "8OB", description: "Apple II Object Code", category: "Code", icon: "⚙️", isGraphics: false)
        case 0x2C:
            return ProDOSFileTypeInfo(shortName: "8IC", description: "Apple II Interpreted", category: "Code", icon: "💻", isGraphics: false)
        case 0x2D:
            return ProDOSFileTypeInfo(shortName: "8LD", description: "Apple II Language Data", category: "Code", icon: "📄", isGraphics: false)
        case 0x2E:
            return ProDOSFileTypeInfo(shortName: "P8C", description: "ProDOS 8 Module", category: "Code", icon: "⚙️", isGraphics: false)
            
        case 0x40:
            return ProDOSFileTypeInfo(shortName: "DIC", description: "Dictionary", category: "Data", icon: "📚", isGraphics: false)
        case 0x41:
            return ProDOSFileTypeInfo(shortName: "OCR", description: "OCR Data", category: "Data", icon: "📄", isGraphics: false)
        case 0x42:
            return ProDOSFileTypeInfo(shortName: "FTD", description: "File Type Names", category: "System", icon: "📋", isGraphics: false)
            
        // MARK: - Apple IIgs Productivity
            
        case 0x50: // GWP - GS Word Processing
            if let aux = auxType {
                switch aux {
                case 0x8010:
                    return ProDOSFileTypeInfo(shortName: "GWP", description: "AppleWorks GS WP", category: "Productivity", icon: "📝", isGraphics: false)
                case 0x5445:
                    return ProDOSFileTypeInfo(shortName: "TCH", description: "Teach Document", category: "Productivity", icon: "📝", isGraphics: false)
                case 0x8001:
                    return ProDOSFileTypeInfo(shortName: "DWR", description: "DeluxeWrite", category: "Productivity", icon: "📝", isGraphics: false)
                case 0x8003:
                    return ProDOSFileTypeInfo(shortName: "PJN", description: "Personal Journal", category: "Productivity", icon: "📔", isGraphics: false)
                default:
                    break
                }
            }
            return ProDOSFileTypeInfo(shortName: "GWP", description: "GS Word Processing", category: "Productivity", icon: "📝", isGraphics: false)
            
        case 0x51: // GSS - GS Spreadsheet
            if matchesAux(0x8010) {
                return ProDOSFileTypeInfo(shortName: "GSS", description: "AppleWorks GS SS", category: "Productivity", icon: "📊", isGraphics: false)
            }
            return ProDOSFileTypeInfo(shortName: "GSS", description: "GS Spreadsheet", category: "Productivity", icon: "📊", isGraphics: false)
            
        case 0x52: // GDB - GS Database
            if let aux = auxType {
                switch aux {
                case 0x8010:
                    return ProDOSFileTypeInfo(shortName: "GDB", description: "AppleWorks GS DB", category: "Productivity", icon: "🗂️", isGraphics: false)
                case 0x8013, 0x8014:
                    return ProDOSFileTypeInfo(shortName: "GSA", description: "GSAS Accounting", category: "Productivity", icon: "💰", isGraphics: false)
                default:
                    break
                }
            }
            return ProDOSFileTypeInfo(shortName: "GDB", description: "GS Database", category: "Productivity", icon: "🗂️", isGraphics: false)
            
        case 0x54: // GDP - Desktop Publishing
            if let aux = auxType {
                switch aux {
                case 0x8010:
                    return ProDOSFileTypeInfo(shortName: "GDP", description: "AppleWorks GS DTP", category: "Productivity", icon: "📰", isGraphics: false)
                case 0xDD3E:
                    return ProDOSFileTypeInfo(shortName: "MED", description: "Medley", category: "Productivity", icon: "📰", isGraphics: false)
                default:
                    break
                }
            }
            return ProDOSFileTypeInfo(shortName: "GDP", description: "Desktop Publishing", category: "Productivity", icon: "📰", isGraphics: false)
            
        // MARK: - Hypermedia & Education
            
        case 0x55: // HMD - Hypermedia
            if let aux = auxType {
                switch aux {
                case 0x0001:
                    return ProDOSFileTypeInfo(shortName: "HYP", description: "HyperCard GS Stack", category: "Hypermedia", icon: "📚", isGraphics: false)
                case 0x8002:
                    return ProDOSFileTypeInfo(shortName: "HYP", description: "HyperStudio", category: "Hypermedia", icon: "📚", isGraphics: false)
                case 0x8003:
                    return ProDOSFileTypeInfo(shortName: "NEX", description: "Nexus", category: "Hypermedia", icon: "📚", isGraphics: false)
                default:
                    break
                }
            }
            return ProDOSFileTypeInfo(shortName: "HMD", description: "Hypermedia", category: "Hypermedia", icon: "📚", isGraphics: false)
            
        case 0x56:
            return ProDOSFileTypeInfo(shortName: "EDU", description: "Educational Data", category: "Education", icon: "🎓", isGraphics: false)
        case 0x57:
            return ProDOSFileTypeInfo(shortName: "STN", description: "Stationery", category: "Productivity", icon: "📄", isGraphics: false)
        case 0x58:
            return ProDOSFileTypeInfo(shortName: "HLP", description: "Help File", category: "System", icon: "❓", isGraphics: false)
        case 0x59:
            return ProDOSFileTypeInfo(shortName: "COM", description: "Communications", category: "Communications", icon: "📡", isGraphics: false)
        case 0x5A:
            return ProDOSFileTypeInfo(shortName: "CFG", description: "Configuration", category: "System", icon: "⚙️", isGraphics: false)
            
        // MARK: - Multimedia & Animation
            
        case 0x5B:
            return ProDOSFileTypeInfo(shortName: "ANM", description: "Animation", category: "Multimedia", icon: "🎬", isGraphics: false)
        case 0x5C:
            return ProDOSFileTypeInfo(shortName: "MUM", description: "Multimedia", category: "Multimedia", icon: "🎭", isGraphics: false)
        case 0x5D:
            return ProDOSFileTypeInfo(shortName: "ENT", description: "Game/Entertainment", category: "Entertainment", icon: "🎮", isGraphics: false)
        case 0x5E:
            return ProDOSFileTypeInfo(shortName: "DVU", description: "Development Utility", category: "Development", icon: "🔧", isGraphics: false)
        case 0x5F:
            return ProDOSFileTypeInfo(shortName: "FIN", description: "Financial", category: "Productivity", icon: "💰", isGraphics: false)
            
        // MARK: - PC Transporter
            
        case 0x6B:
            return ProDOSFileTypeInfo(shortName: "BIO", description: "PC Transporter BIOS", category: "System", icon: "💾", isGraphics: false)
        case 0x6D:
            return ProDOSFileTypeInfo(shortName: "TDR", description: "PC Transporter Driver", category: "System", icon: "⚙️", isGraphics: false)
        case 0x6E:
            return ProDOSFileTypeInfo(shortName: "PRE", description: "PC Transporter Pre-boot", category: "System", icon: "💾", isGraphics: false)
        case 0x6F:
            return ProDOSFileTypeInfo(shortName: "HDV", description: "PC Transporter Volume", category: "System", icon: "💾", isGraphics: false)
            
        // MARK: - WordPerfect
            
        case 0xA0:
            return ProDOSFileTypeInfo(shortName: "WP", description: "WordPerfect", category: "Productivity", icon: "📝", isGraphics: false)
            
        // MARK: - BASIC
            
        case 0xAB:
            return ProDOSFileTypeInfo(shortName: "GSB", description: "IIGS BASIC Program", category: "Code", icon: "💻", isGraphics: false)
        case 0xAC:
            return ProDOSFileTypeInfo(shortName: "TDF", description: "IIGS BASIC TDF", category: "Code", icon: "📄", isGraphics: false)
        case 0xAD:
            return ProDOSFileTypeInfo(shortName: "BDF", description: "IIGS BASIC Data", category: "Data", icon: "📄", isGraphics: false)
            
        case 0xFA:
            return ProDOSFileTypeInfo(shortName: "INT", description: "Integer BASIC", category: "Code", icon: "💻", isGraphics: false)
        case 0xFB:
            return ProDOSFileTypeInfo(shortName: "IVR", description: "Integer Variables", category: "Data", icon: "📄", isGraphics: false)
        case 0xFC:
            return ProDOSFileTypeInfo(shortName: "BAS", description: "Applesoft BASIC", category: "Code", icon: "💻", isGraphics: false)
        case 0xFD:
            return ProDOSFileTypeInfo(shortName: "VAR", description: "Applesoft Variables", category: "Data", icon: "📄", isGraphics: false)
            
        // MARK: - Source Code & Development
            
        case 0xB0: // SRC - GS Source Code
            if let aux = auxType {
                switch aux {
                case 0x0001:
                    return ProDOSFileTypeInfo(shortName: "TXT", description: "APW Text", category: "Code", icon: "📄", isGraphics: false)
                case 0x0003:
                    return ProDOSFileTypeInfo(shortName: "ASM", description: "APW Assembly", category: "Code", icon: "💻", isGraphics: false)
                case 0x0005:
                    return ProDOSFileTypeInfo(shortName: "PAS", description: "ORCA Pascal", category: "Code", icon: "💻", isGraphics: false)
                case 0x0008:
                    return ProDOSFileTypeInfo(shortName: "C", description: "ORCA C", category: "Code", icon: "💻", isGraphics: false)
                case 0x000A:
                    return ProDOSFileTypeInfo(shortName: "C", description: "APW C", category: "Code", icon: "💻", isGraphics: false)
                case 0x0719:
                    return ProDOSFileTypeInfo(shortName: "PS", description: "PostScript", category: "Code", icon: "📄", isGraphics: false)
                default:
                    break
                }
            }
            return ProDOSFileTypeInfo(shortName: "SRC", description: "GS Source Code", category: "Code", icon: "💻", isGraphics: false)
            
        case 0xB1:
            return ProDOSFileTypeInfo(shortName: "OBJ", description: "GS Object Code", category: "Code", icon: "⚙️", isGraphics: false)
        case 0xB2:
            return ProDOSFileTypeInfo(shortName: "LIB", description: "GS Library", category: "Code", icon: "📚", isGraphics: false)
        case 0xB3:
            return ProDOSFileTypeInfo(shortName: "S16", description: "GS/OS Application", category: "System", icon: "📱", isGraphics: false)
        case 0xB4:
            return ProDOSFileTypeInfo(shortName: "RTL", description: "GS Runtime Library", category: "System", icon: "📚", isGraphics: false)
        case 0xB5:
            return ProDOSFileTypeInfo(shortName: "EXE", description: "GS Shell Application", category: "System", icon: "💻", isGraphics: false)
        case 0xB6:
            return ProDOSFileTypeInfo(shortName: "PIF", description: "Permanent Init File", category: "System", icon: "⚙️", isGraphics: false)
        case 0xB7:
            return ProDOSFileTypeInfo(shortName: "TIF", description: "Temporary Init File", category: "System", icon: "⚙️", isGraphics: false)
        case 0xB8:
            return ProDOSFileTypeInfo(shortName: "NDA", description: "New Desk Accessory", category: "System", icon: "🔧", isGraphics: false)
        case 0xB9:
            return ProDOSFileTypeInfo(shortName: "CDA", description: "Classic Desk Accessory", category: "System", icon: "🔧", isGraphics: false)
        case 0xBA:
            return ProDOSFileTypeInfo(shortName: "TOL", description: "Tool", category: "System", icon: "🔧", isGraphics: false)
        case 0xBB:
            return ProDOSFileTypeInfo(shortName: "DVR", description: "Device Driver", category: "System", icon: "⚙️", isGraphics: false)
        case 0xBC:
            return ProDOSFileTypeInfo(shortName: "LDF", description: "Load File", category: "System", icon: "📦", isGraphics: false)
        case 0xBD:
            return ProDOSFileTypeInfo(shortName: "FST", description: "File System Translator", category: "System", icon: "💾", isGraphics: false)
        case 0xBF:
            return ProDOSFileTypeInfo(shortName: "DOC", description: "GS/OS Document", category: "Document", icon: "📄", isGraphics: false)
            
        // MARK: - Scripts & Control Panels
            
        case 0xC6:
            return ProDOSFileTypeInfo(shortName: "SCR", description: "Script", category: "Code", icon: "📜", isGraphics: false)
        case 0xC7:
            return ProDOSFileTypeInfo(shortName: "CDV", description: "Control Panel", category: "System", icon: "⚙️", isGraphics: false)
            
        // MARK: - Fonts & Icons
            
        case 0xC8:
            if matchesAux(0x0001) {
                return ProDOSFileTypeInfo(shortName: "TTF", description: "TrueType Font", category: "Font", icon: "🔤", isGraphics: false)
            }
            return ProDOSFileTypeInfo(shortName: "FON", description: "Font", category: "Font", icon: "🔤", isGraphics: false)
        case 0xC9:
            return ProDOSFileTypeInfo(shortName: "FND", description: "Finder Data", category: "System", icon: "🔍", isGraphics: false)
        case 0xCA:
            return ProDOSFileTypeInfo(shortName: "ICN", description: "Icons", category: "Graphics", icon: "🎨", isGraphics: false)
            
        // MARK: - Sound & Music
            
        case 0xD5: // MUS - Music Sequence
            if let aux = auxType {
                switch aux {
                case 0x0000:
                    return ProDOSFileTypeInfo(shortName: "MCS", description: "Music Construction Set", category: "Multimedia", icon: "🎵", isGraphics: false)
                case 0x0007:
                    return ProDOSFileTypeInfo(shortName: "SND", description: "SoundSmith", category: "Multimedia", icon: "🎵", isGraphics: false)
                case 0x8003:
                    return ProDOSFileTypeInfo(shortName: "MTJ", description: "Master Tracks Jr", category: "Multimedia", icon: "🎵", isGraphics: false)
                default:
                    break
                }
            }
            return ProDOSFileTypeInfo(shortName: "MUS", description: "Music Sequence", category: "Multimedia", icon: "🎵", isGraphics: false)
            
        case 0xD6:
            return ProDOSFileTypeInfo(shortName: "INS", description: "Instrument", category: "Multimedia", icon: "🎹", isGraphics: false)
        case 0xD7:
            return ProDOSFileTypeInfo(shortName: "MDI", description: "MIDI Data", category: "Multimedia", icon: "🎵", isGraphics: false)
        case 0xD8:
            return ProDOSFileTypeInfo(shortName: "SND", description: "Sampled Sound", category: "Multimedia", icon: "🔊", isGraphics: false)
            
        // MARK: - Database
            
        case 0xDB:
            return ProDOSFileTypeInfo(shortName: "DBM", description: "DB Master", category: "Productivity", icon: "🗂️", isGraphics: false)
            
        // MARK: - Archives
            
        case 0xE0: // LBR - Archives
            if let aux = auxType {
                switch aux {
                case 0x8002:
                    return ProDOSFileTypeInfo(shortName: "SHK", description: "ShrinkIt (NuFX)", category: "Archive", icon: "📦", isGraphics: false)
                case 0x0005:
                    return ProDOSFileTypeInfo(shortName: "DC", description: "DiskCopy Image", category: "Archive", icon: "💾", isGraphics: false)
                case 0x8000:
                    return ProDOSFileTypeInfo(shortName: "BNY", description: "Binary II", category: "Archive", icon: "📦", isGraphics: false)
                default:
                    break
                }
            }
            return ProDOSFileTypeInfo(shortName: "LBR", description: "Archival Library", category: "Archive", icon: "📦", isGraphics: false)
            
        case 0xE2:
            return ProDOSFileTypeInfo(shortName: "ATK", description: "AppleTalk Data", category: "Communications", icon: "📡", isGraphics: false)
            
        // MARK: - Misc System
            
        case 0xEE:
            return ProDOSFileTypeInfo(shortName: "R16", description: "EDASM 816 Relocatable", category: "Code", icon: "⚙️", isGraphics: false)
        case 0xEF:
            return ProDOSFileTypeInfo(shortName: "PAS", description: "Pascal Area", category: "System", icon: "💾", isGraphics: false)
        case 0xF0:
            return ProDOSFileTypeInfo(shortName: "CMD", description: "BASIC Command", category: "Code", icon: "💻", isGraphics: false)
            
        // User Types
        case 0xF1:
            return ProDOSFileTypeInfo(shortName: "US1", description: "User #1", category: "User", icon: "👤", isGraphics: false)
        case 0xF2:
            return ProDOSFileTypeInfo(shortName: "US2", description: "User #2", category: "User", icon: "👤", isGraphics: false)
        case 0xF3:
            return ProDOSFileTypeInfo(shortName: "US3", description: "User #3", category: "User", icon: "👤", isGraphics: false)
        case 0xF4:
            return ProDOSFileTypeInfo(shortName: "US4", description: "User #4", category: "User", icon: "👤", isGraphics: false)
        case 0xF5:
            return ProDOSFileTypeInfo(shortName: "US5", description: "User #5", category: "User", icon: "👤", isGraphics: false)
        case 0xF6:
            return ProDOSFileTypeInfo(shortName: "US6", description: "User #6", category: "User", icon: "👤", isGraphics: false)
        case 0xF7:
            return ProDOSFileTypeInfo(shortName: "US7", description: "User #7", category: "User", icon: "👤", isGraphics: false)
        case 0xF8:
            return ProDOSFileTypeInfo(shortName: "US8", description: "User #8", category: "User", icon: "👤", isGraphics: false)
            
        // MARK: - System Files
            
        case 0xF9:
            return ProDOSFileTypeInfo(shortName: "OS", description: "GS/OS System", category: "System", icon: "🗂️", isGraphics: false)
        case 0xFE:
            return ProDOSFileTypeInfo(shortName: "REL", description: "Relocatable Code", category: "Code", icon: "⚙️", isGraphics: false)
        case 0xFF:
            return ProDOSFileTypeInfo(shortName: "SYS", description: "ProDOS 8 Application", category: "System", icon: "🗂️", isGraphics: false)
            
        // MARK: - Unknown
            
        default:
            return ProDOSFileTypeInfo(shortName: String(format: "$%02X", fileType), description: String(format: "Type $%02X", fileType), category: "Unknown", icon: "❓", isGraphics: false)
        }
    }
}


// MARK: - Disk Catalog Structures

struct DiskCatalogEntry: Identifiable {
    let id = UUID()
    let name: String
    let fileType: UInt8
    let fileTypeString: String
    let size: Int
    let blocks: Int?
    let loadAddress: Int?
    let length: Int?
    let data: Data
    let isImage: Bool
    let imageType: AppleIIImageType
    let isDirectory: Bool
    let children: [DiskCatalogEntry]?
    
    var sizeString: String {
        if size < 1024 {
            return "\(size) B"
        } else if size < 1024 * 1024 {
            return String(format: "%.1f KB", Double(size) / 1024.0)
        } else {
            return String(format: "%.1f MB", Double(size) / (1024.0 * 1024.0))
        }
    }
}
extension DiskCatalogEntry {
    var fileTypeInfo: ProDOSFileTypeInfo {
        return ProDOSFileTypeInfo.getFileTypeInfo(fileType: fileType, auxType: loadAddress)
    }
    
    // Ersetze die alten computed properties:
    var icon: String {
        if isDirectory { return "📁" }
        return fileTypeInfo.icon
    }
    
    var typeDescription: String {
        if isDirectory { return "Folder" }
        return fileTypeInfo.shortName
    }
}


struct DiskCatalog {
    let diskName: String
    let diskFormat: String
    let diskSize: Int
    let entries: [DiskCatalogEntry]
    
    var totalFiles: Int {
        countFiles(in: entries)
    }
    
    var imageFiles: Int {
        countImages(in: entries)
    }
    
    var allEntries: [DiskCatalogEntry] {
        return flattenEntries(entries)
    }
    
    private func countFiles(in entries: [DiskCatalogEntry]) -> Int {
        var count = 0
        for entry in entries {
            if !entry.isDirectory { count += 1 }
            if let children = entry.children {
                count += countFiles(in: children)
            }
        }
        return count
    }
    
    private func countImages(in entries: [DiskCatalogEntry]) -> Int {
        var count = 0
        for entry in entries {
            if entry.isImage { count += 1 }
            if let children = entry.children {
                count += countImages(in: children)
            }
        }
        return count
    }
    
    private func flattenEntries(_ entries: [DiskCatalogEntry]) -> [DiskCatalogEntry] {
        var result: [DiskCatalogEntry] = []
        for entry in entries {
            result.append(entry)
            if let children = entry.children {
                result.append(contentsOf: flattenEntries(children))
            }
        }
        return result
    }
}


// MARK: - Disk Image Support

struct DiskImageFile {
    let name: String
    let data: Data
    let type: AppleIIImageType
}

class DiskImageReader {
    
    static func readDiskImage(data: Data) -> [DiskImageFile] {
        var files: [DiskImageFile] = []
        
        if let twoImgFiles = read2IMG(data: data) {
            files.append(contentsOf: twoImgFiles)
        }
        else if let proDOSFiles = readProDOSDSK(data: data) {
            files.append(contentsOf: proDOSFiles)
        }
        else if let dos33Files = readDOS33DSK(data: data) {
            files.append(contentsOf: dos33Files)
        }
        else if let hdvFiles = readHDV(data: data) {
            files.append(contentsOf: hdvFiles)
        }
        
        return files
    }
  
    
    
    // MARK: - 2IMG Format
    
    static func read2IMG(data: Data) -> [DiskImageFile]? {
        guard data.count >= 64 else {
            return nil
        }
        
        let signature = String(data: data.subdata(in: 0..<4), encoding: .ascii)
        guard signature == "2IMG" else {
            return nil
        }
        
        let imageFormat = data[12]
        
        let dataOffset = Int(data[24]) | (Int(data[25]) << 8) | (Int(data[26]) << 16) | (Int(data[27]) << 24)
        let dataLength = Int(data[28]) | (Int(data[29]) << 8) | (Int(data[30]) << 16) | (Int(data[31]) << 24)
        
        // For large disk images, use what's available
        let actualDataLength: Int
        if dataLength == 0 {
            actualDataLength = data.count - dataOffset
        } else {
            actualDataLength = min(dataLength, data.count - dataOffset)
        }
        
        guard dataOffset < data.count else {
            return nil
        }
        
        let endOffset = min(dataOffset + actualDataLength, data.count)
        let diskData = data.subdata(in: dataOffset..<endOffset)
        
        if imageFormat == 0 {
            return readDOS33DSK(data: diskData)
        } else if imageFormat == 1 {
            return readProDOSDSK(data: diskData)
        }
        
        return nil
    }
    
    // MARK: - ProDOS DSK Format
    
    static func readProDOSDSK(data: Data) -> [DiskImageFile]? {
        let blockSize = 512
        
        guard data.count >= blockSize * 2 else {
            return nil
        }
        
        let volumeDirBlock = 2
        let volumeDirOffset = volumeDirBlock * blockSize
        
        guard volumeDirOffset + blockSize <= data.count else {
            return nil
        }
        
        let storageType = (data[volumeDirOffset + 4] & 0xF0) >> 4
        guard storageType == 0x0F else {
            return nil
        }
        
        var files: [DiskImageFile] = []
        
        let entriesPerBlock = 13
        var currentBlock = volumeDirBlock
        
        for _ in 0..<10 {
            let blockOffset = currentBlock * blockSize
            guard blockOffset + blockSize <= data.count else { break }
            
            let startEntry = (currentBlock == volumeDirBlock) ? 1 : 0
            
            for entryIdx in startEntry..<entriesPerBlock {
                let entryOffset = blockOffset + 4 + (entryIdx * 39)
                guard entryOffset + 39 <= data.count else { continue }
                
                let entryStorageType = (data[entryOffset] & 0xF0) >> 4
                guard entryStorageType > 0 else { continue }
                
                let nameLength = Int(data[entryOffset] & 0x0F)
                guard nameLength > 0 && nameLength <= 15 else { continue }
                
                let fileName = String(data: data.subdata(in: (entryOffset + 1)..<(entryOffset + 1 + nameLength)), encoding: .ascii) ?? ""
                
                let fileType = data[entryOffset + 16]
                let keyBlock = Int(data[entryOffset + 17]) | (Int(data[entryOffset + 18]) << 8)
                let blocksUsed = Int(data[entryOffset + 19]) | (Int(data[entryOffset + 20]) << 8)
                let eof = Int(data[entryOffset + 21]) | (Int(data[entryOffset + 22]) << 8) | (Int(data[entryOffset + 23]) << 16)
                
                if fileType == 0xC0 || fileType == 0xC1 || fileType == 0x08 || fileType == 0x06 {
                    if let fileData = extractProDOSFile(data: data, keyBlock: keyBlock, blocksUsed: blocksUsed, eof: eof, storageType: Int(entryStorageType)) {
                        let result = SHRDecoder.decode(data: fileData, filename: fileName)
                        if result.type != AppleIIImageType.Unknown, let _ = result.image {
                            files.append(DiskImageFile(name: fileName, data: fileData, type: result.type))
                        }
                    }
                }
            }
            
            let nextBlock = Int(data[blockOffset + 2]) | (Int(data[blockOffset + 3]) << 8)
            if nextBlock == 0 { break }
            currentBlock = nextBlock
        }
        
        return files.isEmpty ? nil : files
    }
    
    static func extractProDOSFile(data: Data, keyBlock: Int, blocksUsed: Int, eof: Int, storageType: Int) -> Data? {
        let blockSize = 512
        var fileData = Data()
        
        if storageType == 1 {
            let offset = keyBlock * blockSize
            guard offset + blockSize <= data.count else { return nil }
            fileData = data.subdata(in: offset..<min(offset + eof, offset + blockSize))
        } else if storageType == 2 {
            let indexOffset = keyBlock * blockSize
            guard indexOffset + blockSize <= data.count else { return nil }
            
            for i in 0..<256 {
                let blockNum = Int(data[indexOffset + i]) | (Int(data[indexOffset + i + 256]) << 8)
                if blockNum == 0 { break }
                
                let blockOffset = blockNum * blockSize
                guard blockOffset + blockSize <= data.count else { continue }
                
                let bytesToRead = min(blockSize, eof - fileData.count)
                if bytesToRead > 0 {
                    fileData.append(data.subdata(in: blockOffset..<(blockOffset + bytesToRead)))
                }
                
                if fileData.count >= eof { break }
            }
        } else if storageType == 3 {
            let masterIndexOffset = keyBlock * blockSize
            guard masterIndexOffset + blockSize <= data.count else { return nil }
            
            for masterIdx in 0..<256 {
                let indexBlockNum = Int(data[masterIndexOffset + masterIdx]) | (Int(data[masterIndexOffset + masterIdx + 256]) << 8)
                if indexBlockNum == 0 { break }
                
                let indexOffset = indexBlockNum * blockSize
                guard indexOffset + blockSize <= data.count else { continue }
                
                for i in 0..<256 {
                    let blockNum = Int(data[indexOffset + i]) | (Int(data[indexOffset + i + 256]) << 8)
                    if blockNum == 0 { break }
                    
                    let blockOffset = blockNum * blockSize
                    guard blockOffset + blockSize <= data.count else { continue }
                    
                    let bytesToRead = min(blockSize, eof - fileData.count)
                    if bytesToRead > 0 {
                        fileData.append(data.subdata(in: blockOffset..<(blockOffset + bytesToRead)))
                    }
                    
                    if fileData.count >= eof { break }
                }
                
                if fileData.count >= eof { break }
            }
        }
        
        return fileData.isEmpty ? nil : fileData
    }
    
    // MARK: - DOS 3.3 DSK Format
    
    static func readDOS33DSK(data: Data) -> [DiskImageFile]? {
        let sectorSize = 256
        let sectorsPerTrack = 16
        let tracks = 35
        
        guard data.count >= sectorSize * sectorsPerTrack * tracks else {
            return nil
        }
        
        let vtocTrack = 17
        let vtocSector = 0
        let vtocOffset = (vtocTrack * sectorsPerTrack + vtocSector) * sectorSize
        
        guard vtocOffset + sectorSize <= data.count else {
            return nil
        }
        
        let catalogTrack = Int(data[vtocOffset + 1])
        guard catalogTrack == 17 else {
            return nil
        }
        
        var files: [DiskImageFile] = []
        
        var currentTrack = 17
        var currentSector = 15
        
        for _ in 0..<100 {
            let catalogOffset = (currentTrack * sectorsPerTrack + currentSector) * sectorSize
            guard catalogOffset + sectorSize <= data.count else { break }
            
            for entryIdx in 0..<7 {
                let entryOffset = catalogOffset + 11 + (entryIdx * 35)
                guard entryOffset + 35 <= data.count else { continue }
                
                let trackList = Int(data[entryOffset])
                let sectorList = Int(data[entryOffset + 1])
                
                if trackList == 0 || trackList == 0xFF { continue }
                
                var fileName = ""
                for i in 0..<30 {
                    let char = data[entryOffset + 3 + i] & 0x7F
                    if char == 0 || char == 0x20 { break }
                    if char > 0 {
                        fileName.append(Character(UnicodeScalar(char)))
                    }
                }
                fileName = fileName.trimmingCharacters(in: .whitespaces)
                
                let fileType = data[entryOffset + 2] & 0x7F
                
                // Accept: B (0x42), I (0x49), A (0x41), and binary (0x04)
                if fileType == 0x42 || fileType == 0x49 || fileType == 0x41 || fileType == 0x04 {
                    if let fileData = extractDOS33File(data: data, trackList: trackList, sectorList: sectorList, sectorsPerTrack: sectorsPerTrack, sectorSize: sectorSize) {
                        let result = SHRDecoder.decode(data: fileData, filename: fileName)
                        if result.type != AppleIIImageType.Unknown, let _ = result.image {
                            files.append(DiskImageFile(name: fileName, data: fileData, type: result.type))
                        }
                    }
                }
            }
            
            let nextTrack = Int(data[catalogOffset + 1])
            let nextSector = Int(data[catalogOffset + 2])
            
            if nextTrack == 0 { break }
            currentTrack = nextTrack
            currentSector = nextSector
        }
        
        return files.isEmpty ? nil : files
    }
    
    static func extractDOS33File(data: Data, trackList: Int, sectorList: Int, sectorsPerTrack: Int, sectorSize: Int) -> Data? {
        var fileData = Data()
        var currentTrack = trackList
        var currentSector = sectorList
        
        for _ in 0..<1000 {
            let tsListOffset = (currentTrack * sectorsPerTrack + currentSector) * sectorSize
            guard tsListOffset + sectorSize <= data.count else { break }
            
            for pairIdx in 0..<122 {
                let track = Int(data[tsListOffset + 12 + (pairIdx * 2)])
                let sector = Int(data[tsListOffset + 12 + (pairIdx * 2) + 1])
                
                if track == 0 { break }
                
                let dataOffset = (track * sectorsPerTrack + sector) * sectorSize
                guard dataOffset + sectorSize <= data.count else { continue }
                
                fileData.append(data.subdata(in: dataOffset..<(dataOffset + sectorSize)))
            }
            
            let nextTrack = Int(data[tsListOffset + 1])
            let nextSector = Int(data[tsListOffset + 2])
            
            if nextTrack == 0 { break }
            currentTrack = nextTrack
            currentSector = nextSector
        }
        
        // Strip DOS 3.3 binary header (4 bytes: load address + length)
        if fileData.count > 4 {
            let loadAddr = Int(fileData[0]) | (Int(fileData[1]) << 8)
            let length = Int(fileData[2]) | (Int(fileData[3]) << 8)
            
            // Check if this looks like a valid binary header
            // Valid load addresses are typically in ranges: 0x0800-0x6000
            if length > 100 && length <= fileData.count - 4 && loadAddr >= 0x0800 && loadAddr <= 0xBFFF {
                fileData = fileData.subdata(in: 4..<(4 + length))
            }
        }
        
        return fileData.isEmpty ? nil : fileData
    }
    
    // MARK: - HDV Format
    
    static func readHDV(data: Data) -> [DiskImageFile]? {
        return readProDOSDSK(data: data)
    }
}

// MARK: - Image Item Model

struct ImageItem: Identifiable {
    let id = UUID()
    let url: URL
    let image: NSImage
    let type: AppleIIImageType
    
    var filename: String {
        url.lastPathComponent
    }
    
}
// MARK: - Catalog Reading Extension

extension DiskImageReader {
    static func readDiskCatalog(data: Data, filename: String = "Unknown") -> DiskCatalog? {
     
        
        // 2IMG Format
        if let catalog = read2IMGCatalogFull(data: data, filename: filename) {
        
            return catalog
        }
        
      
        
        // Direkte Disk Images mit Order Detection
        let result = readDiskCatalogWithOrderDetection(data: data, filename: filename)
        
        if result != nil {
    
        } else {
     
        }
        
        return result
    }
    
    static func read2IMGCatalogFull(data: Data, filename: String) -> DiskCatalog? {
        guard data.count >= 64 else { return nil }
        
        let signature = String(data: data.subdata(in: 0..<4), encoding: .ascii)
        guard signature == "2IMG" else { return nil }
        
        let imageFormat = data[12]
        let dataOffset = Int(data[24]) | (Int(data[25]) << 8) | (Int(data[26]) << 16) | (Int(data[27]) << 24)
        let dataLength = Int(data[28]) | (Int(data[29]) << 8) | (Int(data[30]) << 16) | (Int(data[31]) << 24)
        
        let actualDataLength: Int
        if dataLength == 0 {
            actualDataLength = data.count - dataOffset  // Berechne aus Dateigröße
        } else {
            actualDataLength = min(dataLength, data.count - dataOffset)
        }
        guard dataOffset < data.count else { return nil }
        
        let endOffset = min(dataOffset + actualDataLength, data.count)
        let diskData = data.subdata(in: dataOffset..<endOffset)
        
        if imageFormat == 0 {
            return readDOS33CatalogFull(data: diskData, filename: filename)
        } else if imageFormat == 1 {
            return readProDOSCatalogFull(data: diskData, filename: filename)
        }
        
        return nil
    }
    
    static func readProDOSCatalogFull(data: Data, filename: String) -> DiskCatalog? {
        let blockSize = 512
        guard data.count >= blockSize * 3 else { return nil }
        
        // Try both block 2 (standard) and block 1 (some non-standard disks)
        for volumeDirBlock in [2, 1] {
            let volumeDirOffset = volumeDirBlock * blockSize
            guard volumeDirOffset + blockSize <= data.count else { continue }
            
            let storageType = (data[volumeDirOffset + 4] & 0xF0) >> 4
            guard storageType == 0x0F else { continue }
            
            let volumeNameLength = Int(data[volumeDirOffset + 4] & 0x0F)
            guard volumeNameLength > 0 && volumeNameLength <= 15 else { continue }
            
            var volumeName = ""
            for i in 0..<volumeNameLength {
                volumeName.append(Character(UnicodeScalar(data[volumeDirOffset + 5 + i])))
            }
            
            let entries = readProDOSDirectoryForCatalog(data: data, startBlock: volumeDirBlock, blockSize: blockSize, parentPath: "")
            
            // Only return if we found files
            if !entries.isEmpty {
                return DiskCatalog(
                    diskName: volumeName.isEmpty ? filename : volumeName,
                    diskFormat: "ProDOS",
                    diskSize: data.count,
                    entries: entries
                )
            }
        }
        
        return nil
    }
    
    static func readProDOSDirectoryForCatalog(data: Data, startBlock: Int, blockSize: Int, parentPath: String) -> [DiskCatalogEntry] {
        var entries: [DiskCatalogEntry] = []
        var currentBlock = startBlock
        
        for _ in 0..<100 {
            let blockOffset = currentBlock * blockSize
            guard blockOffset + blockSize <= data.count else { break }
            
            let entriesPerBlock = currentBlock == startBlock ? 12 : 13
            let entryStart = currentBlock == startBlock ? 4 + 39 : 4
            
            for entryIdx in 0..<entriesPerBlock {
                let entryOffset = blockOffset + entryStart + (entryIdx * 39)
                guard entryOffset + 39 <= data.count else { continue }
                
                let entryStorageType = (data[entryOffset] & 0xF0) >> 4
                if entryStorageType == 0 { continue }
                
                let nameLength = Int(data[entryOffset] & 0x0F)
                var fileName = ""
                for i in 0..<nameLength {
                    fileName.append(Character(UnicodeScalar(data[entryOffset + 1 + i])))
                }
                
                let fileType = data[entryOffset + 16]
                let keyPointer = Int(data[entryOffset + 17]) | (Int(data[entryOffset + 18]) << 8)
                let blocksUsed = Int(data[entryOffset + 19]) | (Int(data[entryOffset + 20]) << 8)
                let eof = Int(data[entryOffset + 21]) | (Int(data[entryOffset + 22]) << 8) | (Int(data[entryOffset + 23]) << 16)
                
                let fullPath = parentPath.isEmpty ? fileName : "\(parentPath)/\(fileName)"
                
                if entryStorageType == 0x0D {
                    // Directory
                    let subEntries = readProDOSDirectoryForCatalog(data: data, startBlock: keyPointer, blockSize: blockSize, parentPath: fullPath)
                    
                    let dirEntry = DiskCatalogEntry(
                        name: fileName,
                        fileType: 0x0F,
                        fileTypeString: "DIR",
                        size: subEntries.reduce(0) { $0 + $1.size },
                        blocks: blocksUsed,
                        loadAddress: nil,
                        length: nil,
                        data: Data(),
                        isImage: false,
                        imageType: .Unknown,
                        isDirectory: true,
                        children: subEntries
                    )
                    entries.append(dirEntry)
                } else {
                    // Regular file
                    if let fileData = extractProDOSFile(data: data, keyBlock: keyPointer, blocksUsed: blocksUsed, eof: eof, storageType: Int(entryStorageType)) {
                        // Check if this could be an image based on file type and size
                        var loadAddr: Int? = nil
                        var length: Int? = nil
                        if fileData.count > 4 && (fileType == 0x04 || fileType == 0x06) {
                            let potentialLoadAddr = Int(fileData[0]) | (Int(fileData[1]) << 8)
                            let potentialLength = Int(fileData[2]) | (Int(fileData[3]) << 8)
                            
                            // Validate load address (should be reasonable)
                            if potentialLoadAddr < 0xC000 && potentialLength > 0 && potentialLength < 0x8000 {
                                loadAddr = potentialLoadAddr
                                length = potentialLength
                            }
                        }

                        // ProDOS Graphics Detection - check by file size if no valid header
                        let couldBeGraphics = (fileType == 0x04 || fileType == 0x06) && (
                            fileData.count == 8192 ||     // HGR
                            fileData.count == 16384 ||    // DHGR
                            fileData.count == 32768 ||    // SHR
                            fileData.count == 8196 ||     // HGR + header
                            fileData.count == 16388 ||    // DHGR + header
                            fileData.count == 32772       // SHR + header
                        )

                        // Use FileType info for icon/description, but override isGraphics check
                        let fileTypeInfo = ProDOSFileTypeInfo.getFileTypeInfo(fileType: fileType, auxType: loadAddr)

                        // Only decode if size suggests graphics
                        let result: (image: CGImage?, type: AppleIIImageType)
                        if couldBeGraphics || fileTypeInfo.isGraphics {
                            result = SHRDecoder.decode(data: fileData, filename: fileName)
                        } else {
                            result = (image: nil, type: .Unknown)
                        }

                       

                        let isImage = result.image != nil && result.type != .Unknown
                        
                        // Use mapped type for graphics recognition, differentiate by size
                        let displayFileType: UInt8
                        if couldBeGraphics && isImage {
                            // Differentiate HGR vs DHGR by file size
                            if fileData.count >= 16380 && fileData.count <= 16400 {
                                // DHGR size range
                                displayFileType = 0x08  // FOT with auxType for DHGR
                            } else {
                                // HGR or SHR
                                displayFileType = 0x08  // FOT
                            }
                        } else {
                            displayFileType = fileType
                        }

                        // Set appropriate auxType for FileType detection
                        let displayAuxType: Int?
                        if couldBeGraphics && isImage {
                            if fileData.count >= 16380 && fileData.count <= 16400 {
                                displayAuxType = 0x4000  // DHGR
                            } else if fileData.count >= 8180 && fileData.count <= 8200 {
                                displayAuxType = 0x2000  // HGR
                            } else {
                                displayAuxType = loadAddr
                            }
                        } else {
                            displayAuxType = loadAddr
                        }

                        let entry = DiskCatalogEntry(
                            name: fileName,
                            fileType: displayFileType,
                            fileTypeString: String(format: "$%02X", fileType),
                            size: fileData.count,
                            blocks: blocksUsed,
                            loadAddress: displayAuxType,  // <-- Use displayAuxType!
                            length: length,
                            data: fileData,
                            isImage: isImage,
                            imageType: result.type,
                            isDirectory: false,
                            children: nil
                        )
                        entries.append(entry)
                    }
                }
            }
            
            let nextBlock = Int(data[blockOffset + 2]) | (Int(data[blockOffset + 3]) << 8)
            if nextBlock == 0 { break }
            currentBlock = nextBlock
        }
        
        return entries
    }
    
    static func readDOS33CatalogFull(data: Data, filename: String) -> DiskCatalog? {
      
        
        let sectorSize = 256
        let sectorsPerTrack = 16
        let tracks = 35
        
        guard data.count >= sectorSize * sectorsPerTrack * tracks else {
           
            return nil
        }
        
        let vtocTrack = 17
        let vtocSector = 0
        let vtocOffset = (vtocTrack * sectorsPerTrack + vtocSector) * sectorSize
        
        guard vtocOffset + sectorSize <= data.count else {
           
            return nil
        }
        
        let catalogTrack = Int(data[vtocOffset + 1])
       
        
        guard catalogTrack == 17 else {
          
            return nil
        }
        
        var entries: [DiskCatalogEntry] = []
        var currentTrack = 17
        var currentSector = 15
        
        for _ in 0..<100 {
            let catalogOffset = (currentTrack * sectorsPerTrack + currentSector) * sectorSize
            guard catalogOffset + sectorSize <= data.count else { break }
            
            for entryIdx in 0..<7 {
                let entryOffset = catalogOffset + 11 + (entryIdx * 35)
                guard entryOffset + 35 <= data.count else { continue }
                
                let trackList = Int(data[entryOffset])
                let sectorList = Int(data[entryOffset + 1])
                
                if trackList == 0 || trackList == 0xFF { continue }
                
                var fileName = ""
                for i in 0..<30 {
                    let char = data[entryOffset + 3 + i] & 0x7F
                    if char == 0 || char == 0x20 { break }
                    if char > 0 {
                        fileName.append(Character(UnicodeScalar(char)))
                    }
                }
                fileName = fileName.trimmingCharacters(in: .whitespaces)
                
                let fileType = data[entryOffset + 2]
                let sectorsUsed = Int(data[entryOffset + 33]) | (Int(data[entryOffset + 34]) << 8)
                
                if let fileData = extractDOS33File(data: data, trackList: trackList, sectorList: sectorList, sectorsPerTrack: sectorsPerTrack, sectorSize: sectorSize) {
                    // Check if this could be an image based on file type and size
                  

                    var loadAddr: Int? = nil
                    var length: Int? = nil
                    if fileData.count > 4 && (fileType & 0x7F == 0x04 || fileType & 0x7F == 0x06) {
                        loadAddr = Int(fileData[0]) | (Int(fileData[1]) << 8)
                        length = Int(fileData[2]) | (Int(fileData[3]) << 8)
                    }

                    // DOS 3.3 Graphics Detection
                    // Be more flexible with file sizes (allow header + data)
                    let couldBeGraphics = (fileType & 0x7F == 0x04 || fileType & 0x7F == 0x06) && (
                        // Exact sizes
                        fileData.count == 8192 ||     // HGR exact
                        fileData.count == 16384 ||    // DHGR exact
                        fileData.count == 32768 ||    // SHR exact
                        // Sizes with 4-byte header
                        fileData.count == 8196 ||     // HGR + header
                        fileData.count == 16388 ||    // DHGR + header
                        fileData.count == 32772 ||    // SHR + header
                        // Sizes in range (some files have padding/extra data)
                        (fileData.count >= 8180 && fileData.count <= 8200) ||   // HGR range
                        (fileData.count >= 16380 && fileData.count <= 16400) || // DHGR range
                        (fileData.count >= 32760 && fileData.count <= 32780) || // SHR range
                        // Standard load addresses
                        (loadAddr == 0x2000 && fileData.count >= 8180) ||  // HGR load address
                        (loadAddr == 0x4000 && fileData.count >= 16380)    // DHGR load address
                    )

                    // Only decode if it looks like graphics
                    let result: (image: CGImage?, type: AppleIIImageType)
                    if couldBeGraphics {
                        result = SHRDecoder.decode(data: fileData, filename: fileName)
                    } else {
                        result = (image: nil, type: .Unknown)
                    }

                    let isImage = result.image != nil && result.type != .Unknown


                    // Use the mapped ProDOS file type for better type detection
                    let proDOSFileType: UInt8 = couldBeGraphics ? 0x08 : (fileType & 0x7F)

                    // Set appropriate auxType for FileType detection
                    let displayAuxType: Int?
                    if couldBeGraphics && isImage {
                        if fileData.count >= 16380 && fileData.count <= 16400 {
                            displayAuxType = 0x4000  // DHGR
                        } else if fileData.count >= 8180 && fileData.count <= 8200 {
                            displayAuxType = 0x2000  // HGR
                        } else {
                            displayAuxType = loadAddr
                        }
                    } else {
                        displayAuxType = loadAddr
                    }

                    let entry = DiskCatalogEntry(
                        name: fileName,
                        fileType: proDOSFileType,
                        fileTypeString: String(format: "$%02X", fileType & 0x7F),
                        size: fileData.count,
                        blocks: sectorsUsed,
                        loadAddress: displayAuxType,  // <-- Use displayAuxType!
                        length: length,
                        data: fileData,
                        isImage: isImage,
                        imageType: result.type,
                        isDirectory: false,
                        children: nil
                    )
                    entries.append(entry)
                }
            }
            
            let nextTrack = Int(data[catalogOffset + 1])
            let nextSector = Int(data[catalogOffset + 2])
            
            if nextTrack == 0 { break }
            currentTrack = nextTrack
            currentSector = nextSector
        }
        
        return DiskCatalog(
            diskName: filename,
            diskFormat: "DOS 3.3",
            diskSize: data.count,
            entries: entries
        )
    }
}
extension DiskImageReader {
    
    /// Konvertiert DOS 3.3 Sector Order zu ProDOS Block Order
    /// Nötig für .dsk Dateien die ProDOS enthalten aber DOS Order nutzen
    static func convertDOSOrderToProDOSOrder(data: Data) -> Data? {
        guard data.count == 143360 else { return nil } // 35 tracks * 16 sectors * 256 bytes
        
        var proDOSData = Data(count: data.count)
        
        // DOS to ProDOS physical sector mapping
        let dosToProDOS: [Int] = [
            0x0, 0x7, 0xE, 0x6, 0xD, 0x5, 0xC, 0x4,
            0xB, 0x3, 0xA, 0x2, 0x9, 0x1, 0x8, 0xF
        ]
        
        let sectorsPerTrack = 16
        let sectorSize = 256
        let tracks = 35
        
        for track in 0..<tracks {
            for dosSector in 0..<sectorsPerTrack {
                let proDOSSector = dosToProDOS[dosSector]
                
                let dosOffset = (track * sectorsPerTrack + dosSector) * sectorSize
                let proDOSOffset = (track * sectorsPerTrack + proDOSSector) * sectorSize
                
                // Copy sector from DOS position to ProDOS position
                proDOSData[proDOSOffset..<(proDOSOffset + sectorSize)] = data[dosOffset..<(dosOffset + sectorSize)]
            }
        }
        
        return proDOSData
    }
    
    /// Prüft ob eine Disk Image DOS Order nutzt und konvertiert wenn nötig
    static func readDiskCatalogWithOrderDetection(data: Data, filename: String) -> DiskCatalog? {
       
        
        // Zuerst: Versuche direkt als ProDOS
    
        if let catalog = readProDOSCatalogFull(data: data, filename: filename) {
            // Prüfe ob wirklich Dateien gefunden wurden
            if catalog.totalFiles > 0 {
              
                return catalog
            } else {
                
            }
        }
        
        // Zweiter Versuch: DOS 3.3
      
        if let catalog = readDOS33CatalogFull(data: data, filename: filename) {
            
            return catalog
        }
        
        // Dritter Versuch: Konvertiere DOS Order → ProDOS Order und versuche nochmal
        if data.count == 143360 {
          
            if let convertedData = convertDOSOrderToProDOSOrder(data: data) {
                if let catalog = readProDOSCatalogFull(data: convertedData, filename: filename) {
                    if catalog.totalFiles > 0 {
                       
                        return catalog
                    }
                }
            }
        }
        
        return nil
    }
}



// MARK: - Main App Entry Point

@main
struct SHRConverterApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 900, minHeight: 600)
        }
    }
}


// MARK: - UI View with Image Browser

struct ContentView: View {
    @State private var filesToConvert: [URL] = []
    @State private var imageItems: [ImageItem] = []
    @State private var selectedImage: ImageItem?
    @State private var selectedExportFormat: ExportFormat = .png
    @State private var statusMessage: String = "Drag files/folders or open files to start."
    @State private var isProcessing = false
    @State private var progressString = ""
    @State private var showBrowser = false
    @State private var upscaleFactor: Int = 1
    @State private var zoomScale: CGFloat = 1.0
    @State private var imageOffset: CGSize = .zero
    @State private var filterFormat: String = "All"
    @State private var showCatalogBrowser = false
    @State private var currentCatalog: DiskCatalog? = nil
    
    var filteredImages: [ImageItem] {
        if filterFormat == "All" {
            return imageItems
        }
        
        return imageItems.filter { item in
            let typeName = item.type.displayName
            switch filterFormat {
            case "Apple II":
                return typeName.contains("SHR") || typeName.contains("HGR") || typeName.contains("DHGR")
            case "C64":
                return typeName.contains("C64")
            case "Amiga":
                return typeName.contains("IFF")
            case "Atari ST":
                return typeName.contains("DEGAS")
            case "ZX Spectrum":
                return typeName.contains("ZX Spectrum")
            case "CPC":
                return typeName.contains("CPC")
            case "PC":
                return typeName.contains("PCX") || typeName.contains("BMP")
            case "Mac":
                return typeName.contains("MacPaint")
            case "Modern":
                return typeName.contains("PNG") || typeName.contains("JPEG") || typeName.contains("GIF") || typeName.contains("TIFF") || typeName.contains("HEIC") || typeName.contains("WEBP")
            default:
                return true
            }
        }
    }
    
    var body: some View {
        HSplitView {
            if showBrowser && !imageItems.isEmpty {
                browserPanel
                    .frame(minWidth: 250, idealWidth: 300)
            }
            
            mainPanel
                .frame(minWidth: 500)
        }
        .padding()
        .sheet(isPresented: $showCatalogBrowser) {
            if let catalog = currentCatalog {
                DiskCatalogBrowserView(
                    catalog: catalog,
                    onImport: { selectedEntries in
                        importCatalogEntries(selectedEntries)
                        showCatalogBrowser = false
                    },
                    onCancel: {
                        showCatalogBrowser = false
                    }
                )
            }
        }

    }
    
    
    
    var browserPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Image Browser")
                    .font(.headline)
                Spacer()
                Button(action: { clearAllImages() }) {
                    Image(systemName: "trash")
                }
                .help("Clear all images")
            }
            
            HStack {
                Text("Filter:")
                    .font(.caption)
                Picker("", selection: $filterFormat) {
                    Text("All").tag("All")
                    Text("Apple II").tag("Apple II")
                    Text("C64").tag("C64")
                    Text("Amiga").tag("Amiga")
                    Text("Atari ST").tag("Atari ST")
                    Text("ZX Spectrum").tag("ZX Spectrum")
                    Text("Amstrad CPC").tag("CPC")
                    Text("PC (PCX/BMP)").tag("PC")
                    Text("Mac").tag("Mac")
                    Text("Modern (PNG/JPG)").tag("Modern")
                }
                .labelsHidden()
                Spacer()
            }
            
            Divider()
            
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 10)], spacing: 10) {
                    ForEach(filteredImages) { item in
                        ImageThumbnailView(item: item, isSelected: selectedImage?.id == item.id)
                            .onTapGesture {
                                selectedImage = item
                            }
                    }
                }
                .padding(.horizontal, 5)
            }
            .onDrop(of: [.fileURL, .url, .data], isTargeted: nil) { providers in
              
                loadDroppedFiles(providers)
                return true
            }
            
            Divider()
            
            Text("\(filteredImages.count) of \(imageItems.count) image(s)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    var mainPanel: some View {
        VStack(spacing: 20) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [10]))
                    .foregroundColor(isProcessing ? .blue : (!imageItems.isEmpty ? .green : .secondary))
                    .background(Color(NSColor.controlBackgroundColor))
                
                if let selectedImg = selectedImage {
                    VStack(spacing: 10) {
                        GeometryReader { geometry in
                            ScrollView([.horizontal, .vertical], showsIndicators: true) {
                                Image(nsImage: selectedImg.image)
                                    .interpolation(.none)
                                    .scaleEffect(zoomScale)
                                    .offset(imageOffset)
                                    .gesture(
                                        MagnificationGesture()
                                            .onChanged { value in
                                                zoomScale = max(0.5, min(value, 10.0))
                                            }
                                    )
                            }
                            .frame(maxWidth: .infinity, maxHeight: 400)
                        }
                        .frame(maxHeight: 400)
                        
                        HStack(spacing: 10) {
                            Button("Zoom Out") {
                                zoomScale = max(0.5, zoomScale / 1.5)
                            }
                            
                            Text("\(Int(zoomScale * 100))%")
                                .frame(width: 60)
                            
                            Button("Zoom In") {
                                zoomScale = min(10.0, zoomScale * 1.5)
                            }
                            
                            Button("Reset") {
                                zoomScale = 1.0
                                imageOffset = .zero
                            }
                            
                            Spacer()
                        }
                        .font(.caption)
                        
                        HStack {
                            Text(selectedImg.filename)
                                .font(.headline)
                            Spacer()
                            Text(selectedImg.type.displayName)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(4)
                        }
                        .padding(.horizontal)
                    }
                    .padding()
                } else if imageItems.isEmpty {
                    VStack(spacing: 15) {
                        Image(systemName: "photo.stack")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("Retro Graphics Converter")
                            .font(.headline)
                        Text("Supports Apple II (including disk images: 2IMG, DSK, HDV), Amiga IFF, Atari ST, C64, ZX Spectrum, Amstrad CPC, PCX, BMP, MacPaint, plus modern formats.")
                            .multilineTextAlignment(.center)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Drag & drop files/folders or click 'Open Files...'")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    VStack(spacing: 15) {
                        Image(systemName: "hand.tap")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("Select an image from the browser")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                }
                
                if isProcessing {
                    VStack(spacing: 10) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text(progressString)
                            .font(.caption)
                            .padding(.top, 10)
                    }
                    .padding()
                    .background(Color(NSColor.windowBackgroundColor).opacity(0.9))
                    .cornerRadius(10)
                }
            }
            .frame(height: 450)
            .onDrop(of: [.fileURL, .url, .data], isTargeted: nil) { providers in
         
                loadDroppedFiles(providers)
                return true
            }
            
            VStack(spacing: 10) {
                HStack {
                    Button("Open Files...") {
                        openFiles()
                    }
                    
                    Button(showBrowser ? "Hide Browser" : "Show Browser") {
                        withAnimation {
                            showBrowser.toggle()
                        }
                    }
                    .disabled(imageItems.isEmpty)
                    
                    Spacer()
                    
                    Picker("Upscale:", selection: $upscaleFactor) {
                        Text("1x (Original)").tag(1)
                        Text("2x").tag(2)
                        Text("4x").tag(4)
                        Text("8x").tag(8)
                    }
                    .frame(width: 150)
                    
                    Picker("Export As:", selection: $selectedExportFormat) {
                        ForEach(ExportFormat.allCases, id: \.self) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .frame(width: 180)
                    
                    Button("Export All to \(selectedExportFormat.rawValue)...") {
                        exportAllImages()
                    }
                    .disabled(imageItems.isEmpty || isProcessing)
                    
                    Button("Export with Custom Names...") {
                        showBatchRename()
                    }
                    .disabled(imageItems.isEmpty || isProcessing)
                }
                
                if let selected = selectedImage {
                    HStack {
                        Spacer()
                        Button("Export Selected Image...") {
                            exportSingleImage(selected)
                        }
                        .disabled(isProcessing)
                    }
                }
            }
            
            VStack(alignment: .leading, spacing: 5) {
                Text(statusMessage)
                    .font(.headline)
                if !progressString.isEmpty && !isProcessing {
                    Text(progressString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
    }
    
    // MARK: - File Handling
    func importCatalogEntries(_ entries: [DiskCatalogEntry]) {
        DispatchQueue.global(qos: .userInitiated).async {
            var newItems: [ImageItem] = []
            
            for entry in entries {
                if entry.isImage, let cgImage = SHRDecoder.decode(data: entry.data, filename: entry.name).image {
                    let url = URL(fileURLWithPath: "/catalog/\(entry.name)")
                    let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                    let item = ImageItem(url: url, image: nsImage, type: entry.imageType)
                    newItems.append(item)
                }
            }
            
            DispatchQueue.main.async {
                self.imageItems.append(contentsOf: newItems)
                
                if !newItems.isEmpty {
                    self.showBrowser = true
                    if self.selectedImage == nil {
                        self.selectedImage = newItems.first
                    }
                }
                
                self.statusMessage = "Imported \(newItems.count) image(s) from catalog"
            }
        }
    }
    func clearAllImages() {
        imageItems = []
        selectedImage = nil
        filesToConvert = []
        statusMessage = "All images cleared."
        progressString = ""
        showBrowser = false
    }
    
    func showBatchRename() {
        let alert = NSAlert()
        alert.messageText = "Batch Export with Custom Names"
        alert.informativeText = "Export all images with custom names. Use {n} for number, {name} for original name.\nExample: converted_{n} тЖТ converted_1.png, converted_2.png, etc."
        alert.alertStyle = .informational
        alert.addButton(withTitle: "Export")
        alert.addButton(withTitle: "Cancel")
        
        let inputField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        inputField.stringValue = "{name}_converted"
        inputField.placeholderString = "e.g., image_{n} or {name}_export"
        alert.accessoryView = inputField
        
        let response = alert.runModal()
        
        if response == .alertFirstButtonReturn {
            let pattern = inputField.stringValue
            batchExportWithRename(pattern: pattern)
        }
    }
    
    func batchExportWithRename(pattern: String) {
        guard !imageItems.isEmpty else { return }
        
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.canCreateDirectories = true
        openPanel.showsHiddenFiles = false
        openPanel.prompt = "Select Export Folder"

        if openPanel.runModal() == .OK, let outputFolderURL = openPanel.url {
            isProcessing = true
            
            DispatchQueue.global(qos: .userInitiated).async {
                var successCount = 0
                
                for (index, item) in self.imageItems.enumerated() {
                    DispatchQueue.main.async {
                        self.progressString = "Exporting \(index + 1) of \(self.imageItems.count)"
                    }
                    
                    let originalName = item.url.deletingPathExtension().lastPathComponent
                    
                    var newName = pattern
                    newName = newName.replacingOccurrences(of: "{n}", with: "\(index + 1)")
                    newName = newName.replacingOccurrences(of: "{name}", with: originalName)
                    
                    let filename = "\(newName).\(self.selectedExportFormat.fileExtension)"
                    let outputURL = outputFolderURL.appendingPathComponent(filename)
                    
                    if self.saveImage(image: item.image, to: outputURL, format: self.selectedExportFormat) {
                        successCount += 1
                    }
                }
                
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.statusMessage = "Exported \(successCount) of \(self.imageItems.count) image(s) with custom names"
                    self.progressString = ""
                }
            }
        }
    }
    
    func openFiles() {
        let openPanel = NSOpenPanel()
        openPanel.allowsOtherFileTypes = true
        openPanel.allowsMultipleSelection = true
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = true
        openPanel.prompt = "Open Files or Folders"

        if openPanel.runModal() == .OK {
            processFilesAndFolders(urls: openPanel.urls)
        }
    }
    
    func loadDroppedFiles(_ providers: [NSItemProvider]) {
       
        
        self.isProcessing = true
        self.statusMessage = "Loading dropped files..."
        
        var filesToProcess: [(data: Data, name: String, url: URL?)] = []
        let dispatchGroup = DispatchGroup()
        
        for (index, provider) in providers.enumerated() {
         
            
            dispatchGroup.enter()
            
            // Versuche zuerst fileURL zu laden
            provider.loadFileRepresentation(forTypeIdentifier: UTType.data.identifier) { url, error in
                if let url = url {
                    // Wir haben eine echte URL mit Dateinamen!
                    do {
                        let data = try Data(contentsOf: url)
                        let fileName = url.lastPathComponent
                       
                        filesToProcess.append((data: data, name: fileName, url: url))
                    } catch {
                      
                    }
                    dispatchGroup.leave()
                } else {
                    // Fallback: Lade als Data
                    guard let typeIdentifier = provider.registeredTypeIdentifiers.first else {
                        dispatchGroup.leave()
                        return
                    }
                    
                    provider.loadDataRepresentation(forTypeIdentifier: typeIdentifier) { data, error in
                        defer { dispatchGroup.leave() }
                        
                        if let data = data {
                            let fileName = "dropped_file_\(index).\(typeIdentifier.split(separator: ".").last ?? "bin")"
                         
                            filesToProcess.append((data: data, name: fileName, url: nil))
                        }
                    }
                }
            }
        }


        
        dispatchGroup.notify(queue: .main) {
          
            
            if filesToProcess.isEmpty {
                self.isProcessing = false
                self.statusMessage = "No files received"
                return
            }
            
            // Process the dropped data directly
            DispatchQueue.global(qos: .userInitiated).async {
                var newItems: [ImageItem] = []
                var successCount = 0
                
                for (fileIndex, file) in filesToProcess.enumerated() {
                    DispatchQueue.main.async {
                        self.progressString = "Processing \(fileIndex + 1) of \(filesToProcess.count): \(file.name)"
                    }
                    
                    let data = file.data
                    let fileName = file.name
                    
                   
                    // Check if it's a known image format first (by magic bytes)
                    let isPNG = data.count >= 8 && data[0] == 0x89 && data[1] == 0x50 && data[2] == 0x4E && data[3] == 0x47
                    let isJPEG = data.count >= 2 && data[0] == 0xFF && data[1] == 0xD8
                    let isGIF = data.count >= 6 && data[0] == 0x47 && data[1] == 0x49 && data[2] == 0x46
                    let isBMP = data.count >= 2 && data[0] == 0x42 && data[1] == 0x4D

                    let isModernImage = isPNG || isJPEG || isGIF || isBMP

                    // Only check for disk images if it's NOT a modern image format
                    let possibleDiskImage = !isModernImage && (data.count == 143360 || data.count == 819200 || data.count > 100000)
                    
                    var processedAsDiskImage = false
                    
                    if possibleDiskImage {
                        // Try catalog browser first
                        if let catalog = DiskImageReader.readDiskCatalog(data: data, filename: fileName) {
                        
                            DispatchQueue.main.async {
                                self.currentCatalog = catalog
                                self.showCatalogBrowser = true
                                self.isProcessing = false
                            }
                            continue
                        }
                        
                        // Catalog reading failed - show error and skip this file
                       
                        DispatchQueue.main.async {
                            self.statusMessage = "Could not read disk image: \(fileName)"
                        }
                        processedAsDiskImage = true  // Mark as processed so it doesn't try as regular file
                    }
                    
                    // Only try as regular file if it wasn't a disk image
                    if !processedAsDiskImage {
                        let result = SHRDecoder.decode(data: data, filename: fileName)
                        if let cgImage = result.image, result.type != .Unknown {
                            let fileURL = file.url ?? URL(fileURLWithPath: "/\(fileName)")
                            let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                            let item = ImageItem(url: fileURL, image: nsImage, type: result.type)
                            newItems.append(item)
                            successCount += 1
                        }
                    }
                }
                
                DispatchQueue.main.async {
                    self.imageItems.append(contentsOf: newItems)
                    self.isProcessing = false
                    
                    if successCount > 0 {
                        self.statusMessage = "Loaded \(successCount) image(s) from \(filesToProcess.count) file(s)"
                        self.showBrowser = true
                        if self.selectedImage == nil {
                            self.selectedImage = newItems.first
                        }
                    } else {
                        self.statusMessage = "No valid images found"
                    }
                    
                    self.progressString = ""
                }
            }
        }
    }
    
    func processFilesAndFolders(urls: [URL]) {
        guard !urls.isEmpty else {
            isProcessing = false
            return
        }
        
        isProcessing = true
        statusMessage = "Scanning files and folders..."
        
        DispatchQueue.global(qos: .userInitiated).async {
            var allFileURLs: [URL] = []
            
            for url in urls {
                var isDirectory: ObjCBool = false
                if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
                    if isDirectory.boolValue {
                        if let files = self.scanFolder(url: url) {
                            allFileURLs.append(contentsOf: files)
                        }
                    } else {
                        allFileURLs.append(url)
                    }
                }
            }
            
            DispatchQueue.main.async {
                if allFileURLs.isEmpty {
                    self.isProcessing = false
                    self.statusMessage = "No files found"
                    self.progressString = ""
                } else {
                    self.processFiles(urls: allFileURLs)
                }
            }
        }
    }
    
    func scanFolder(url: URL) -> [URL]? {
        let fileManager = FileManager.default
        var fileURLs: [URL] = []
        
        guard let enumerator = fileManager.enumerator(at: url,
                                                       includingPropertiesForKeys: [.isRegularFileKey],
                                                       options: [.skipsHiddenFiles]) else {
            return nil
        }
        
        for case let fileURL as URL in enumerator {
            do {
                let fileAttributes = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
                if fileAttributes.isRegularFile == true {
                    let fileSize = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int) ?? 0
                    if fileSize > 0 {
                        fileURLs.append(fileURL)
                    }
                }
            } catch {
                continue
            }
        }
        
        return fileURLs
    }
    
    func processFiles(urls: [URL]) {
        guard !urls.isEmpty else {
            isProcessing = false
            return
        }
        
        isProcessing = true
        statusMessage = "Processing \(urls.count) file(s)..."
        
        DispatchQueue.global(qos: .userInitiated).async {
            var newItems: [ImageItem] = []
            var successCount = 0
            
            for (index, url) in urls.enumerated() {
                DispatchQueue.main.async {
                    self.progressString = "Processing \(index + 1) of \(urls.count): \(url.lastPathComponent)"
                }
                
                guard let data = try? Data(contentsOf: url) else { continue }
                
                // Check if this is a disk image
                let fileExtension = url.pathExtension.lowercased()
                if fileExtension == "2mg" || fileExtension == "dsk" || fileExtension == "hdv" || fileExtension == "po" {
                    // Try catalog first
                    if let catalog = DiskImageReader.readDiskCatalog(data: data, filename: url.lastPathComponent) {
                        DispatchQueue.main.async {
                            self.currentCatalog = catalog
                            self.showCatalogBrowser = true
                            self.isProcessing = false
                        }
                        continue
                    }

                    // Try to extract images from disk image
                    let diskFiles = DiskImageReader.readDiskImage(data: data)
                    
                    for diskFile in diskFiles {
                        if let cgImage = SHRDecoder.decode(data: diskFile.data, filename: diskFile.name).image {
                            // Create a virtual URL for this file
                            let virtualURL = url.appendingPathComponent(diskFile.name)
                            let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                            let item = ImageItem(url: virtualURL, image: nsImage, type: diskFile.type)
                            newItems.append(item)
                            successCount += 1
                        }
                    }
                } else {
                    // Regular file
                    let result = SHRDecoder.decode(data: data, filename: url.lastPathComponent)
                    
                    if let cgImage = result.image, result.type != .Unknown {
                        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                        let item = ImageItem(url: url, image: nsImage, type: result.type)
                        newItems.append(item)
                        successCount += 1
                    }
                }
            }
            
            DispatchQueue.main.async {
                self.imageItems.append(contentsOf: newItems)
                self.isProcessing = false
                self.statusMessage = "Loaded \(successCount) image(s) from \(urls.count) file(s)"
                self.progressString = ""
                
                if !newItems.isEmpty {
                    self.showBrowser = true
                    if self.selectedImage == nil {
                        self.selectedImage = newItems.first
                    }
                }
            }
        }
    }
    
    // MARK: - Export Functions
    
    func exportSingleImage(_ item: ImageItem) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [UTType(filenameExtension: selectedExportFormat.fileExtension)!]
        savePanel.nameFieldStringValue = "\(item.url.deletingPathExtension().lastPathComponent).\(selectedExportFormat.fileExtension)"
        savePanel.prompt = "Export"
        savePanel.canCreateDirectories = true
        savePanel.showsHiddenFiles = false
        savePanel.message = "Export \(item.filename) as \(selectedExportFormat.rawValue)"
        savePanel.level = .modalPanel
        
        savePanel.begin { response in
            if response == .OK, let outputURL = savePanel.url {
                self.isProcessing = true
                DispatchQueue.global(qos: .userInitiated).async {
                    let success = self.saveImage(image: item.image, to: outputURL, format: self.selectedExportFormat)
                    
                    DispatchQueue.main.async {
                        self.isProcessing = false
                        if success {
                            self.statusMessage = "Exported: \(outputURL.lastPathComponent)"
                            self.progressString = ""
                        } else {
                            self.statusMessage = "Export failed!"
                        }
                    }
                }
            }
        }
    }
    
    func exportAllImages() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.canCreateDirectories = true
        openPanel.showsHiddenFiles = false
        openPanel.prompt = "Select Export Folder"

        if openPanel.runModal() == .OK, let outputFolderURL = openPanel.url {
            isProcessing = true
            
            DispatchQueue.global(qos: .userInitiated).async {
                var successCount = 0
                
                for (index, item) in self.imageItems.enumerated() {
                    DispatchQueue.main.async {
                        self.progressString = "Exporting \(index + 1) of \(self.imageItems.count)"
                    }
                    
                    let filename = "\(item.url.deletingPathExtension().lastPathComponent).\(self.selectedExportFormat.fileExtension)"
                    let outputURL = outputFolderURL.appendingPathComponent(filename)
                    
                    if self.saveImage(image: item.image, to: outputURL, format: self.selectedExportFormat) {
                        successCount += 1
                    }
                }
                
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.statusMessage = "Exported \(successCount) of \(self.imageItems.count) image(s)"
                    self.progressString = ""
                }
            }
        }
    }
    
    func saveImage(image: NSImage, to outputURL: URL, format: ExportFormat) -> Bool {
        var finalImage = image
        if upscaleFactor > 1 {
            if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil),
               let upscaled = SHRDecoder.upscaleCGImage(cgImage, factor: upscaleFactor) {
                finalImage = NSImage(cgImage: upscaled, size: NSSize(width: upscaled.width, height: upscaled.height))
            }
        }
        
        guard let tiffData = finalImage.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return false
        }
        
        var outputData: Data? = nil
        
        switch format {
        case .png:
            outputData = bitmap.representation(using: .png, properties: [:])
        case .jpeg:
            outputData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.9])
        case .tiff:
            outputData = bitmap.representation(using: .tiff, properties: [:])
        case .gif:
            outputData = bitmap.representation(using: .gif, properties: [.ditherTransparency: true])
        case .heic:
            guard let cgImage = finalImage.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return false }
            outputData = HEICConverter.convert(cgImage: cgImage)
        }
        
        guard let finalData = outputData else { return false }
        
        do {
            try finalData.write(to: outputURL)
            return true
        } catch {
          
            return false
        }
    }
}

// MARK: - Thumbnail View

struct ImageThumbnailView: View {
    let item: ImageItem
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            Image(nsImage: item.image)
                .resizable()
                .interpolation(.none)
                .frame(width: 120, height: 90)
                .background(Color.black.opacity(0.1))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
                )
            
            Text(item.filename)
                .font(.caption2)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 120)
            
            Text(item.type.displayName)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .padding(4)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(8)
    }
}

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


// MARK: - SHRDecoder

class SHRDecoder {
    
    static func decode(data: Data, filename: String? = nil) -> (image: CGImage?, type: AppleIIImageType) {
        let size = data.count
        
        // Use filename extension as a hint if available
        let fileExtension = filename?.split(separator: ".").last?.lowercased() ?? ""
        
        // Check for modern image formats first (PNG, JPEG, GIF, TIFF, HEIC)
        // These should be recognized before retro formats to avoid false positives
        let modernFormats = ["png", "jpg", "jpeg", "gif", "tiff", "tif", "heic", "heif", "webp"]
        if modernFormats.contains(fileExtension) {
            return decodeModernImage(data: data, format: fileExtension)
        }
        
        // Also check PNG/JPEG/GIF by magic bytes
        if size >= 8 {
            // PNG: starts with 0x89 0x50 0x4E 0x47
            if data[0] == 0x89 && data[1] == 0x50 && data[2] == 0x4E && data[3] == 0x47 {
                return decodeModernImage(data: data, format: "png")
            }
            // JPEG: starts with 0xFF 0xD8
            if data[0] == 0xFF && data[1] == 0xD8 {
                return decodeModernImage(data: data, format: "jpeg")
            }
            // GIF: starts with "GIF87a" or "GIF89a"
            if data[0] == 0x47 && data[1] == 0x49 && data[2] == 0x46 {
                return decodeModernImage(data: data, format: "gif")
            }
        }
        
        // Check for BMP format (starts with "BM")
        if size >= 14 && data[0] == 0x42 && data[1] == 0x4D {
            return decodeBMP(data: data)
        }
        
        // Check for PCX format first (has magic byte 0x0A)
        if size >= 128 && data[0] == 0x0A {
            return decodePCX(data: data)
        }
        
        // Check for IFF format (has FORM header)
        if size >= 12 {
            let header = data.subdata(in: 0..<4)
            if let headerString = String(data: header, encoding: .ascii), headerString == "FORM" {
                return decodeIFF(data: data)
            }
        }
        
        // Check for C64 Koala format (10003 bytes nominal, but sometimes has extra bytes)
        if size >= 10003 && size <= 10010 {
            return decodeC64Koala(data: data)
        }
        
        // Check for other C64 formats and other platforms by exact size
        switch size {
        case 10018: // Art Studio variant
            return decodeC64ArtStudio(data: data)
        case 9009: // Art Studio HIRES or similar
            return decodeC64Hires(data: data)
        case 6912: // ZX Spectrum SCR
            return decodeZXSpectrum(data: data)
        case 16384: // Could be Amstrad CPC or Apple II DHGR
            // Use filename as hint if available
            if fileExtension == "scr" {
                // .SCR is commonly used for CPC screens
                return decodeAmstradCPC(data: data)
            } else if fileExtension == "2mg" || fileExtension == "po" || fileExtension == "dsk" {
                // Apple II disk image extensions
                return (decodeDHGR(data: data), .DHGR)
            }
            
            // No clear filename hint, use heuristics
            // CPC has distinctive patterns (interleaved scanlines, specific byte patterns)
            // DHGR is more uniform memory layout
            
            var cpcScore = 0
            var dhgrScore = 0
            
            // CPC typically has more varied data in the first few blocks
            // DHGR has more sequential patterns
            for blockIdx in 0..<8 {
                let blockStart = blockIdx * 2048
                if blockStart + 100 < data.count {
                    let blockData = data[blockStart..<(blockStart + 100)]
                    let uniqueBytes = Set(blockData).count
                    
                    // CPC tends to have more varied bytes per block
                    if uniqueBytes > 50 {
                        cpcScore += 1
                    } else {
                        dhgrScore += 1
                    }
                }
            }
            
            // If mostly zeros or very uniform, probably DHGR
            let firstKB = data.prefix(1024)
            let zeroCount = firstKB.filter { $0 == 0 }.count
            if zeroCount > 512 {
                dhgrScore += 3 // Strong indicator for DHGR (often starts with zeros)
            }
            
            // Default to DHGR if unclear (more common)
            if cpcScore > dhgrScore + 2 {
                return decodeAmstradCPC(data: data)
            } else {
                return (decodeDHGR(data: data), .DHGR)
            }
        default:
            break
        }
        
        // Check for MacPaint format (.MAC, .PNTG)
        // Only check by extension first - size-based detection comes later
        if fileExtension == "mac" || fileExtension == "pntg" {
            if size >= 512 {
                return decodeMacPaint(data: data)
            }
        }
        
        // Check for Degas format (.PI1, .PI2, .PI3)
        if size >= 34 {
            let resolutionWord = readBigEndianUInt16(data: data, offset: 0)
            
            let isDegas = (resolutionWord <= 2) && (
                size == 32034 ||  // PI1: Low res
                size == 32066     // PI2/PI3: Medium/High res
            )
            
            if isDegas {
                return decodeDegas(data: data)
            }
        }
        
        // Then check Apple II formats by size
        let type: AppleIIImageType
        let image: CGImage?
        
        switch size {
        case 32768:
            type = .SHR(mode: "Standard")
            image = decodeSHR(data: data, is3200Color: false)
        case 38400...:
            type = .SHR(mode: "3200 Color")
            image = decodeSHR(data: data, is3200Color: true)
        case 8184...8200:  // HGR images can vary slightly in size
            type = .HGR
            image = decodeHGR(data: data)
        case 16384:
            // If we reach here, it wasn't CPC, try DHGR
            type = .DHGR
            image = decodeDHGR(data: data)
        default:
            type = .Unknown
            image = nil
        }
        
        // Last resort: Try MacPaint for files in typical size range without extension
        // This comes AFTER all known formats to avoid false positives
        if image == nil && type == .Unknown {
            if size >= 20000 && size <= 100000 && size >= 512 {
                let result = decodeMacPaint(data: data)
                if result.image != nil {
                    return result
                }
            }
        }
        
        return (image, type)
    }
    
    // --- Risk EGA Format Decoder (32KB, 320x200, chunky 4-bit) ---
    
    // --- MacPaint Decoder (Classic Macintosh format, 576x720, 1-bit) ---
    
    static func decodeMacPaint(data: Data) -> (image: CGImage?, type: AppleIIImageType) {
        // MacPaint format: 512 byte header + compressed image data
        // Image is 576x720 pixels (1 bit per pixel)
        // Data is compressed using PackBits (Apple's RLE)
        
        guard data.count >= 512 else {
            return (nil, .Unknown)
        }
        
        let width = 576
        let height = 720
        let bytesPerRow = 72 // 576 pixels / 8 bits per byte
        let expectedSize = bytesPerRow * height // 51840 bytes uncompressed
        
        // Skip 512-byte header, start decompressing from byte 512
        var compressed = Array(data[512...])
        
        // Decompress using PackBits
        var decompressed: [UInt8] = []
        var offset = 0
        
        while offset < compressed.count && decompressed.count < expectedSize {
            let byte = compressed[offset]
            offset += 1
            
            if byte >= 128 {
                // RLE run: repeat next byte (257 - byte) times
                let count = 257 - Int(byte)
                if offset < compressed.count {
                    let value = compressed[offset]
                    offset += 1
                    for _ in 0..<count {
                        decompressed.append(value)
                    }
                }
            } else {
                // Literal run: copy next (byte + 1) bytes
                let count = Int(byte) + 1
                for _ in 0..<count {
                    if offset < compressed.count {
                        decompressed.append(compressed[offset])
                        offset += 1
                    }
                }
            }
        }
        
        // Verify we got enough data
        guard decompressed.count >= expectedSize * 4 / 5 else {
            // If we got less than 80% of expected data, it's probably not MacPaint
            return (nil, .Unknown)
        }
        
        // Convert 1-bit bitmap to RGBA
        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)
        
        for y in 0..<height {
            for x in 0..<width {
                let byteIndex = y * bytesPerRow + (x / 8)
                
                if byteIndex < decompressed.count {
                    let byte = decompressed[byteIndex]
                    let bitIndex = 7 - (x % 8)
                    let bit = (byte >> bitIndex) & 1
                    
                    // Black = 1, White = 0 in MacPaint
                    let color: UInt8 = (bit == 1) ? 0 : 255
                    
                    let bufferIdx = (y * width + x) * 4
                    rgbaBuffer[bufferIdx] = color
                    rgbaBuffer[bufferIdx + 1] = color
                    rgbaBuffer[bufferIdx + 2] = color
                    rgbaBuffer[bufferIdx + 3] = 255
                }
            }
        }
        
        guard let cgImage = createCGImage(from: rgbaBuffer, width: width, height: height) else {
            return (nil, .Unknown)
        }
        
        return (cgImage, .MacPaint)
    }
    
    // --- Modern Image Decoder (PNG, JPEG, GIF, etc.) ---
    
    static func decodeModernImage(data: Data, format: String) -> (image: CGImage?, type: AppleIIImageType) {
        // Use ImageIO to decode modern formats
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
    
    // --- BMP Decoder (Windows Bitmap format) ---
    
    static func decodeBMP(data: Data) -> (image: CGImage?, type: AppleIIImageType) {
        guard data.count >= 54 else { // Minimum BMP size
            return (nil, .Unknown)
        }
        
        // BMP Header (14 bytes)
        // Check "BM" magic bytes
        guard data[0] == 0x42 && data[1] == 0x4D else {
            return (nil, .Unknown)
        }
        
        // DIB Header offset (starts at byte 14)
        let dibHeaderSize = Int(data[14]) | (Int(data[15]) << 8) | (Int(data[16]) << 16) | (Int(data[17]) << 24)
        
        // Read image dimensions (little-endian)
        let width = Int(data[18]) | (Int(data[19]) << 8) | (Int(data[20]) << 16) | (Int(data[21]) << 24)
        var height = Int(data[22]) | (Int(data[23]) << 8) | (Int(data[24]) << 16) | (Int(data[25]) << 24)
        
        // Height can be negative (top-down bitmap)
        let topDown = height < 0
        if topDown {
            height = -height
        }
        
        let planes = Int(data[26]) | (Int(data[27]) << 8)
        let bitsPerPixel = Int(data[28]) | (Int(data[29]) << 8)
        let compression = Int(data[30]) | (Int(data[31]) << 8) | (Int(data[32]) << 16) | (Int(data[33]) << 24)
        
        // Only support uncompressed BMPs for now
        guard compression == 0 else {
            return (nil, .Unknown)
        }
        
        guard width > 0 && height > 0 && width < 10000 && height < 10000 else {
            return (nil, .Unknown)
        }
        
        // Get pixel data offset
        let pixelDataOffset = Int(data[10]) | (Int(data[11]) << 8) | (Int(data[12]) << 16) | (Int(data[13]) << 24)
        
        // Read palette if present (for <= 8 bit images)
        var palette: [(r: UInt8, g: UInt8, b: UInt8)] = []
        if bitsPerPixel <= 8 {
            let numColors = 1 << bitsPerPixel
            let paletteOffset = 14 + dibHeaderSize
            
            for i in 0..<numColors {
                let offset = paletteOffset + (i * 4)
                if offset + 3 < data.count {
                    let b = data[offset]
                    let g = data[offset + 1]
                    let r = data[offset + 2]
                    // Fourth byte is reserved/alpha
                    palette.append((r, g, b))
                }
            }
        }
        
        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)
        
        // BMP rows are padded to 4-byte boundaries
        let bytesPerPixel = bitsPerPixel / 8
        let rowSize = ((bitsPerPixel * width + 31) / 32) * 4
        
        // Decode based on bit depth
        if bitsPerPixel == 24 {
            // 24-bit RGB (no alpha)
            for y in 0..<height {
                let actualY = topDown ? y : (height - 1 - y) // BMP is bottom-up by default
                let rowOffset = pixelDataOffset + (y * rowSize)
                
                for x in 0..<width {
                    let pixelOffset = rowOffset + (x * 3)
                    if pixelOffset + 2 < data.count {
                        let b = data[pixelOffset]
                        let g = data[pixelOffset + 1]
                        let r = data[pixelOffset + 2]
                        
                        let bufferIdx = (actualY * width + x) * 4
                        rgbaBuffer[bufferIdx] = r
                        rgbaBuffer[bufferIdx + 1] = g
                        rgbaBuffer[bufferIdx + 2] = b
                        rgbaBuffer[bufferIdx + 3] = 255
                    }
                }
            }
        } else if bitsPerPixel == 8 {
            // 8-bit indexed
            for y in 0..<height {
                let actualY = topDown ? y : (height - 1 - y)
                let rowOffset = pixelDataOffset + (y * rowSize)
                
                for x in 0..<width {
                    let pixelOffset = rowOffset + x
                    if pixelOffset < data.count {
                        let paletteIndex = Int(data[pixelOffset])
                        if paletteIndex < palette.count {
                            let color = palette[paletteIndex]
                            let bufferIdx = (actualY * width + x) * 4
                            rgbaBuffer[bufferIdx] = color.r
                            rgbaBuffer[bufferIdx + 1] = color.g
                            rgbaBuffer[bufferIdx + 2] = color.b
                            rgbaBuffer[bufferIdx + 3] = 255
                        }
                    }
                }
            }
        } else if bitsPerPixel == 4 {
            // 4-bit indexed (2 pixels per byte)
            for y in 0..<height {
                let actualY = topDown ? y : (height - 1 - y)
                let rowOffset = pixelDataOffset + (y * rowSize)
                
                for x in 0..<width {
                    let byteOffset = rowOffset + (x / 2)
                    if byteOffset < data.count {
                        let byte = data[byteOffset]
                        let paletteIndex = (x % 2 == 0) ? Int(byte >> 4) : Int(byte & 0x0F)
                        
                        if paletteIndex < palette.count {
                            let color = palette[paletteIndex]
                            let bufferIdx = (actualY * width + x) * 4
                            rgbaBuffer[bufferIdx] = color.r
                            rgbaBuffer[bufferIdx + 1] = color.g
                            rgbaBuffer[bufferIdx + 2] = color.b
                            rgbaBuffer[bufferIdx + 3] = 255
                        }
                    }
                }
            }
        } else if bitsPerPixel == 1 {
            // 1-bit monochrome (8 pixels per byte)
            for y in 0..<height {
                let actualY = topDown ? y : (height - 1 - y)
                let rowOffset = pixelDataOffset + (y * rowSize)
                
                for x in 0..<width {
                    let byteOffset = rowOffset + (x / 8)
                    if byteOffset < data.count {
                        let byte = data[byteOffset]
                        let bitIndex = 7 - (x % 8)
                        let bit = (byte >> bitIndex) & 1
                        
                        let color = palette[Int(bit)]
                        let bufferIdx = (actualY * width + x) * 4
                        rgbaBuffer[bufferIdx] = color.r
                        rgbaBuffer[bufferIdx + 1] = color.g
                        rgbaBuffer[bufferIdx + 2] = color.b
                        rgbaBuffer[bufferIdx + 3] = 255
                    }
                }
            }
        }
        
        guard let cgImage = createCGImage(from: rgbaBuffer, width: width, height: height) else {
            return (nil, .Unknown)
        }
        
        return (cgImage, .BMP(width: width, height: height, bitsPerPixel: bitsPerPixel))
    }
    
    // --- PCX Decoder (ZSoft PC Paintbrush format) ---
    
    static func decodePCX(data: Data) -> (image: CGImage?, type: AppleIIImageType) {
        guard data.count >= 128 else {
            return (nil, .Unknown)
        }
        
        // PCX Header (128 bytes)
        let manufacturer = data[0]  // Should be 0x0A
        let version = data[1]       // 0=v2.5, 2=v2.8 with palette, 3=v2.8 w/o palette, 5=v3.0
        let encoding = data[2]      // 1 = RLE encoding
        let bitsPerPixel = data[3]
        
        guard manufacturer == 0x0A else {
            return (nil, .Unknown)
        }
        
        // Read image dimensions (little-endian)
        let xMin = Int(data[4]) | (Int(data[5]) << 8)
        let yMin = Int(data[6]) | (Int(data[7]) << 8)
        let xMax = Int(data[8]) | (Int(data[9]) << 8)
        let yMax = Int(data[10]) | (Int(data[11]) << 8)
        
        let width = xMax - xMin + 1
        let height = yMax - yMin + 1
        
        let numPlanes = data[65]
        let bytesPerLine = Int(data[66]) | (Int(data[67]) << 8)
        
        guard width > 0 && height > 0 && width < 10000 && height < 10000 else {
            return (nil, .Unknown)
        }
        
        // Calculate total bits per pixel
        // Note: Some old PCX files have numPlanes=0, so we handle that specially
        var totalBitsPerPixel = Int(bitsPerPixel) * Int(numPlanes)
        if totalBitsPerPixel == 0 && bitsPerPixel > 0 {
            // Handle the case where numPlanes is 0 (old format)
            totalBitsPerPixel = Int(bitsPerPixel)
        }
        
        // Decompress image data (starts at byte 128)
        var decompressedData: [UInt8] = []
        var offset = 128
        
        // Calculate expected decompressed size
        // For numPlanes=0 (old format), use bytesPerLine * height
        let expectedSize: Int
        if numPlanes == 0 {
            expectedSize = bytesPerLine * height
        } else {
            expectedSize = bytesPerLine * Int(numPlanes) * height
        }
        
        // RLE decompression
        while offset < data.count && decompressedData.count < expectedSize {
            let byte = data[offset]
            offset += 1
            
            if (byte & 0xC0) == 0xC0 {
                // RLE run
                let count = Int(byte & 0x3F)
                if offset < data.count {
                    let value = data[offset]
                    offset += 1
                    for _ in 0..<count {
                        decompressedData.append(value)
                    }
                }
            } else {
                // Literal byte
                decompressedData.append(byte)
            }
        }
        
        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)
        
        // Check if there's a 256-color palette at the end
        var palette: [(r: UInt8, g: UInt8, b: UInt8)] = []
        if totalBitsPerPixel == 8 && data.count >= 769 {
            // Check for palette marker (0x0C) 769 bytes from end
            let paletteMarkerOffset = data.count - 769
            if paletteMarkerOffset >= 0 && data[paletteMarkerOffset] == 0x0C {
                // Read 256-color palette (768 bytes: 256 * 3)
                for i in 0..<256 {
                    let r = data[paletteMarkerOffset + 1 + (i * 3)]
                    let g = data[paletteMarkerOffset + 1 + (i * 3) + 1]
                    let b = data[paletteMarkerOffset + 1 + (i * 3) + 2]
                    palette.append((r, g, b))
                }
            }
        }
        
        // If no palette found, use grayscale or header palette
        if palette.isEmpty {
            if totalBitsPerPixel <= 4 {
                // Use 16-color palette from header (bytes 16-63)
                for i in 0..<16 {
                    let offset = 16 + (i * 3)
                    let r = data[offset]
                    let g = data[offset + 1]
                    let b = data[offset + 2]
                    palette.append((r, g, b))
                }
            } else {
                // Generate grayscale palette
                for i in 0..<256 {
                    let gray = UInt8(i)
                    palette.append((gray, gray, gray))
                }
            }
        }
        
        // Decode image based on bit depth
        if totalBitsPerPixel == 8 && numPlanes == 1 {
            // 8-bit indexed color
            for y in 0..<height {
                let lineOffset = y * bytesPerLine
                for x in 0..<width {
                    if lineOffset + x < decompressedData.count {
                        let paletteIndex = Int(decompressedData[lineOffset + x])
                        let color = palette[min(paletteIndex, palette.count - 1)]
                        
                        let bufferIdx = (y * width + x) * 4
                        rgbaBuffer[bufferIdx] = color.r
                        rgbaBuffer[bufferIdx + 1] = color.g
                        rgbaBuffer[bufferIdx + 2] = color.b
                        rgbaBuffer[bufferIdx + 3] = 255
                    }
                }
            }
        } else if totalBitsPerPixel == 24 && numPlanes == 3 {
            // 24-bit RGB (3 planes)
            for y in 0..<height {
                for x in 0..<width {
                    let rOffset = (y * bytesPerLine * 3) + x
                    let gOffset = (y * bytesPerLine * 3) + bytesPerLine + x
                    let bOffset = (y * bytesPerLine * 3) + (bytesPerLine * 2) + x
                    
                    var r: UInt8 = 0, g: UInt8 = 0, b: UInt8 = 0
                    if rOffset < decompressedData.count { r = decompressedData[rOffset] }
                    if gOffset < decompressedData.count { g = decompressedData[gOffset] }
                    if bOffset < decompressedData.count { b = decompressedData[bOffset] }
                    
                    let bufferIdx = (y * width + x) * 4
                    rgbaBuffer[bufferIdx] = r
                    rgbaBuffer[bufferIdx + 1] = g
                    rgbaBuffer[bufferIdx + 2] = b
                    rgbaBuffer[bufferIdx + 3] = 255
                }
            }
        } else if totalBitsPerPixel == 2 || (Int(bitsPerPixel) == 2 && Int(numPlanes) <= 1) {
            // 2-bit (4 colors) - CGA mode
            // Use default CGA palette if header palette is invalid (all same color)
            var cgaPalette: [(r: UInt8, g: UInt8, b: UInt8)] = []
            
            // Check if we need default CGA palette
            if palette.count >= 4 {
                let firstFour = Array(palette.prefix(4))
                
                // Check if all colors are the same (invalid palette)
                let allSame = firstFour.dropFirst().allSatisfy {
                    $0.r == firstFour[0].r &&
                    $0.g == firstFour[0].g &&
                    $0.b == firstFour[0].b
                }
                
                if allSame {
                    // Invalid palette - use default CGA
                    cgaPalette = [
                        (0, 0, 0),       // Black
                        (0, 255, 255),   // Cyan
                        (255, 0, 255),   // Magenta
                        (255, 255, 255)  // White
                    ]
                } else {
                    cgaPalette = firstFour
                }
            } else {
                // Default CGA palette
                cgaPalette = [
                    (0, 0, 0),       // Black
                    (0, 255, 255),   // Cyan
                    (255, 0, 255),   // Magenta
                    (255, 255, 255)  // White
                ]
            }
            
            for y in 0..<height {
                let lineOffset = y * bytesPerLine
                for x in 0..<width {
                    let byteIndex = lineOffset + (x / 4)
                    let pixelInByte = 3 - (x % 4)  // High bits first
                    
                    if byteIndex < decompressedData.count {
                        let byteVal = decompressedData[byteIndex]
                        let colorIndex = Int((byteVal >> (pixelInByte * 2)) & 0x03)
                        let color = cgaPalette[min(colorIndex, cgaPalette.count - 1)]
                        
                        let bufferIdx = (y * width + x) * 4
                        rgbaBuffer[bufferIdx] = color.r
                        rgbaBuffer[bufferIdx + 1] = color.g
                        rgbaBuffer[bufferIdx + 2] = color.b
                        rgbaBuffer[bufferIdx + 3] = 255
                    }
                }
            }
        } else if totalBitsPerPixel <= 4 {
            // 1-4 bit indexed color
            for y in 0..<height {
                let lineOffset = y * bytesPerLine
                for x in 0..<width {
                    let byteIndex = lineOffset + (x / 8)
                    let bitIndex = 7 - (x % 8)
                    
                    if byteIndex < decompressedData.count {
                        let bit = (decompressedData[byteIndex] >> bitIndex) & 1
                        let color = palette[Int(bit)]
                        
                        let bufferIdx = (y * width + x) * 4
                        rgbaBuffer[bufferIdx] = color.r
                        rgbaBuffer[bufferIdx + 1] = color.g
                        rgbaBuffer[bufferIdx + 2] = color.b
                        rgbaBuffer[bufferIdx + 3] = 255
                    }
                }
            }
        }
        
        guard let cgImage = createCGImage(from: rgbaBuffer, width: width, height: height) else {
            return (nil, .Unknown)
        }
        
        return (cgImage, .PCX(width: width, height: height, bitsPerPixel: totalBitsPerPixel))
    }
    
    // --- Amstrad CPC SCR Decoder (16384 bytes) ---
    
    // Amstrad CPC Hardware Palette (27 colors - the "real" hardware colors)
    static let amstradCPCPalette: [(r: UInt8, g: UInt8, b: UInt8)] = [
        (0x00, 0x00, 0x00),  // 0: Black
        (0x00, 0x00, 0x80),  // 1: Blue
        (0x00, 0x00, 0xFF),  // 2: Bright Blue
        (0x80, 0x00, 0x00),  // 3: Red
        (0x80, 0x00, 0x80),  // 4: Magenta
        (0x80, 0x00, 0xFF),  // 5: Mauve
        (0xFF, 0x00, 0x00),  // 6: Bright Red
        (0xFF, 0x00, 0x80),  // 7: Purple
        (0xFF, 0x00, 0xFF),  // 8: Bright Magenta
        (0x00, 0x80, 0x00),  // 9: Green
        (0x00, 0x80, 0x80),  // 10: Cyan
        (0x00, 0x80, 0xFF),  // 11: Sky Blue
        (0x80, 0x80, 0x00),  // 12: Yellow
        (0x80, 0x80, 0x80),  // 13: White (actually grey)
        (0x80, 0x80, 0xFF),  // 14: Pastel Blue
        (0xFF, 0x80, 0x00),  // 15: Orange
        (0xFF, 0x80, 0x80),  // 16: Pink
        (0xFF, 0x80, 0xFF),  // 17: Pastel Magenta
        (0x00, 0xFF, 0x00),  // 18: Bright Green
        (0x00, 0xFF, 0x80),  // 19: Sea Green
        (0x00, 0xFF, 0xFF),  // 20: Bright Cyan
        (0x80, 0xFF, 0x00),  // 21: Lime
        (0x80, 0xFF, 0x80),  // 22: Pastel Green
        (0x80, 0xFF, 0xFF),  // 23: Pastel Cyan
        (0xFF, 0xFF, 0x00),  // 24: Bright Yellow
        (0xFF, 0xFF, 0x80),  // 25: Pastel Yellow
        (0xFF, 0xFF, 0xFF)   // 26: Bright White
    ]
    
    static func decodeAmstradCPC(data: Data) -> (image: CGImage?, type: AppleIIImageType) {
        guard data.count == 16384 else {
            return (nil, .Unknown)
        }
        
        // Try to detect the mode by analyzing the data
        // Mode 0 typically has more varied data (4 bits per pixel)
        // Mode 1 is most common (2 bits per pixel)
        // For now, we'll try both and see which looks better
        // Or default to Mode 1 as it's most common
        
        // Let's decode both Mode 0 and Mode 1
        // You can add heuristics here to auto-detect, but for now try Mode 1 first
        
        // Try Mode 1 first (most common)
        if let result = decodeAmstradCPCMode1(data: data) {
            return result
        }
        
        // Fallback to Mode 0
        if let result = decodeAmstradCPCMode0(data: data) {
            return result
        }
        
        return (nil, .Unknown)
    }
    
    // Mode 0: 160x200, 16 colors (4 bits per pixel)
    static func decodeAmstradCPCMode0(data: Data) -> (image: CGImage?, type: AppleIIImageType)? {
        let width = 160
        let height = 200
        let colorsPerMode = 16
        
        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)
        
        // Default Mode 0 palette (16 colors)
        let defaultPalette: [Int] = [
            1,  // Blue
            24, // Yellow
            20, // Cyan
            6,  // Red
            0,  // Black
            26, // White
            18, // Green
            8,  // Magenta
            13, // Grey
            25, // Pastel Yellow
            23, // Pastel Cyan
            17, // Pastel Magenta
            22, // Pastel Green
            16, // Pink
            15, // Orange
            14  // Pastel Blue
        ]
        
        for y in 0..<height {
            let block = y / 8
            let lineInBlock = y % 8
            let bytesPerLine = 80  // Same as Mode 1
            let lineOffset = (block * 2048) + (lineInBlock * bytesPerLine)
            
            for xByte in 0..<bytesPerLine {
                let byteOffset = lineOffset + xByte
                if byteOffset >= data.count { continue }
                
                let dataByte = data[byteOffset]
                
                // Mode 0: Each byte contains 2 pixels (4 bits each)
                // Bit order: pixel 0 uses bits 7,5,3,1 and pixel 1 uses bits 6,4,2,0
                
                for pixel in 0..<2 {
                    let x = xByte * 2 + pixel
                    if x >= width { continue }
                    
                    // Extract 4-bit color value with CPC's bit order
                    let nibble: UInt8
                    if pixel == 0 {
                        // Bits 7,5,3,1 (odd bits)
                        nibble = ((dataByte >> 7) & 1) << 3 |
                                 ((dataByte >> 5) & 1) << 2 |
                                 ((dataByte >> 3) & 1) << 1 |
                                 ((dataByte >> 1) & 1)
                    } else {
                        // Bits 6,4,2,0 (even bits)
                        nibble = ((dataByte >> 6) & 1) << 3 |
                                 ((dataByte >> 4) & 1) << 2 |
                                 ((dataByte >> 2) & 1) << 1 |
                                 ((dataByte >> 0) & 1)
                    }
                    
                    let paletteIndex = Int(nibble)
                    let hardwareColor = defaultPalette[paletteIndex]
                    let rgb = amstradCPCPalette[hardwareColor]
                    
                    let bufferIdx = (y * width + x) * 4
                    rgbaBuffer[bufferIdx] = rgb.r
                    rgbaBuffer[bufferIdx + 1] = rgb.g
                    rgbaBuffer[bufferIdx + 2] = rgb.b
                    rgbaBuffer[bufferIdx + 3] = 255
                }
            }
        }
        
        guard let cgImage = createCGImage(from: rgbaBuffer, width: width, height: height) else {
            return nil
        }
        
        return (cgImage, .AmstradCPC(mode: 0, colors: colorsPerMode))
    }
    
    // Mode 1: 320x200, 4 colors (2 bits per pixel)
    static func decodeAmstradCPCMode1(data: Data) -> (image: CGImage?, type: AppleIIImageType)? {
        let width = 320
        let height = 200
        let colorsPerMode = 4
        
        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)
        
        // Default Mode 1 palette
        let defaultPalette: [Int] = [1, 24, 20, 6] // Blue, Yellow, Cyan, Red
        
        for y in 0..<height {
            let block = y / 8
            let lineInBlock = y % 8
            let bytesPerLine = 80
            let lineOffset = (block * 2048) + (lineInBlock * bytesPerLine)
            
            for xByte in 0..<bytesPerLine {
                let byteOffset = lineOffset + xByte
                if byteOffset >= data.count { continue }
                
                let dataByte = data[byteOffset]
                
                // Mode 1: Each byte contains 4 pixels (2 bits each)
                for pixel in 0..<4 {
                    let x = xByte * 4 + pixel
                    if x >= width { continue }
                    
                    let bitPair: UInt8
                    switch pixel {
                    case 0: bitPair = ((dataByte >> 7) & 1) << 1 | ((dataByte >> 3) & 1)
                    case 1: bitPair = ((dataByte >> 6) & 1) << 1 | ((dataByte >> 2) & 1)
                    case 2: bitPair = ((dataByte >> 5) & 1) << 1 | ((dataByte >> 1) & 1)
                    case 3: bitPair = ((dataByte >> 4) & 1) << 1 | ((dataByte >> 0) & 1)
                    default: bitPair = 0
                    }
                    
                    let paletteIndex = Int(bitPair)
                    let hardwareColor = defaultPalette[paletteIndex]
                    let rgb = amstradCPCPalette[hardwareColor]
                    
                    let bufferIdx = (y * width + x) * 4
                    rgbaBuffer[bufferIdx] = rgb.r
                    rgbaBuffer[bufferIdx + 1] = rgb.g
                    rgbaBuffer[bufferIdx + 2] = rgb.b
                    rgbaBuffer[bufferIdx + 3] = 255
                }
            }
        }
        
        guard let cgImage = createCGImage(from: rgbaBuffer, width: width, height: height) else {
            return nil
        }
        
        return (cgImage, .AmstradCPC(mode: 1, colors: colorsPerMode))
    }
    
    // --- ZX Spectrum SCR Decoder (256x192, 6912 bytes) ---
    
    // ZX Spectrum Palette (BRIGHT 0 and BRIGHT 1)
    static let zxSpectrumPalette: [(r: UInt8, g: UInt8, b: UInt8)] = [
        // Normal intensity (BRIGHT 0)
        (0x00, 0x00, 0x00),  // 0: Black
        (0x00, 0x00, 0xD7),  // 1: Blue
        (0xD7, 0x00, 0x00),  // 2: Red
        (0xD7, 0x00, 0xD7),  // 3: Magenta
        (0x00, 0xD7, 0x00),  // 4: Green
        (0x00, 0xD7, 0xD7),  // 5: Cyan
        (0xD7, 0xD7, 0x00),  // 6: Yellow
        (0xD7, 0xD7, 0xD7),  // 7: White
        // Bright intensity (BRIGHT 1)
        (0x00, 0x00, 0x00),  // 8: Black (bright)
        (0x00, 0x00, 0xFF),  // 9: Blue (bright)
        (0xFF, 0x00, 0x00),  // 10: Red (bright)
        (0xFF, 0x00, 0xFF),  // 11: Magenta (bright)
        (0x00, 0xFF, 0x00),  // 12: Green (bright)
        (0x00, 0xFF, 0xFF),  // 13: Cyan (bright)
        (0xFF, 0xFF, 0x00),  // 14: Yellow (bright)
        (0xFF, 0xFF, 0xFF)   // 15: White (bright)
    ]
    
    static func decodeZXSpectrum(data: Data) -> (image: CGImage?, type: AppleIIImageType) {
        guard data.count == 6912 else {
            return (nil, .Unknown)
        }
        
        let width = 256
        let height = 192
        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)
        
        // ZX Spectrum memory layout:
        // 6144 bytes: Bitmap (256x192, 1 bit per pixel)
        // 768 bytes: Color attributes (32x24 cells, 8x8 pixels each)
        
        let bitmapOffset = 0
        let attributeOffset = 6144
        
        // Decode the screen
        // The bitmap has a weird memory layout for historical reasons:
        // It's divided into 3 sections of 2048 bytes each (top, middle, bottom third)
        // Within each section, lines are interleaved in a complex pattern
        
        for y in 0..<height {
            // Calculate the byte offset for this scanline in the weird ZX memory layout
            // The screen is divided into thirds (each 64 lines)
            let third = y / 64          // Which third (0, 1, 2)
            let lineInThird = y % 64
            let octave = lineInThird / 8   // Which 8-line block within the third
            let lineInOctave = lineInThird % 8
            
            // Calculate bitmap address
            let bitmapLineOffset = bitmapOffset + (third * 2048) + (lineInOctave * 256) + (octave * 32)
            
            // Calculate which attribute row this line belongs to
            let attrY = y / 8
            
            for x in 0..<width {
                let xByte = x / 8
                let xBit = 7 - (x % 8)
                
                // Get bitmap byte
                let bitmapByteOffset = bitmapLineOffset + xByte
                let bitmapByte = data[bitmapByteOffset]
                let pixelBit = (bitmapByte >> xBit) & 1
                
                // Get attribute byte (8x8 cell)
                let attrX = x / 8
                let attrIndex = attributeOffset + (attrY * 32) + attrX
                let attrByte = data[attrIndex]
                
                // Decode attribute byte:
                // Bit 7: FLASH (we'll ignore for static image)
                // Bit 6: BRIGHT (0 = normal, 1 = bright)
                // Bits 5-3: PAPER (background) color
                // Bits 2-0: INK (foreground) color
                
                let flash = (attrByte >> 7) & 1
                let bright = (attrByte >> 6) & 1
                let paper = (attrByte >> 3) & 0x07
                let ink = attrByte & 0x07
                
                // Add 8 to color index if BRIGHT is set
                let paperColor = Int(paper) + (bright == 1 ? 8 : 0)
                let inkColor = Int(ink) + (bright == 1 ? 8 : 0)
                
                // Select color based on pixel bit
                let colorIndex = (pixelBit == 1) ? inkColor : paperColor
                let rgb = zxSpectrumPalette[colorIndex]
                
                let bufferIdx = (y * width + x) * 4
                rgbaBuffer[bufferIdx] = rgb.r
                rgbaBuffer[bufferIdx + 1] = rgb.g
                rgbaBuffer[bufferIdx + 2] = rgb.b
                rgbaBuffer[bufferIdx + 3] = 255
            }
        }
        
        guard let cgImage = createCGImage(from: rgbaBuffer, width: width, height: height) else {
            return (nil, .Unknown)
        }
        
        return (cgImage, .ZXSpectrum)
    }
    
    // C64 HIRES Format - 9009 bytes (Art Studio variant or similar)
    // Format: 2 bytes load address + 8000 bytes bitmap + 1000 bytes screen RAM + 7 bytes extra
    static func decodeC64Hires(data: Data) -> (image: CGImage?, type: AppleIIImageType) {
        guard data.count == 9009 else {
            return (nil, .Unknown)
        }
        
        let width = 320
        let height = 200
        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)
        
        let bitmapOffset = 2
        let screenRAMOffset = 8002
        
        // Decode as HIRES (1 bit per pixel)
        for cellY in 0..<25 {
            for cellX in 0..<40 {
                let cellIndex = cellY * 40 + cellX
                
                // Screen RAM contains foreground (low nybble) and background (high nybble) colors
                let screenByte = data[screenRAMOffset + cellIndex]
                let bgColor = Int((screenByte >> 4) & 0x0F)
                let fgColor = Int(screenByte & 0x0F)
                
                for row in 0..<8 {
                    let bitmapByteOffset = bitmapOffset + (cellIndex * 8) + row
                    if bitmapByteOffset >= data.count { continue }
                    
                    let bitmapByte = data[bitmapByteOffset]
                    let y = cellY * 8 + row
                    
                    // Each bit is one pixel (320 pixels wide)
                    for bit in 0..<8 {
                        let x = cellX * 8 + bit
                        let bitVal = (bitmapByte >> (7 - bit)) & 1
                        let colorIndex = (bitVal == 0) ? fgColor : bgColor  // Inverted: 0 = foreground
                        
                        let rgb = c64Palette[colorIndex]
                        let bufferIdx = (y * width + x) * 4
                        
                        if bufferIdx + 3 < rgbaBuffer.count {
                            rgbaBuffer[bufferIdx] = rgb.r
                            rgbaBuffer[bufferIdx + 1] = rgb.g
                            rgbaBuffer[bufferIdx + 2] = rgb.b
                            rgbaBuffer[bufferIdx + 3] = 255
                        }
                    }
                }
            }
        }
        
        guard let cgImage = createCGImage(from: rgbaBuffer, width: width, height: height) else {
            return (nil, .Unknown)
        }
        
        return (cgImage, .C64(format: "C64 HIRES"))
    }
    
    // --- Commodore 64 Decoders ---
    
    // C64 Color Palette (16 colors)
    static let c64Palette: [(r: UInt8, g: UInt8, b: UInt8)] = [
        (0x00, 0x00, 0x00),  // 0: Black
        (0xFF, 0xFF, 0xFF),  // 1: White
        (0x68, 0x37, 0x2B),  // 2: Red
        (0x70, 0xA4, 0xB2),  // 3: Cyan
        (0x6F, 0x3D, 0x86),  // 4: Purple
        (0x58, 0x8D, 0x43),  // 5: Green
        (0x35, 0x28, 0x79),  // 6: Blue
        (0xB8, 0xC7, 0x6F),  // 7: Yellow
        (0x6F, 0x4F, 0x25),  // 8: Orange
        (0x43, 0x39, 0x00),  // 9: Brown
        (0x9A, 0x67, 0x59),  // 10: Light Red
        (0x44, 0x44, 0x44),  // 11: Dark Grey
        (0x6C, 0x6C, 0x6C),  // 12: Grey
        (0x9A, 0xD2, 0x84),  // 13: Light Green
        (0x6C, 0x5E, 0xB5),  // 14: Light Blue
        (0x95, 0x95, 0x95)   // 15: Light Grey
    ]
    
    // Koala Painter (.KOA, .KLA) - 10003 bytes
    // Format: 2 bytes load address + 8000 bytes bitmap + 1000 bytes screen RAM + 1000 bytes color RAM + 1 byte background
    static func decodeC64Koala(data: Data) -> (image: CGImage?, type: AppleIIImageType) {
        // Koala files are nominally 10003 bytes, but some have 2-7 extra padding bytes
        guard data.count >= 10003 && data.count <= 10010 else {
            return (nil, .Unknown)
        }
        
        let width = 320
        let height = 200
        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)
        
        // Koala format offsets
        let bitmapOffset = 2           // Skip load address
        let screenRAMOffset = 8002     // Bitmap + load address
        let colorRAMOffset = 9002      // + screen RAM
        let backgroundOffset = 10002   // + color RAM
        
        let backgroundColor = data[backgroundOffset] & 0x0F
        
        // Decode bitmap (160x200 cells, each 4x8 pixels)
        for cellY in 0..<25 {  // 25 rows of cells
            for cellX in 0..<40 {  // 40 columns of cells
                let cellIndex = cellY * 40 + cellX
                
                // Get color information for this cell
                let screenByte = data[screenRAMOffset + cellIndex]
                let colorByte = data[colorRAMOffset + cellIndex]
                
                // Extract the 4 colors for this cell
                let color0 = backgroundColor  // Background (00)
                let color1 = (screenByte >> 4) & 0x0F  // Upper nybble (01)
                let color2 = screenByte & 0x0F         // Lower nybble (10)
                let color3 = colorByte & 0x0F          // Color RAM (11)
                
                let colors = [color0, color1, color2, color3]
                
                // Decode 8 rows of 4 pixels each
                for row in 0..<8 {
                    let bitmapByteOffset = bitmapOffset + (cellIndex * 8) + row
                    if bitmapByteOffset >= data.count { continue }
                    
                    let bitmapByte = data[bitmapByteOffset]
                    let y = cellY * 8 + row
                    
                    // Decode 4 pixels (2 bits per pixel)
                    for pixelPair in 0..<4 {
                        let x = cellX * 8 + (pixelPair * 2)
                        let bitShift = 6 - (pixelPair * 2)
                        let colorIndex = Int((bitmapByte >> bitShift) & 0x03)
                        
                        let c64Color = Int(colors[colorIndex])
                        let rgb = c64Palette[c64Color]
                        
                        // Each C64 pixel is 2 screen pixels wide (multicolor mode)
                        for dx in 0..<2 {
                            let bufferIdx = (y * width + x + dx) * 4
                            if bufferIdx + 3 < rgbaBuffer.count {
                                rgbaBuffer[bufferIdx] = rgb.r
                                rgbaBuffer[bufferIdx + 1] = rgb.g
                                rgbaBuffer[bufferIdx + 2] = rgb.b
                                rgbaBuffer[bufferIdx + 3] = 255
                            }
                        }
                    }
                }
            }
        }
        
        guard let cgImage = createCGImage(from: rgbaBuffer, width: width, height: height) else {
            return (nil, .Unknown)
        }
        
        return (cgImage, .C64(format: "Koala Painter"))
    }
    
    // C64 FLI (Flexible Line Interpretation) - ~16000 bytes with BASIC loader
    // FLI allows changing colors every line instead of every 8 lines
    // Note: FLI decoding is experimental - some images may not display perfectly
    
    // Advanced Art Studio (.ART, .OCP) - 10018 bytes
    // Note: Many 10018 byte files are actually Koala format with 15 extra bytes
    // This decoder treats them as standard Koala layout
    static func decodeC64ArtStudio(data: Data) -> (image: CGImage?, type: AppleIIImageType) {
        guard data.count == 10018 else {
            return (nil, .Unknown)
        }
        
        let width = 320
        let height = 200
        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)
        
        // Standard Koala offsets (10018 byte variant)
        let bitmapOffset = 2
        let screenRAMOffset = 8002
        let colorRAMOffset = 9002
        let backgroundOffset = 10002
        
        let backgroundColor = data[backgroundOffset] & 0x0F
        
        // Decode using standard Koala algorithm
        for cellY in 0..<25 {
            for cellX in 0..<40 {
                let cellIndex = cellY * 40 + cellX
                
                let screenByte = data[screenRAMOffset + cellIndex]
                let colorByte = data[colorRAMOffset + cellIndex]
                
                let color0 = backgroundColor
                let color1 = (screenByte >> 4) & 0x0F
                let color2 = screenByte & 0x0F
                let color3 = colorByte & 0x0F
                
                let colors = [color0, color1, color2, color3]
                
                for row in 0..<8 {
                    let bitmapByteOffset = bitmapOffset + (cellIndex * 8) + row
                    if bitmapByteOffset >= data.count { continue }
                    
                    let bitmapByte = data[bitmapByteOffset]
                    let y = cellY * 8 + row
                    
                    for pixelPair in 0..<4 {
                        let x = cellX * 8 + (pixelPair * 2)
                        let bitShift = 6 - (pixelPair * 2)
                        let colorIndex = Int((bitmapByte >> bitShift) & 0x03)
                        
                        let c64Color = Int(colors[colorIndex])
                        let rgb = c64Palette[c64Color]
                        
                        for dx in 0..<2 {
                            let bufferIdx = (y * width + x + dx) * 4
                            if bufferIdx + 3 < rgbaBuffer.count {
                                rgbaBuffer[bufferIdx] = rgb.r
                                rgbaBuffer[bufferIdx + 1] = rgb.g
                                rgbaBuffer[bufferIdx + 2] = rgb.b
                                rgbaBuffer[bufferIdx + 3] = 255
                            }
                        }
                    }
                }
            }
        }
        
        guard let cgImage = createCGImage(from: rgbaBuffer, width: width, height: height) else {
            return (nil, .Unknown)
        }
        
        return (cgImage, .C64(format: "C64 Multicolor (10018 bytes)"))
    }
    
    // --- Atari ST Degas Decoder (.PI1, .PI2, .PI3) ---
    static func decodeDegas(data: Data) -> (image: CGImage?, type: AppleIIImageType) {
        guard data.count >= 34 else {
            return (nil, .Unknown)
        }
        
        // Read resolution mode (0 = low, 1 = medium, 2 = high)
        let resolutionMode = Int(readBigEndianUInt16(data: data, offset: 0))
        
        let width: Int
        let height: Int
        let numPlanes: Int
        let numColors: Int
        let resolutionName: String
        
        switch resolutionMode {
        case 0: // Low res: 320x200, 16 colors (4 bitplanes)
            width = 320
            height = 200
            numPlanes = 4
            numColors = 16
            resolutionName = "Low"
            
        case 1: // Medium res: 640x200, 4 colors (2 bitplanes)
            width = 640
            height = 200
            numPlanes = 2
            numColors = 4
            resolutionName = "Medium"
            
        case 2: // High res: 640x400, 2 colors (1 bitplane, monochrome)
            width = 640
            height = 400
            numPlanes = 1
            numColors = 2
            resolutionName = "High"
            
        default:
            return (nil, .Unknown)
        }
        
        // Read palette (16 ST color words starting at offset 2)
        var palette: [(r: UInt8, g: UInt8, b: UInt8)] = []
        for i in 0..<16 {
            let colorWord = readBigEndianUInt16(data: data, offset: 2 + (i * 2))
            
            // Atari ST color format: 0x0RGB (4 bits per channel, 0-7 range)
            let r4 = (colorWord >> 8) & 0x07
            let g4 = (colorWord >> 4) & 0x07
            let b4 = colorWord & 0x07
            
            // Scale from 0-7 to 0-255
            let r = UInt8((r4 * 255) / 7)
            let g = UInt8((g4 * 255) / 7)
            let b = UInt8((b4 * 255) / 7)
            
            palette.append((r, g, b))
        }
        
        // Image data starts at offset 34
        let imageDataOffset = 34
        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)
        
        // Degas uses interleaved bitplanes per 16-pixel chunk (word)
        let wordsPerLine = width / 16
        let bytesPerLine = wordsPerLine * numPlanes * 2
        
        for y in 0..<height {
            let lineOffset = imageDataOffset + (y * bytesPerLine)
            
            for wordIdx in 0..<wordsPerLine {
                // Read all bitplanes for this 16-pixel word
                var planeWords: [UInt16] = []
                for plane in 0..<numPlanes {
                    let offset = lineOffset + (wordIdx * numPlanes * 2) + (plane * 2)
                    if offset + 1 < data.count {
                        planeWords.append(readBigEndianUInt16(data: data, offset: offset))
                    } else {
                        planeWords.append(0)
                    }
                }
                
                // Decode 16 pixels from the bitplane words
                for bit in 0..<16 {
                    let x = wordIdx * 16 + bit
                    if x >= width { break }
                    
                    let bitPos = 15 - bit
                    var colorIndex = 0
                    
                    // Build color index from bitplanes
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
        
        guard let cgImage = createCGImage(from: rgbaBuffer, width: width, height: height) else {
            return (nil, .Unknown)
        }
        
        return (cgImage, .DEGAS(resolution: resolutionName, colors: numColors))
    }
    
    // --- IFF/ILBM Decoder (Amiga Format) ---
    static func decodeIFF(data: Data) -> (image: CGImage?, type: AppleIIImageType) {
        guard data.count >= 12 else {
            return (nil, .Unknown)
        }
        
        // Verify FORM header
        guard let formHeader = String(data: data.subdata(in: 0..<4), encoding: .ascii),
              formHeader == "FORM" else {
            return (nil, .Unknown)
        }
        
        // Read file size (big-endian)
        let fileSize = readBigEndianUInt32(data: data, offset: 4)
        
        // Verify ILBM type
        guard let ilbmType = String(data: data.subdata(in: 8..<12), encoding: .ascii),
              ilbmType == "ILBM" else {
            return (nil, .Unknown)
        }
        
        var offset = 12
        var width = 0
        var height = 0
        var numPlanes = 0
        var compression: UInt8 = 0
        var palette: [(r: UInt8, g: UInt8, b: UInt8)] = []
        var bodyOffset = 0
        var bodySize = 0
        var masking: UInt8 = 0
        
        // Parse IFF chunks
        while offset + 8 <= data.count {
            guard let chunkID = String(data: data.subdata(in: offset..<offset+4), encoding: .ascii) else {
                break
            }
            
            let chunkSize = Int(readBigEndianUInt32(data: data, offset: offset + 4))
            offset += 8
            
            if offset + chunkSize > data.count {
                break
            }
            
            switch chunkID {
            case "BMHD": // Bitmap Header
                if chunkSize >= 20 {
                    width = Int(readBigEndianUInt16(data: data, offset: offset))
                    height = Int(readBigEndianUInt16(data: data, offset: offset + 2))
                    numPlanes = Int(data[offset + 8])
                    masking = data[offset + 9]
                    compression = data[offset + 10]
                }
                
            case "CMAP": // Color Map
                let numColors = chunkSize / 3
                for i in 0..<numColors {
                    let colorOffset = offset + (i * 3)
                    if colorOffset + 2 < data.count {
                        let r = data[colorOffset]
                        let g = data[colorOffset + 1]
                        let b = data[colorOffset + 2]
                        palette.append((r, g, b))
                    }
                }
                
            case "BODY": // Image Data
                bodyOffset = offset
                bodySize = chunkSize
            
            default:
                break
            }
            
            // Move to next chunk (aligned to even boundary)
            offset += chunkSize
            if chunkSize % 2 == 1 {
                offset += 1
            }
        }
        
        // Validate we have all required data
        guard width > 0, height > 0, numPlanes > 0, bodyOffset > 0 else {
            return (nil, .Unknown)
        }
        
        // Check if this is 24-bit RGB (24 or 25 planes with masking)
        let is24Bit = (numPlanes == 24 || numPlanes == 25 || (numPlanes == 32))
        
        // Decode the image
        let cgImage: CGImage?
        if is24Bit {
            cgImage = decodeILBM24Body(
                data: data,
                bodyOffset: bodyOffset,
                bodySize: bodySize,
                width: width,
                height: height,
                numPlanes: numPlanes,
                compression: compression,
                masking: masking
            )
        } else {
            cgImage = decodeILBMBody(
                data: data,
                bodyOffset: bodyOffset,
                bodySize: bodySize,
                width: width,
                height: height,
                numPlanes: numPlanes,
                compression: compression,
                palette: palette
            )
        }
        
        guard let finalImage = cgImage else {
            return (nil, .Unknown)
        }
        
        // Aspect ratio correction for Amiga interlaced modes with non-square pixels
        // Low-res interlaced (320x400): pixels are 2x taller than wide
        // Correct display: double the width (320x400 -> 640x400)
        let aspectRatio = Double(height) / Double(width)
        var correctedImage = finalImage
        
        if aspectRatio > 1.2 {
            // Interlaced mode detected - double width to correct aspect ratio
            let correctedWidth = width * 2
            
            // Use NSImage for more reliable scaling
            let nsImage = NSImage(cgImage: finalImage, size: NSSize(width: width, height: height))
            let newSize = NSSize(width: correctedWidth, height: height)
            
            if let scaledRep = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: Int(newSize.width),
                pixelsHigh: Int(newSize.height),
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: Int(newSize.width) * 4,
                bitsPerPixel: 32
            ) {
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: scaledRep)
                NSGraphicsContext.current?.imageInterpolation = .none
                nsImage.draw(in: NSRect(origin: .zero, size: newSize))
                NSGraphicsContext.restoreGraphicsState()
                
                if let scaled = scaledRep.cgImage {
                    correctedImage = scaled
                }
            }
        }
        
        let colorDescription = is24Bit ? "24-bit RGB" : "\(1 << numPlanes) colors"
        return (correctedImage, .IFF(width: width, height: height, colors: colorDescription))
    }
    
    static func decodeILBM24Body(data: Data, bodyOffset: Int, bodySize: Int, width: Int, height: Int, numPlanes: Int, compression: UInt8, masking: UInt8) -> CGImage? {
        
        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)
        var srcOffset = bodyOffset
        
        let bytesPerRow = ((width + 15) / 16) * 2
        let planesPerChannel = 8
        
        // 24-bit IFF uses interleaved bitplanes per scanline:
        // For each row: R0-R7, G0-G7, B0-B7 (8 planes per color channel)
        
        for y in 0..<height {
            var planeBits: [[UInt8]] = Array(repeating: [], count: numPlanes)
            
            // Read all 24 bitplanes for this scanline
            for plane in 0..<numPlanes {
                var rowData: [UInt8] = []
                
                if compression == 1 { // RLE compression (ByteRun1)
                    var bytesRead = 0
                    while bytesRead < bytesPerRow && srcOffset < bodyOffset + bodySize && srcOffset < data.count {
                        let cmd = Int8(bitPattern: data[srcOffset])
                        srcOffset += 1
                        
                        if cmd >= 0 {
                            // Literal run: copy next (cmd + 1) bytes
                            let count = Int(cmd) + 1
                            for _ in 0..<count {
                                if srcOffset < bodyOffset + bodySize && srcOffset < data.count && bytesRead < bytesPerRow {
                                    rowData.append(data[srcOffset])
                                    srcOffset += 1
                                    bytesRead += 1
                                }
                            }
                        } else if cmd != -128 {
                            // Repeat run: repeat next byte (-cmd + 1) times
                            let count = Int(-cmd) + 1
                            if srcOffset < bodyOffset + bodySize && srcOffset < data.count {
                                let repeatByte = data[srcOffset]
                                srcOffset += 1
                                for _ in 0..<count {
                                    if bytesRead < bytesPerRow {
                                        rowData.append(repeatByte)
                                        bytesRead += 1
                                    }
                                }
                            }
                        }
                        // cmd == -128 is NOP, skip it
                    }
                } else {
                    // No compression
                    for _ in 0..<bytesPerRow {
                        if srcOffset < bodyOffset + bodySize && srcOffset < data.count {
                            rowData.append(data[srcOffset])
                            srcOffset += 1
                        }
                    }
                }
                
                planeBits[plane] = rowData
            }
            
            // Convert 24 bitplanes to RGB pixels for this scanline
            for x in 0..<width {
                let byteIndex = x / 8
                let bitIndex = 7 - (x % 8)
                
                var r: UInt8 = 0
                var g: UInt8 = 0
                var b: UInt8 = 0
                
                // Extract R, G, B values from their respective 8 bitplanes
                // Red: planes 0-7 (LSB in plane 0, MSB in plane 7)
                for bit in 0..<planesPerChannel {
                    let plane = bit
                    if plane < planeBits.count && byteIndex < planeBits[plane].count {
                        let bitVal = (planeBits[plane][byteIndex] >> bitIndex) & 1
                        r |= bitVal << bit  // LSB first!
                    }
                }
                
                // Green: planes 8-15 (LSB first)
                for bit in 0..<planesPerChannel {
                    let plane = planesPerChannel + bit
                    if plane < planeBits.count && byteIndex < planeBits[plane].count {
                        let bitVal = (planeBits[plane][byteIndex] >> bitIndex) & 1
                        g |= bitVal << bit  // LSB first!
                    }
                }
                
                // Blue: planes 16-23 (LSB first)
                for bit in 0..<planesPerChannel {
                    let plane = 2 * planesPerChannel + bit
                    if plane < planeBits.count && byteIndex < planeBits[plane].count {
                        let bitVal = (planeBits[plane][byteIndex] >> bitIndex) & 1
                        b |= bitVal << bit  // LSB first!
                    }
                }
                
                let bufferIdx = (y * width + x) * 4
                rgbaBuffer[bufferIdx] = r
                rgbaBuffer[bufferIdx + 1] = g
                rgbaBuffer[bufferIdx + 2] = b
                rgbaBuffer[bufferIdx + 3] = 255
            }
        }
        
        return createCGImage(from: rgbaBuffer, width: width, height: height)
    }
    
    static func decodeILBMBody(data: Data, bodyOffset: Int, bodySize: Int, width: Int, height: Int, numPlanes: Int, compression: UInt8, palette: [(r: UInt8, g: UInt8, b: UInt8)]) -> CGImage? {
        
        let bytesPerRow = ((width + 15) / 16) * 2 // Round up to word boundary
        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)
        
        // Create default palette if none provided
        var finalPalette = palette
        let numColors = 1 << numPlanes
        
        if finalPalette.isEmpty || finalPalette.count < numColors {
            // Generate grayscale palette
            finalPalette = []
            for i in 0..<numColors {
                let gray = UInt8((i * 255) / (numColors - 1))
                finalPalette.append((gray, gray, gray))
            }
        }
        
        var srcOffset = bodyOffset
        
        for y in 0..<height {
            var planeBits: [[UInt8]] = Array(repeating: [], count: numPlanes)
            
            // Read each bitplane for this row
            for plane in 0..<numPlanes {
                var rowData: [UInt8] = []
                
                if compression == 1 { // RLE compression
                    var bytesRead = 0
                    while bytesRead < bytesPerRow && srcOffset < bodyOffset + bodySize {
                        let cmd = Int8(bitPattern: data[srcOffset])
                        srcOffset += 1
                        
                        if cmd >= 0 {
                            // Copy next (cmd + 1) bytes literally
                            let count = Int(cmd) + 1
                            for _ in 0..<count {
                                if srcOffset < bodyOffset + bodySize && bytesRead < bytesPerRow {
                                    rowData.append(data[srcOffset])
                                    srcOffset += 1
                                    bytesRead += 1
                                }
                            }
                        } else if cmd != -128 {
                            // Repeat next byte (-cmd + 1) times
                            let count = Int(-cmd) + 1
                            if srcOffset < bodyOffset + bodySize {
                                let repeatByte = data[srcOffset]
                                srcOffset += 1
                                for _ in 0..<count {
                                    if bytesRead < bytesPerRow {
                                        rowData.append(repeatByte)
                                        bytesRead += 1
                                    }
                                }
                            }
                        }
                    }
                } else {
                    // No compression
                    for _ in 0..<bytesPerRow {
                        if srcOffset < bodyOffset + bodySize {
                            rowData.append(data[srcOffset])
                            srcOffset += 1
                        }
                    }
                }
                
                planeBits[plane] = rowData
            }
            
            // Convert bitplanes to pixels
            for x in 0..<width {
                let byteIndex = x / 8
                let bitIndex = 7 - (x % 8)
                
                var colorIndex = 0
                for plane in 0..<numPlanes {
                    if byteIndex < planeBits[plane].count {
                        let bit = (planeBits[plane][byteIndex] >> bitIndex) & 1
                        colorIndex |= Int(bit) << plane
                    }
                }
                
                let color = finalPalette[min(colorIndex, finalPalette.count - 1)]
                let bufferIdx = (y * width + x) * 4
                
                rgbaBuffer[bufferIdx] = color.r
                rgbaBuffer[bufferIdx + 1] = color.g
                rgbaBuffer[bufferIdx + 2] = color.b
                rgbaBuffer[bufferIdx + 3] = 255
            }
        }
        
        return createCGImage(from: rgbaBuffer, width: width, height: height)
    }
    
    // Helper functions for reading big-endian values
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
    
    // --- DHGR Decoder (560x192, 16KB) ---
    static func decodeDHGR(data: Data) -> CGImage? {
        let width = 560
        let height = 192
        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)
        
        guard data.count >= 16384 else { return nil }
        
        let mainData = data.subdata(in: 0..<8192)
        let auxData = data.subdata(in: 8192..<16384)
        
        let dhgrPalette: [(r: UInt8, g: UInt8, b: UInt8)] = [
            (0, 0, 0),           // 0: Black
            (134, 18, 192),      // 1: Lila/Violett
            (0, 101, 43),        // 2: Dunkelgrün
            (48, 48, 255),       // 3: Blau
            (165, 95, 0),        // 4: Braun
            (172, 172, 172),     // 5: Hellgrau
            (0, 226, 0),         // 6: Hellgrün
            (0, 255, 146),       // 7: Cyan
            (224, 0, 39),        // 8: Rot
            (223, 17, 212),      // 9: Magenta
            (81, 81, 81),        // 10: Dunkelgrau
            (78, 158, 255),      // 11: Hellblau
            (255, 39, 0),        // 12: Orange
            (255, 150, 153),     // 13: Rosa
            (255, 253, 0),       // 14: Gelb
            (255, 255, 255)      // 15: White
        ]
        
        for y in 0..<height {
            let base = (y & 0x07) << 10
            let row = (y >> 3) & 0x07
            let block = (y >> 6) & 0x03
            let offset = base | (row << 7) | (block * 40)
            
            guard offset + 40 <= 8192 else { continue }
            
            var bits: [UInt8] = []
            for xByte in 0..<40 {
                let mainByte = mainData[offset + xByte]
                let auxByte = auxData[offset + xByte]
                
                for bitPos in 0..<7 {
                    bits.append((mainByte >> bitPos) & 0x1)
                }
                for bitPos in 0..<7 {
                    bits.append((auxByte >> bitPos) & 0x1)
                }
            }
            
            var pixelX = 0
            var bitIndex = 0
            
            while bitIndex + 3 < bits.count && pixelX < width {
                let bit0 = bits[bitIndex]
                let bit1 = bits[bitIndex + 1]
                let bit2 = bits[bitIndex + 2]
                let bit3 = bits[bitIndex + 3]
                
                let colorIndex = Int(bit0 | (bit1 << 1) | (bit2 << 2) | (bit3 << 3))
                let color = dhgrPalette[colorIndex]
                
                for _ in 0..<4 {
                    let bufferIdx = (y * width + pixelX) * 4
                    if bufferIdx + 3 < rgbaBuffer.count && pixelX < width {
                        rgbaBuffer[bufferIdx] = color.r
                        rgbaBuffer[bufferIdx + 1] = color.g
                        rgbaBuffer[bufferIdx + 2] = color.b
                        rgbaBuffer[bufferIdx + 3] = 255
                    }
                    pixelX += 1
                }
                
                bitIndex += 4
            }
        }
        
        guard let fullImage = createCGImage(from: rgbaBuffer, width: width, height: height) else {
            return nil
        }
        
        return scaleCGImage(fullImage, to: CGSize(width: 280, height: 192))
    }
    
    // --- HGR Decoder (280x192, 8KB) ---
    static func decodeHGR(data: Data) -> CGImage? {
        let width = 280
        let height = 192
        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)
        
        let hgrColors: [(r: UInt8, g: UInt8, b: UInt8)] = [
            (0, 0, 0),       // 0: Schwarz
            (255, 255, 255), // 1: Weiß
            (32, 192, 32),   // 2: Grün
            (160, 32, 240),  // 3: Violett
            (255, 100, 0),   // 4: Orange
            (60, 60, 255)    // 5: Blau
        ]
        
        guard data.count >= 8184 else { return nil }

        for y in 0..<height {
            let i = y % 8
            let j = (y / 8) % 8
            let k = y / 64
            
            let fileOffset = (i * 1024) + (j * 128) + (k * 40)
            
            guard fileOffset + 40 <= data.count else { continue }
            
            for xByte in 0..<40 {
                let currentByte = data[fileOffset + xByte]
                let nextByte: UInt8 = (xByte + 1 < 40) ? data[fileOffset + xByte + 1] : 0
                
                let highBit = (currentByte >> 7) & 0x1
                
                for bitIndex in 0..<7 {
                    let pixelIndex = (xByte * 7) + bitIndex
                    let bufferIdx = (y * width + pixelIndex) * 4
                    
                    let bitA = (currentByte >> bitIndex) & 0x1
                    
                    let bitB: UInt8
                    if bitIndex == 6 {
                        bitB = (nextByte >> 0) & 0x1
                    } else {
                        bitB = (currentByte >> (bitIndex + 1)) & 0x1
                    }
                    
                    var colorIndex = 0
                    
                    if bitA == 0 && bitB == 0 {
                        colorIndex = 0
                    } else if bitA == 1 && bitB == 1 {
                        colorIndex = 1
                    } else {
                        let isEvenColumn = (pixelIndex % 2) == 0
                        
                        if highBit == 1 {
                            if isEvenColumn {
                                colorIndex = (bitA == 1) ? 5 : 4
                            } else {
                                colorIndex = (bitA == 1) ? 4 : 5
                            }
                        } else {
                            if isEvenColumn {
                                colorIndex = (bitA == 1) ? 3 : 2
                            } else {
                                colorIndex = (bitA == 1) ? 2 : 3
                            }
                        }
                    }
                    
                    let c = hgrColors[colorIndex]
                    rgbaBuffer[bufferIdx] = c.r
                    rgbaBuffer[bufferIdx + 1] = c.g
                    rgbaBuffer[bufferIdx + 2] = c.b
                    rgbaBuffer[bufferIdx + 3] = 255
                }
            }
        }
        
        return createCGImage(from: rgbaBuffer, width: width, height: height)
    }
    
    // --- SHR Decoder ---
    static func decodeSHR(data: Data, is3200Color: Bool) -> CGImage? {
        let width = 320
        let height = 200
        var rgbaBuffer = [UInt8](repeating: 255, count: width * height * 4)
        
        let pixelDataStart = 0
        let scbOffset = 32000
        let standardPaletteOffset = 32256
        let brooksPaletteOffset = 32000
        
        if !is3200Color {
            var palettes = [[(r: UInt8, g: UInt8, b: UInt8)]]()
            for i in 0..<16 {
                let pOffset = standardPaletteOffset + (i * 32)
                palettes.append(readPalette(from: data, offset: pOffset, reverseOrder: false))
            }
            
            for y in 0..<height {
                let scb = data[scbOffset + y]
                let paletteIndex = Int(scb & 0x0F)
                let currentPalette = palettes[paletteIndex]
                renderLine(y: y, data: data, pixelStart: pixelDataStart, palette: currentPalette, to: &rgbaBuffer, width: width)
            }
            
        } else {
            for y in 0..<height {
                let pOffset = brooksPaletteOffset + (y * 32)
                let currentPalette = readPalette(from: data, offset: pOffset, reverseOrder: true)
                renderLine(y: y, data: data, pixelStart: pixelDataStart, palette: currentPalette, to: &rgbaBuffer, width: width)
            }
        }
        
        return createCGImage(from: rgbaBuffer, width: width, height: height)
    }
    
    // Upscale CGImage using nearest neighbor (pixel-perfect retro look)
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
    
    // --- Decoder Helpers ---
    
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
    
    static func renderLine(y: Int, data: Data, pixelStart: Int, palette: [(r: UInt8, g: UInt8, b: UInt8)], to buffer: inout [UInt8], width: Int) {
        let bytesPerLine = 160
        let lineStart = pixelStart + (y * bytesPerLine)
        
        for xByte in 0..<bytesPerLine {
            let byte = data[lineStart + xByte]
            
            let idx1 = (byte & 0xF0) >> 4
            let idx2 = (byte & 0x0F)
            
            let c1 = palette[Int(idx1)]
            let bufferIdx1 = (y * width + (xByte * 2)) * 4
            buffer[bufferIdx1]     = c1.r
            buffer[bufferIdx1 + 1] = c1.g
            buffer[bufferIdx1 + 2] = c1.b
            buffer[bufferIdx1 + 3] = 255
            
            let c2 = palette[Int(idx2)]
            let bufferIdx2 = (y * width + (xByte * 2) + 1) * 4
            buffer[bufferIdx2]     = c2.r
            buffer[bufferIdx2 + 1] = c2.g
            buffer[bufferIdx2 + 2] = c2.b
            buffer[bufferIdx2 + 3] = 255
        }
    }
    
    static func createCGImage(from buffer: [UInt8], width: Int, height: Int) -> CGImage? {
        let bytesPerPixel = 4
        let bitsPerComponent = 8
        let bytesPerRow = width * bytesPerPixel
        let expectedSize = bytesPerRow * height
        
        guard buffer.count == expectedSize else {
            return nil
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        // Use .noneSkipLast to ignore the alpha channel for opaque images
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
    
}
// MARK: - Disk Catalog Browser View

// ===============================================
// 1. DiskCatalogBrowserView (Top-Level View)
//    - Defines the @State for selection.
//    - Defines the global selection/toggle functions.
//    - Calls CatalogEntryRow using these functions.
// ===============================================

struct DiskCatalogBrowserView: View {
    let catalog: DiskCatalog
    let onImport: ([DiskCatalogEntry]) -> Void
    let onCancel: () -> Void
    
    @State private var selectedEntries: Set<UUID> = []
    @State private var searchText: String = ""
    @State private var showImagesOnly: Bool = false
    @State private var expandAllTrigger: Bool = true
    
    var filteredEntries: [DiskCatalogEntry] {
        var entries = showImagesOnly || !searchText.isEmpty
             ? catalog.allEntries
             : catalog.entries
        
        if !searchText.isEmpty {
            entries = entries.filter { entry in
                entry.name.localizedCaseInsensitiveContains(searchText) ||
                entry.typeDescription.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        if showImagesOnly {
            entries = entries.filter { $0.isImage }
        }
        
        return entries
    }
    
    var selectedCount: Int {
        selectedEntries.count
    }
    
    var selectedImagesCount: Int {
        catalog.allEntries.filter { selectedEntries.contains($0.id) && $0.isImage }.count
    }

    // Function to handle toggling selection for ANY entry (top-level or child)
    func toggleSelection(_ entry: DiskCatalogEntry) {
        if selectedEntries.contains(entry.id) {
            selectedEntries.remove(entry.id)
        } else {
            selectedEntries.insert(entry.id)
        }
    }

    // Function to check selection status for ANY entry (passed as `isSelected` closure)
    func isSelected(entry: DiskCatalogEntry) -> Bool {
        selectedEntries.contains(entry.id)
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header (unchanged)
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("💾 \(catalog.diskName)")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("(\(catalog.diskFormat))")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    HStack(spacing: 16) {
                        Label("\(catalog.totalFiles) files", systemImage: "doc.text")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Label("\(catalog.imageFiles) images", systemImage: "photo")
                            .font(.caption)
                            .foregroundColor(.blue)
                        
                        Text(ByteCountFormatter.string(fromByteCount: Int64(catalog.diskSize), countStyle: .file))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                Button(action: onCancel) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
            
            Divider()
            
            // Toolbar (unchanged)
            HStack(spacing: 12) {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search files...", text: $searchText)
                        .textFieldStyle(.plain)
                    
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundColor(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(6)
                .background(Color(NSColor.textBackgroundColor))
                .cornerRadius(6)
                .frame(width: 250)
                
                Toggle(isOn: $showImagesOnly) {
                    HStack(spacing: 4) {
                        Image(systemName: "photo")
                        Text("Images Only")
                    }
                }
                .toggleStyle(.checkbox)
                
                Spacer()
                
                Button("Select All Images") {
                    let imageEntries = catalog.allEntries.filter { $0.isImage }
                    print("🔵 Total entries: \(catalog.allEntries.count)")
                    print("🔵 Image entries: \(imageEntries.count)")
                    print("🔵 Images found: \(imageEntries.map { $0.name })")
                    selectedEntries = Set(imageEntries.map { $0.id })
                }
                
                Button("Clear Selection") {
                    selectedEntries.removeAll()
                }
                Button("Expand All") {
                    expandAllTrigger = true
                }

                Button("Collapse All") {
                    expandAllTrigger = false
                }

            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.5))
            
            Divider()
            
            // Table
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(filteredEntries) { entry in
                        CatalogEntryRow(
                            entry: entry,
                            isSelected: self.isSelected,
                            onToggle: self.toggleSelection,
                            level: 0,
                            expandAllTrigger: expandAllTrigger  // NEU!
                        )
                    }
                }
            }

            
            Divider()
            
            // Footer (unchanged)
            HStack {
                HStack(spacing: 16) {
                    Text("\(selectedCount) selected")
                        .foregroundColor(.secondary)
                    
                    if selectedImagesCount > 0 {
                        Text("(\(selectedImagesCount) images)")
                            .foregroundColor(.blue)
                            .fontWeight(.medium)
                    }
                }
                
                Spacer()
                
                Button("Cancel") {
                    onCancel()
                }
                .keyboardShortcut(.cancelAction)
                
                Button("Export Files") {
                    exportSelectedFiles()
                }
                .disabled(selectedCount == 0)
                
                Button("Import Selected") {
                    let entriesToImport = catalog.allEntries.filter { selectedEntries.contains($0.id) }
                    onImport(entriesToImport)
                }
                .keyboardShortcut(.defaultAction)
                .disabled(selectedCount == 0)
            }
            .padding()
            .background(Color(NSColor.controlBackgroundColor))
        }
        .frame(width: 900, height: 600)
        .onAppear {
            selectedEntries = []  // Keine Vorauswahl
        }
    }
    
    // exportSelectedFiles function (unchanged)
    func exportSelectedFiles() {
        let entriesToExport = catalog.allEntries.filter { selectedEntries.contains($0.id) }
        
        guard !entriesToExport.isEmpty else { return }
        
        let downloadsURL = FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first!
        
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd_HHmmss"
        let timestamp = dateFormatter.string(from: Date())
        let exportFolder = downloadsURL.appendingPathComponent("\(catalog.diskName)_export_\(timestamp)")
        
        do {
            try FileManager.default.createDirectory(at: exportFolder, withIntermediateDirectories: true)
            
            var exportedCount = 0
            
            for entry in entriesToExport {
                guard !entry.isDirectory else { continue }
                
                var filename = entry.name
                
                if !filename.contains(".") {
                    switch entry.fileType {
                    case 0x00, 0x01: filename += ".txt"
                    case 0x02: filename += ".bas"
                    case 0x04, 0x06: filename += ".bin"
                    case 0xFA, 0xFC: filename += ".bas"
                    default: filename += ".dat"
                    }
                }
                
                let fileURL = exportFolder.appendingPathComponent(filename)
                try entry.data.write(to: fileURL)
                exportedCount += 1
            }
            
            
            NSWorkspace.shared.activateFileViewerSelecting([exportFolder])
            
        } catch {
            
        }
    }
}


// ===============================================
// 2. CatalogEntryRow (Main Row View)
//    - Updated signatures and usage of isSelected/onToggle closures.
//    - Recursively calls CatalogEntryRowRecursive.
// ===============================================

struct CatalogEntryRow: View {
    let entry: DiskCatalogEntry
    let isSelected: (DiskCatalogEntry) -> Bool
    let onToggle: (DiskCatalogEntry) -> Void
    let level: Int
    let expandAllTrigger: Bool  // NEU!
    
    @State private var isExpanded: Bool = true

    
    var body: some View {
        VStack(spacing: 0) {
            // Haupt-Row
            HStack(spacing: 8) {
                // Einrückung für Hierarchie (unchanged)
                if level > 0 {
                    ForEach(0..<level, id: \.self) { _ in
                        Text("  ")
                    }
                    Text("└─")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                   

                
                // Checkbox
                Button(action: {
                    onToggle(entry)
                }) {
                    Image(systemName: isSelected(entry) ? "checkmark.square.fill" : "square")
                        .foregroundColor(isSelected(entry) ? .blue : .secondary)
                }
                .buttonStyle(.plain)
                .frame(width: 30)
                
                // Expand/Collapse für Ordner (unchanged)
                if entry.isDirectory && entry.children != nil && !entry.children!.isEmpty {
                    Button(action: { isExpanded.toggle() }) {
                        Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                
                Text(entry.icon)
                    .font(.title3)
                
                Text(entry.name)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fontWeight(entry.isDirectory ? .semibold : .regular)
                
                // Rest bleibt gleich... (unchanged)
                Text(entry.typeDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(width: 120, alignment: .leading)
                
                Text(entry.sizeString)
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundColor(.secondary)
                    .frame(width: 80, alignment: .trailing)
                
                if let loadAddr = entry.loadAddress {
                    Text(String(format: "$%04X", loadAddr))
                        .font(.caption)
                        .monospacedDigit()
                        .foregroundColor(.secondary)
                        .frame(width: 80, alignment: .trailing)
                } else {
                    Text("-")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(width: 80, alignment: .trailing)
                }
            }
            .padding(.vertical, 4)
            .padding(.horizontal, 8)
            .background(isSelected(entry) ? Color.blue.opacity(0.1) : Color.clear)
            .contentShape(Rectangle())
            .onTapGesture(perform: { onToggle(entry) })
            
            // Kinder anzeigen wenn expanded
                if entry.isDirectory && isExpanded, let children = entry.children {
                               ForEach(children) { child in
                                   CatalogEntryRowRecursive(
                                       entry: child,
                                       isSelected: isSelected,
                                       onToggle: onToggle,
                                       level: level + 1,
                                       expandAllTrigger: expandAllTrigger  // NEU!
                                   )
                               }
                           }
                       }
                       .onChange(of: expandAllTrigger) { newValue in  // NEU!
                           isExpanded = newValue
                       }
                   }
               }


// ===============================================
// 3. CatalogEntryRowRecursive (Wrapper for Recursion)
//    - Updated signatures to match CatalogEntryRow.
// ===============================================

// Rekursive Version
    struct CatalogEntryRowRecursive: View {
        let entry: DiskCatalogEntry
        let isSelected: (DiskCatalogEntry) -> Bool
        let onToggle: (DiskCatalogEntry) -> Void
        let level: Int
        let expandAllTrigger: Bool  // NEU!
        
        var body: some View {
            CatalogEntryRow(
                entry: entry,
                isSelected: isSelected,
                onToggle: onToggle,
                level: level,
                expandAllTrigger: expandAllTrigger  // NEU!
            )
        }
    }

    

