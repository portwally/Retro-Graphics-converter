import Foundation
import AppKit

/// Reader for MSX disk images (.dsk files with FAT12 filesystem)
/// Supports 360KB (SS/DD) and 720KB (DS/DD) disk images
class MSXDiskReader {

    // MARK: - Types

    struct DiskGeometry {
        let bytesPerSector: Int
        let sectorsPerCluster: Int
        let reservedSectors: Int
        let numberOfFATs: Int
        let rootEntries: Int
        let totalSectors: Int
        let mediaDescriptor: UInt8
        let sectorsPerFAT: Int
        let sectorsPerTrack: Int
        let numberOfHeads: Int
        let hiddenSectors: Int
    }

    struct DirectoryEntry {
        let name: String
        let extension_: String
        let attributes: UInt8
        let reserved: Data
        let time: UInt16
        let date: UInt16
        let firstCluster: UInt16
        let fileSize: UInt32

        var isDirectory: Bool { (attributes & 0x10) != 0 }
        var isVolumeLabel: Bool { (attributes & 0x08) != 0 }
        var isHidden: Bool { (attributes & 0x02) != 0 }
        var isSystem: Bool { (attributes & 0x04) != 0 }
        var isReadOnly: Bool { (attributes & 0x01) != 0 }
        var isLongFileName: Bool { attributes == 0x0F }

        var isValid: Bool {
            guard !name.isEmpty else { return false }
            guard name.first != "\u{E5}" else { return false }  // Deleted entry
            guard name.first != "\0" else { return false }      // Empty entry
            guard !isVolumeLabel else { return false }
            guard !isLongFileName else { return false }
            return true
        }

        var fullName: String {
            let trimmedName = name.trimmingCharacters(in: .whitespaces)
            let trimmedExt = extension_.trimmingCharacters(in: .whitespaces)
            if trimmedExt.isEmpty {
                return trimmedName
            }
            return "\(trimmedName).\(trimmedExt)"
        }
    }

    // MARK: - Detection

    /// Check if data appears to be an MSX disk image
    func canRead(data: Data) -> Bool {
        // MSX disks are typically 360KB or 720KB
        let validSizes = [
            360 * 1024,     // 360KB SS/DD
            720 * 1024,     // 720KB DS/DD
        ]

        guard validSizes.contains(data.count) else { return false }

        // Must have at least a boot sector
        guard data.count >= 512 else { return false }

        // Check for valid FAT12 BPB structure
        guard let geometry = parseBootSector(data: data) else { return false }

        // Validate geometry makes sense for MSX
        guard geometry.bytesPerSector == 512 else { return false }
        guard geometry.sectorsPerCluster >= 1 && geometry.sectorsPerCluster <= 8 else { return false }
        guard geometry.numberOfFATs >= 1 && geometry.numberOfFATs <= 2 else { return false }
        guard geometry.rootEntries > 0 && geometry.rootEntries <= 512 else { return false }

        // Check media descriptor - MSX typically uses F8, F9, FA, FB, FC, FD, FE, FF
        let validMediaDescriptors: [UInt8] = [0xF8, 0xF9, 0xFA, 0xFB, 0xFC, 0xFD, 0xFE, 0xFF]
        guard validMediaDescriptors.contains(geometry.mediaDescriptor) else { return false }

        // Try to read FAT and verify it starts with media descriptor
        let fatStart = geometry.reservedSectors * geometry.bytesPerSector
        guard fatStart + 3 <= data.count else { return false }

        let fat0 = data[fatStart]
        // First byte of FAT should match media descriptor
        guard fat0 == geometry.mediaDescriptor else { return false }

        // Next two bytes should be 0xFF 0xFF for FAT12
        guard data[fatStart + 1] == 0xFF && data[fatStart + 2] == 0xFF else { return false }

        return true
    }

    // MARK: - Reading

