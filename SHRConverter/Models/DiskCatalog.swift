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

extension DiskCatalogEntry {
    var fileTypeInfo: ProDOSFileTypeInfo {
        return ProDOSFileTypeInfo.getFileTypeInfo(fileType: fileType, auxType: loadAddress)
    }
    
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

// MARK: - Disk Image File

struct DiskImageFile {
    let name: String
    let data: Data
    let type: AppleIIImageType
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

    // Initializer mit optionaler ID - wenn keine ID übergeben wird, wird eine neue erstellt
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
        // Versuche die Original-Dateierweiterung zu ermitteln
        let ext = url.pathExtension.lowercased()
        if !ext.isEmpty {
            return ext
        }
        
        // Fallback basierend auf Bildtyp
        switch type {
        case .SHR: return "shr"
        case .HGR: return "hgr"
        case .DHGR: return "dhgr"
        case .IFF: return "iff"
        case .DEGAS: return "pi1"
        case .C64: return "c64"
        case .ZXSpectrum: return "scr"
        case .AmstradCPC: return "cpc"
        case .PCX: return "pcx"
        case .BMP: return "bmp"
        case .MacPaint: return "mac"
        case .MSX(let mode, _): return "sc\(mode)"
        case .BBCMicro(let mode, _): return "bbm\(mode)"
        case .TRS80: return "bin"
        case .ModernImage(let format, _, _):
            return format.lowercased()
        case .Unknown: return "bin"
        }
    }
}
