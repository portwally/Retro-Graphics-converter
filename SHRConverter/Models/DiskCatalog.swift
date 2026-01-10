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
    let id = UUID()
    let url: URL
    let image: NSImage
    let type: AppleIIImageType
    
    var filename: String {
        url.lastPathComponent
    }
}