    /// Read all files from the MSX disk image
    func readDisk(data: Data) -> [DiskCatalogEntry]? {
        guard let geometry = parseBootSector(data: data) else { return nil }

        // Read FAT
        let fat = readFAT(data: data, geometry: geometry)
        guard !fat.isEmpty else { return nil }

        // Read root directory
        let rootDirStart = (geometry.reservedSectors + geometry.numberOfFATs * geometry.sectorsPerFAT) * geometry.bytesPerSector
        let rootDirSize = geometry.rootEntries * 32
        guard rootDirStart + rootDirSize <= data.count else { return nil }

        let entries = parseDirectory(data: data, offset: rootDirStart, count: geometry.rootEntries)

        // Build catalog entries
        var catalogEntries: [DiskCatalogEntry] = []

        for entry in entries {
            if entry.isDirectory && entry.name != "." && entry.name != ".." {
                // Read subdirectory
                let subEntries = readSubdirectory(data: data, entry: entry, geometry: geometry, fat: fat, path: entry.fullName)
                catalogEntries.append(contentsOf: subEntries)
            } else if !entry.isDirectory && entry.isValid {
                // Extract file
                if let fileData = extractFile(data: data, entry: entry, geometry: geometry, fat: fat) {
                    let fileTypeStr = detectFileType(name: entry.fullName, data: fileData)
                    let (isImage, imageType) = detectImageType(name: entry.fullName, data: fileData)
                    let catalogEntry = DiskCatalogEntry(
                        name: entry.fullName,
                        fileType: 0,
                        fileTypeString: fileTypeStr,
                        size: Int(entry.fileSize),
                        blocks: nil,
                        loadAddress: nil,
                        length: nil,
                        data: fileData,
                        isImage: isImage,
                        imageType: imageType,
                        isDirectory: false,
                        children: nil
                    )
                    catalogEntries.append(catalogEntry)
                }
            }
        }

        return catalogEntries
    }

    // MARK: - Boot Sector Parsing

    private func parseBootSector(data: Data) -> DiskGeometry? {
        guard data.count >= 512 else { return nil }

        let bytesPerSector = Int(UInt16(data[11]) | (UInt16(data[12]) << 8))
        let sectorsPerCluster = Int(data[13])
        let reservedSectors = Int(UInt16(data[14]) | (UInt16(data[15]) << 8))
        let numberOfFATs = Int(data[16])
        let rootEntries = Int(UInt16(data[17]) | (UInt16(data[18]) << 8))
        let totalSectors = Int(UInt16(data[19]) | (UInt16(data[20]) << 8))
        let mediaDescriptor = data[21]
        let sectorsPerFAT = Int(UInt16(data[22]) | (UInt16(data[23]) << 8))
        let sectorsPerTrack = Int(UInt16(data[24]) | (UInt16(data[25]) << 8))
        let numberOfHeads = Int(UInt16(data[26]) | (UInt16(data[27]) << 8))
        let hiddenSectors = Int(UInt16(data[28]) | (UInt16(data[29]) << 8))

        // Validate basic geometry
        guard bytesPerSector == 512 else { return nil }
        guard sectorsPerCluster > 0 else { return nil }
        guard numberOfFATs > 0 else { return nil }
        guard rootEntries > 0 else { return nil }
        guard totalSectors > 0 else { return nil }
        guard sectorsPerFAT > 0 else { return nil }

        return DiskGeometry(
            bytesPerSector: bytesPerSector,
            sectorsPerCluster: sectorsPerCluster,
            reservedSectors: reservedSectors,
            numberOfFATs: numberOfFATs,
            rootEntries: rootEntries,
            totalSectors: totalSectors,
            mediaDescriptor: mediaDescriptor,
            sectorsPerFAT: sectorsPerFAT,
            sectorsPerTrack: sectorsPerTrack,
            numberOfHeads: numberOfHeads,
            hiddenSectors: hiddenSectors
        )
    }

    // MARK: - FAT Reading

