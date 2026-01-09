import Foundation

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
