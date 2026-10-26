import Foundation
import AppKit

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
    /// Which file system `fileType` belongs to. The numbers mean different things on each:
    /// $04 is a text file on ProDOS but a binary on DOS 3.3, and 2 is PRG on a Commodore disk.
    var fileSystem: CatalogFileSystem = .other

    var sizeString: String {
        if size < 1024 {
            return "\(size) B"
        } else if size < 1024 * 1024 {
            return String(format: "%.1f KB", Double(size) / 1024.0)
        } else {
            return String(format: "%.1f MB", Double(size) / (1024.0 * 1024.0))
        }
    }

    /// Filename with ProDOS type info suffix (e.g., "FILENAME#c00001")
    /// This is used by the decoder to identify file formats like PNT ($C0) with auxtype
    var nameWithTypeInfo: String {
        let auxType = loadAddress ?? 0
        return String(format: "%@#%02x%04x", name, fileType, auxType)
    }
}

enum CatalogFileSystem {
    case prodos   // fileType / loadAddress are a ProDOS file type and aux type
    case dos33    // fileTypeString holds the DOS 3.3 type byte as "$xx"
    case other    // fileTypeString is already a readable type (PRG, Degas, GR.8 ...)
}

extension DiskCatalogEntry {
    var fileTypeInfo: ProDOSFileTypeInfo {
        return ProDOSFileTypeInfo.getFileTypeInfo(fileType: fileType, auxType: loadAddress)
    }

    /// DOS 3.3 type byte (lock bit removed), parsed back from fileTypeString
    private var dos33Type: UInt8? {
        guard fileSystem == .dos33, fileTypeString.hasPrefix("$") else { return nil }
        return UInt8(fileTypeString.dropFirst(), radix: 16)
    }

    private var dos33TypeName: String {
        switch dos33Type {
        case 0x00: return "TXT"
        case 0x01: return "INT"   // Integer BASIC
        case 0x02: return "BAS"   // Applesoft BASIC
        case 0x04: return "BIN"
        case 0x08: return "S"
        case 0x10: return "REL"
        case 0x20: return "A"
        case 0x40: return "B"
        default: return fileTypeString
        }
    }

    var icon: String {
        if isDirectory { return "📁" }
        switch fileSystem {
        case .prodos:
            return fileTypeInfo.icon
        case .dos33, .other:
            return isImage ? "🖼️" : "📄"
        }
    }

    var typeDescription: String {
        if isDirectory { return "Folder" }
        switch fileSystem {
        case .prodos:
            return fileTypeInfo.shortName
        case .dos33:
            return isImage ? "\(dos33TypeName) (image)" : dos33TypeName
        case .other:
            return fileTypeString
        }
    }

    /// Extension to add when exporting a file whose name has none
    var defaultExportExtension: String {
        switch fileSystem {
        case .prodos:
            switch fileType {
            case 0x04: return "txt"
            case 0x06: return "bin"
            case 0xFA, 0xFC: return "bas"
            case 0xFF: return "sys"
            default: return "dat"
            }
        case .dos33:
            switch dos33Type {
            case 0x00: return "txt"
            case 0x01, 0x02: return "bas"
            case 0x04: return "bin"
            default: return "dat"
            }
        case .other:
            // Short readable types double as extensions (PRG, SEQ, BAS ...)
            let type = fileTypeString.lowercased()
            let isPlainType = (1...4).contains(type.count) && type.allSatisfy { $0.isLetter || $0.isNumber }
            return isPlainType ? type : "dat"
        }
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

// MARK: - Image Item Model

struct ImageItem: Identifiable {
    let id: UUID
    let url: URL
    var image: NSImage
    let type: AppleIIImageType
    let originalData: Data?
    var paletteInfo: PaletteInfo?
    var modifiedPalette: PaletteInfo?
    var hasImageModification: Bool  // Track transforms (rotate, flip, crop, adjustments)
    /// Name the decoder was given when this differs from the URL (ProDOS type-tagged names from disk catalogs)
    var decodeFilename: String? = nil
    /// Image and palette as they were before the first palette edit; lets edits be re-applied from
    /// a clean copy for platforms that are recolored rather than re-decoded. Not kept across transforms.
    var paletteEditBase: (image: NSImage, palette: PaletteInfo)? = nil

    // Initializer with optional ID - if no ID is provided, a new one is created
    init(id: UUID = UUID(), url: URL, image: NSImage, type: AppleIIImageType, originalData: Data?, paletteInfo: PaletteInfo? = nil, hasImageModification: Bool = false) {
        self.id = id
        self.url = url
        self.image = image
        self.type = type
        self.originalData = originalData
        self.paletteInfo = paletteInfo
        self.modifiedPalette = nil
        self.hasImageModification = hasImageModification
    }

    var filename: String {
        url.lastPathComponent
    }

    /// Returns the active palette (modified if available, otherwise original)
    var activePalette: PaletteInfo? {
        modifiedPalette ?? paletteInfo
    }

    /// Whether the palette has been modified
    var hasPaletteModification: Bool {
        modifiedPalette != nil
    }

    /// Whether the image has any modification (palette or transform)
    var hasAnyModification: Bool {
        hasPaletteModification || hasImageModification
    }
    
    var originalFileExtension: String {
        // Try to determine the original file extension
        let ext = url.pathExtension.lowercased()
        if !ext.isEmpty {
            return ext
        }
        
        // Fallback based on image type
        switch type {
        case .SHR(_, _, _): return "shr"
        case .HGR: return "hgr"
        case .DHGR: return "dhgr"
        case .IFF(_, _, _): return "iff"
        case .DEGAS(_, _): return "pi1"
        case .NEOchrome(_): return "neo"
        case .ArtDirector: return "art"
        case .C64(_): return "c64"
        case .Plus4(let mode, _): return mode == "Multicolor" ? "ocp" : "art"
        case .VIC20(_, _): return "prg"
        case .ZXSpectrum: return "scr"
        case .AmstradCPC(_, _): return "cpc"
        case .PCX(_, _, _): return "pcx"
        case .BMP(_, _, _): return "bmp"
        case .MacPaint: return "mac"
        case .MSX(let mode, _): return "sc\(mode)"
        case .BBCMicro(let mode, _): return "bbm\(mode)"
        case .TRS80(_, _): return "bin"
        case .Atari8bit(let mode, _): return mode.lowercased().replacingOccurrences(of: ".", with: "")
        case .ModernImage(let format, _, _):
            return format.lowercased()
        case .Unknown: return "bin"
        }
    }
}