    private func readFAT(data: Data, geometry: DiskGeometry) -> [UInt16] {
        let fatStart = geometry.reservedSectors * geometry.bytesPerSector
        let fatSize = geometry.sectorsPerFAT * geometry.bytesPerSector
        guard fatStart + fatSize <= data.count else { return [] }

        // FAT12: each entry is 12 bits (1.5 bytes)
        var fat: [UInt16] = []
        let numEntries = (fatSize * 8) / 12

        for i in 0..<numEntries {
            let byteOffset = fatStart + (i * 3) / 2
            guard byteOffset + 1 < data.count else { break }

            var value: UInt16
            if i % 2 == 0 {
                // Even entry: low 8 bits from byte[n], high 4 bits from low nibble of byte[n+1]
                value = UInt16(data[byteOffset]) | ((UInt16(data[byteOffset + 1]) & 0x0F) << 8)
            } else {
                // Odd entry: low 4 bits from high nibble of byte[n], high 8 bits from byte[n+1]
                value = (UInt16(data[byteOffset]) >> 4) | (UInt16(data[byteOffset + 1]) << 4)
            }
            fat.append(value)
        }

        return fat
    }

    // MARK: - Directory Parsing

    private func parseDirectory(data: Data, offset: Int, count: Int) -> [DirectoryEntry] {
        var entries: [DirectoryEntry] = []

        for i in 0..<count {
            let entryOffset = offset + i * 32
            guard entryOffset + 32 <= data.count else { break }

            let firstByte = data[entryOffset]
            if firstByte == 0x00 { break }  // End of directory
            if firstByte == 0xE5 { continue }  // Deleted entry

            // Parse 8.3 filename
            var nameBytes = [UInt8](data[entryOffset..<entryOffset + 8])
            var extBytes = [UInt8](data[entryOffset + 8..<entryOffset + 11])

            // Convert to string, handling special characters
            let name = String(bytes: nameBytes, encoding: .ascii)?.trimmingCharacters(in: .whitespaces) ?? ""
            let ext = String(bytes: extBytes, encoding: .ascii)?.trimmingCharacters(in: .whitespaces) ?? ""

            let attributes = data[entryOffset + 11]
            let reserved = data[entryOffset + 12..<entryOffset + 22]
            let time = UInt16(data[entryOffset + 22]) | (UInt16(data[entryOffset + 23]) << 8)
            let date = UInt16(data[entryOffset + 24]) | (UInt16(data[entryOffset + 25]) << 8)
            let firstCluster = UInt16(data[entryOffset + 26]) | (UInt16(data[entryOffset + 27]) << 8)
            let fileSize = UInt32(data[entryOffset + 28]) | (UInt32(data[entryOffset + 29]) << 8) |
                          (UInt32(data[entryOffset + 30]) << 16) | (UInt32(data[entryOffset + 31]) << 24)

            let entry = DirectoryEntry(
                name: name,
                extension_: ext,
                attributes: attributes,
                reserved: Data(reserved),
                time: time,
                date: date,
                firstCluster: firstCluster,
                fileSize: fileSize
            )

            entries.append(entry)
        }

        return entries
    }

    // MARK: - Subdirectory Reading

    private func readSubdirectory(data: Data, entry: DirectoryEntry, geometry: DiskGeometry, fat: [UInt16], path: String) -> [DiskCatalogEntry] {
        guard entry.isDirectory else { return [] }

        // Get cluster chain for directory
        let clusters = getClusterChain(startCluster: entry.firstCluster, fat: fat)
        guard !clusters.isEmpty else { return [] }

        // Calculate data area start
        let rootDirStart = (geometry.reservedSectors + geometry.numberOfFATs * geometry.sectorsPerFAT) * geometry.bytesPerSector
        let rootDirSize = geometry.rootEntries * 32
        let dataAreaStart = rootDirStart + rootDirSize

        // Read directory data
        var dirData = Data()
        let clusterSize = geometry.sectorsPerCluster * geometry.bytesPerSector

        for cluster in clusters {
            let clusterOffset = dataAreaStart + (Int(cluster) - 2) * clusterSize
            guard clusterOffset >= 0 && clusterOffset + clusterSize <= data.count else { continue }
            dirData.append(data[clusterOffset..<clusterOffset + clusterSize])
        }

        // Parse directory entries
        let subEntries = parseDirectory(data: dirData, offset: 0, count: dirData.count / 32)

        var catalogEntries: [DiskCatalogEntry] = []

        for subEntry in subEntries {
            if subEntry.name == "." || subEntry.name == ".." {
                continue
            }

            let fullPath = "\(path)/\(subEntry.fullName)"

            if subEntry.isDirectory {
                let nested = readSubdirectory(data: data, entry: subEntry, geometry: geometry, fat: fat, path: fullPath)
                catalogEntries.append(contentsOf: nested)
            } else if let fileData = extractFile(data: data, entry: subEntry, geometry: geometry, fat: fat) {
                let fileTypeStr = detectFileType(name: subEntry.fullName, data: fileData)
                let (isImage, imageType) = detectImageType(name: subEntry.fullName, data: fileData)
                let catalogEntry = DiskCatalogEntry(
                    name: fullPath,
                    fileType: 0,
                    fileTypeString: fileTypeStr,
                    size: Int(subEntry.fileSize),
                    blocks: nil,
                    loadAddress: nil,
                    length: nil,
                    data: fileData,
                    isImage: isImage,
                    imageType: imageType,
                    isDirectory: false,
                    children: nil
                )
                catalogEntries.append(catalogEntry)
            }
        }

        return catalogEntries
    }

    // MARK: - File Extraction

    private func extractFile(data: Data, entry: DirectoryEntry, geometry: DiskGeometry, fat: [UInt16]) -> Data? {
        guard entry.fileSize > 0 else { return Data() }

        let clusters = getClusterChain(startCluster: entry.firstCluster, fat: fat)
        guard !clusters.isEmpty else { return nil }

        // Calculate data area start
        let rootDirStart = (geometry.reservedSectors + geometry.numberOfFATs * geometry.sectorsPerFAT) * geometry.bytesPerSector
        let rootDirSize = geometry.rootEntries * 32
        let dataAreaStart = rootDirStart + rootDirSize

        var fileData = Data()
        let clusterSize = geometry.sectorsPerCluster * geometry.bytesPerSector

        for cluster in clusters {
            let clusterOffset = dataAreaStart + (Int(cluster) - 2) * clusterSize
            guard clusterOffset >= 0 && clusterOffset + clusterSize <= data.count else { continue }

            let bytesToRead = min(clusterSize, Int(entry.fileSize) - fileData.count)
            if bytesToRead > 0 {
                fileData.append(data[clusterOffset..<clusterOffset + bytesToRead])
            }

            if fileData.count >= entry.fileSize {
                break
            }
        }

        // Trim to exact file size
        if fileData.count > entry.fileSize {
            fileData = fileData.prefix(Int(entry.fileSize))
        }

        return fileData
    }

    // MARK: - Cluster Chain

    private func getClusterChain(startCluster: UInt16, fat: [UInt16]) -> [UInt16] {
        var clusters: [UInt16] = []
        var current = startCluster

        // Sanity check - prevent infinite loops
        let maxClusters = fat.count

        while current >= 2 && current < 0xFF8 && clusters.count < maxClusters {
            clusters.append(current)

            guard Int(current) < fat.count else { break }
            current = fat[Int(current)]
        }

        return clusters
    }

    // MARK: - File Type Detection

    private func detectFileType(name: String, data: Data) -> String {
        let ext = (name as NSString).pathExtension.uppercased()

        // Check by extension first
        switch ext {
        // MSX graphics formats
        case "SC2", "GRP":
            return "MSX Screen 2"
        case "SC5":
            return "MSX Screen 5"
        case "SC7":
            return "MSX Screen 7"
        case "SC8":
            return "MSX Screen 8"
        case "SCC":
            return "MSX Screen C"
        case "SR5":
            return "MSX Screen 5 (SR)"
        case "SR7":
            return "MSX Screen 7 (SR)"
        case "SR8":
            return "MSX Screen 8 (SR)"
        case "PIC":
            return "MSX Picture"
        case "GL":
            return "MSX GL"
        case "GE5", "GE7", "GE8":
            return "MSX Graph Saurus"
        // Other formats
        case "BAS":
            return "BASIC Program"
        case "BIN":
            return "Binary"
        case "COM":
            return "Executable"
        case "DAT":
            return "Data"
        case "TXT":
            return "Text"
        default:
            break
        }

        // Check by file content for BSAVE format
        if data.count >= 7 && data[0] == 0xFE {
            // BSAVE header: 0xFE, start address (2 bytes), end address (2 bytes), exec address (2 bytes)
            return "MSX BSAVE"
        }

        return ext.isEmpty ? "Unknown" : ext
    }

    // MARK: - Image Type Detection

    private func detectImageType(name: String, data: Data) -> (isImage: Bool, imageType: AppleIIImageType) {
        let ext = (name as NSString).pathExtension.uppercased()

        // Check for MSX graphics by extension
        switch ext {
        case "SC2", "GRP":
            // Screen 2: 256x192, 16 colors (pattern-based)
            if data.count >= 7 && data[0] == 0xFE {
                // BSAVE format
                return (true, .MSX(mode: 2, colors: 16))
            }
            if data.count >= 16384 {
                return (true, .MSX(mode: 2, colors: 16))
            }

        case "SC5":
            // Screen 5: 256x212, 16 colors
            if data.count >= 7 && data[0] == 0xFE {
                return (true, .MSX(mode: 5, colors: 16))
            }
            if data.count >= 27000 {
                return (true, .MSX(mode: 5, colors: 16))
            }

        case "SC7":
            // Screen 7: 512x212, 16 colors
            if data.count >= 7 && data[0] == 0xFE {
                return (true, .MSX(mode: 7, colors: 16))
            }
            if data.count >= 54000 {
                return (true, .MSX(mode: 7, colors: 16))
            }

        case "SC8":
            // Screen 8: 256x212, 256 colors
            if data.count >= 7 && data[0] == 0xFE {
                return (true, .MSX(mode: 8, colors: 256))
            }
            if data.count >= 54000 {
                return (true, .MSX(mode: 8, colors: 256))
            }

        case "SR5", "GE5":
            return (true, .MSX(mode: 5, colors: 16))

        case "SR7", "GE7":
            return (true, .MSX(mode: 7, colors: 16))

        case "SR8", "GE8":
            return (true, .MSX(mode: 8, colors: 256))

        default:
            break
        }

        // Check by content - BSAVE format with graphics-like sizes
        if data.count >= 7 && data[0] == 0xFE {
            let startAddr = Int(UInt16(data[1]) | (UInt16(data[2]) << 8))
            let endAddr = Int(UInt16(data[3]) | (UInt16(data[4]) << 8))
            let dataSize = endAddr - startAddr + 1

            // Screen 2: ~16KB of pattern/color data
            if dataSize >= 14000 && dataSize <= 17000 && startAddr == 0x0000 {
                return (true, .MSX(mode: 2, colors: 16))
            }

            // Screen 5/8: typically loaded to VRAM
            if dataSize >= 27000 && dataSize <= 28000 {
                return (true, .MSX(mode: 5, colors: 16))
            }

            if dataSize >= 54000 && dataSize <= 55000 {
                return (true, .MSX(mode: 8, colors: 256))
            }
        }

        return (false, .Unknown)
    }
}
