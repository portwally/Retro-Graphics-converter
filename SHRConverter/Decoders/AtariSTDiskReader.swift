import Foundation

// MARK: - Atari ST Disk Image Reader
// Supports .st disk images (raw sector dumps) with FAT12 filesystem
// Common sizes: 360KB (SS/DD), 720KB (DS/DD), 1.44MB (DS/HD)

class AtariSTDiskReader {

    // MARK: - Constants

    private let sectorSize = 512

    // MARK: - Disk Geometry

    struct DiskGeometry {
        let totalSectors: Int
        let sectorsPerTrack: Int
        let sides: Int
        let tracks: Int
        let bytesPerSector: Int
        let sectorsPerCluster: Int
        let reservedSectors: Int
        let numberOfFATs: Int
        let rootEntries: Int
        let sectorsPerFAT: Int

        var rootDirSectors: Int {
            (rootEntries * 32 + bytesPerSector - 1) / bytesPerSector
        }

        var firstDataSector: Int {
            reservedSectors + (numberOfFATs * sectorsPerFAT) + rootDirSectors
        }

        var dataSectors: Int {
            totalSectors - firstDataSector
        }

        var totalClusters: Int {
            dataSectors / sectorsPerCluster
        }
    }

    // MARK: - Directory Entry

    struct DirectoryEntry {
        let name: String
        let extension_: String
        let attributes: UInt8
        let firstCluster: UInt16
        let fileSize: UInt32
        let isDirectory: Bool
        let isHidden: Bool
        let isSystem: Bool
        let isVolumeLabel: Bool

        var fullName: String {
            if extension_.isEmpty || extension_.trimmingCharacters(in: .whitespaces).isEmpty {
                return name.trimmingCharacters(in: .whitespaces)
            }
            return "\(name.trimmingCharacters(in: .whitespaces)).\(extension_.trimmingCharacters(in: .whitespaces))"
        }

        var isValid: Bool {
            !name.isEmpty && name.first != "\0" && !isVolumeLabel && name.first != Character(UnicodeScalar(0xE5))
        }
    }

    // MARK: - Public Interface

    func canRead(data: Data) -> Bool {
        // Check for valid Atari ST disk image sizes
        let validSizes = [
            360 * 1024,   // 360KB SS/DD
            400 * 1024,   // 400KB (10 sectors/track)
            720 * 1024,   // 720KB DS/DD
            800 * 1024,   // 800KB (10 sectors/track)
            1440 * 1024,  // 1.44MB DS/HD
        ]

        // Allow some tolerance for slight variations
        let isValidSize = validSizes.contains { abs(data.count - $0) < 1024 }

        if !isValidSize {
            return false
        }

        // Check boot sector for valid BPB
        guard data.count >= 512 else { return false }

        // Reject MSX disks - they have "MSX" at offset 3 in boot sector OEM name
        if data.count >= 6 {
            let oemName = String(data: data[3..<6], encoding: .ascii) ?? ""
            if oemName == "MSX" {
                return false
            }
        }

        // Check for valid bytes per sector (should be 512)
        let bytesPerSector = UInt16(data[11]) | (UInt16(data[12]) << 8)
        if bytesPerSector != 512 {
            return false
        }

        // Check sectors per cluster (should be 1 or 2)
        let sectorsPerCluster = data[13]
        if sectorsPerCluster == 0 || sectorsPerCluster > 4 {
            return false
        }

        return true
    }

    func readDisk(data: Data) -> [DiskCatalogEntry]? {
        guard let geometry = parseBootSector(data: data) else {
            print("AtariSTDiskReader: Failed to parse boot sector")
            return nil
        }

        // Read FAT
        guard let fat = readFAT(data: data, geometry: geometry) else {
            print("AtariSTDiskReader: Failed to read FAT")
            return nil
        }

        // Read root directory
        let rootDirOffset = (geometry.reservedSectors + geometry.numberOfFATs * geometry.sectorsPerFAT) * sectorSize
        let rootDirSize = geometry.rootEntries * 32

        guard rootDirOffset + rootDirSize <= data.count else {
            print("AtariSTDiskReader: Root directory out of bounds")
            return nil
        }

        let entries = parseDirectory(data: data, offset: rootDirOffset, maxEntries: geometry.rootEntries)

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
        var totalSectors = Int(UInt16(data[19]) | (UInt16(data[20]) << 8))
        let sectorsPerFAT = Int(UInt16(data[22]) | (UInt16(data[23]) << 8))
        let sectorsPerTrack = Int(UInt16(data[24]) | (UInt16(data[25]) << 8))
        let sides = Int(UInt16(data[26]) | (UInt16(data[27]) << 8))

        // If totalSectors is 0, use 32-bit value at offset 32
        if totalSectors == 0 {
            totalSectors = Int(UInt32(data[32]) | (UInt32(data[33]) << 8) |
                              (UInt32(data[34]) << 16) | (UInt32(data[35]) << 24))
        }

        // Validate parameters
        guard bytesPerSector == 512,
              sectorsPerCluster > 0 && sectorsPerCluster <= 4,
              numberOfFATs > 0 && numberOfFATs <= 2,
              rootEntries > 0,
              totalSectors > 0,
              sectorsPerFAT > 0 else {
            return nil
        }

        let tracks = totalSectors / (sectorsPerTrack * max(1, sides))

        return DiskGeometry(
            totalSectors: totalSectors,
            sectorsPerTrack: sectorsPerTrack,
            sides: sides,
            tracks: tracks,
            bytesPerSector: bytesPerSector,
            sectorsPerCluster: sectorsPerCluster,
            reservedSectors: reservedSectors,
            numberOfFATs: numberOfFATs,
            rootEntries: rootEntries,
            sectorsPerFAT: sectorsPerFAT
        )
    }

    // MARK: - FAT Reading

    private func readFAT(data: Data, geometry: DiskGeometry) -> [UInt16]? {
        let fatOffset = geometry.reservedSectors * sectorSize
        let fatSize = geometry.sectorsPerFAT * sectorSize

        guard fatOffset + fatSize <= data.count else { return nil }

        // FAT12: 12 bits per entry, packed
        var fat: [UInt16] = []
        let totalEntries = (fatSize * 8) / 12

        for i in 0..<totalEntries {
            let byteOffset = fatOffset + (i * 3) / 2
            guard byteOffset + 1 < data.count else { break }

            let value: UInt16
            if i % 2 == 0 {
                // Even entry: low 8 bits + low 4 bits of next byte
                value = UInt16(data[byteOffset]) | ((UInt16(data[byteOffset + 1]) & 0x0F) << 8)
            } else {
                // Odd entry: high 4 bits of current + all 8 bits of next
                value = (UInt16(data[byteOffset]) >> 4) | (UInt16(data[byteOffset + 1]) << 4)
            }
            fat.append(value)
        }

        return fat
    }

    // MARK: - Directory Parsing

    private func parseDirectory(data: Data, offset: Int, maxEntries: Int) -> [DirectoryEntry] {
        var entries: [DirectoryEntry] = []

        for i in 0..<maxEntries {
            let entryOffset = offset + i * 32
            guard entryOffset + 32 <= data.count else { break }

            let firstByte = data[entryOffset]

            // End of directory
            if firstByte == 0x00 {
                break
            }

            // Deleted entry
            if firstByte == 0xE5 {
                continue
            }

            // Parse entry
            let nameBytes = data[entryOffset..<(entryOffset + 8)]
            let extBytes = data[(entryOffset + 8)..<(entryOffset + 11)]
            let attributes = data[entryOffset + 11]
            let firstCluster = UInt16(data[entryOffset + 26]) | (UInt16(data[entryOffset + 27]) << 8)
            let fileSize = UInt32(data[entryOffset + 28]) | (UInt32(data[entryOffset + 29]) << 8) |
                          (UInt32(data[entryOffset + 30]) << 16) | (UInt32(data[entryOffset + 31]) << 24)

            let name = String(bytes: nameBytes, encoding: .ascii)?.trimmingCharacters(in: .whitespaces) ?? ""
            let ext = String(bytes: extBytes, encoding: .ascii)?.trimmingCharacters(in: .whitespaces) ?? ""

            let isDirectory = (attributes & 0x10) != 0
            let isHidden = (attributes & 0x02) != 0
            let isSystem = (attributes & 0x04) != 0
            let isVolumeLabel = (attributes & 0x08) != 0

            // Skip volume labels and LFN entries
            if isVolumeLabel || attributes == 0x0F {
                continue
            }

            let entry = DirectoryEntry(
                name: name,
                extension_: ext,
                attributes: attributes,
                firstCluster: firstCluster,
                fileSize: fileSize,
                isDirectory: isDirectory,
                isHidden: isHidden,
                isSystem: isSystem,
                isVolumeLabel: isVolumeLabel
            )

            if entry.isValid {
                entries.append(entry)
            }
        }

        return entries
    }

    // MARK: - Subdirectory Reading

    private func readSubdirectory(data: Data, entry: DirectoryEntry, geometry: DiskGeometry,
                                   fat: [UInt16], path: String) -> [DiskCatalogEntry] {
        var catalogEntries: [DiskCatalogEntry] = []

        // Get clusters for this directory
        let clusters = getClusterChain(startCluster: entry.firstCluster, fat: fat)

        // Read directory entries from all clusters
        var dirData = Data()
        for cluster in clusters {
            let clusterOffset = clusterToOffset(cluster: cluster, geometry: geometry)
            let clusterSize = geometry.sectorsPerCluster * sectorSize

            guard clusterOffset + clusterSize <= data.count else { continue }

            dirData.append(data[clusterOffset..<(clusterOffset + clusterSize)])
        }

        let maxEntries = dirData.count / 32
        let subEntries = parseDirectory(data: dirData, offset: 0, maxEntries: maxEntries)

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

        var fileData = Data()
        let clusterSize = geometry.sectorsPerCluster * sectorSize
        var remaining = Int(entry.fileSize)

        for cluster in clusters {
            let offset = clusterToOffset(cluster: cluster, geometry: geometry)
            let bytesToRead = min(clusterSize, remaining)

            guard offset + bytesToRead <= data.count else { break }

            fileData.append(data[offset..<(offset + bytesToRead)])
            remaining -= bytesToRead

            if remaining <= 0 {
                break
            }
        }

        return fileData
    }

    // MARK: - Cluster Chain

    private func getClusterChain(startCluster: UInt16, fat: [UInt16]) -> [UInt16] {
        var clusters: [UInt16] = []
        var current = startCluster
        var visited = Set<UInt16>()

        while current >= 2 && current < 0xFF8 {
            if visited.contains(current) {
                break  // Avoid infinite loops
            }
            visited.insert(current)
            clusters.append(current)

            guard Int(current) < fat.count else { break }
            current = fat[Int(current)]
        }

        return clusters
    }

    private func clusterToOffset(cluster: UInt16, geometry: DiskGeometry) -> Int {
        let clusterSize = geometry.sectorsPerCluster * sectorSize
        return geometry.firstDataSector * sectorSize + (Int(cluster) - 2) * clusterSize
    }

    // MARK: - File Type Detection

    private func detectFileType(name: String, data: Data) -> String {
        let ext = (name as NSString).pathExtension.uppercased()

        // Atari ST image formats
        switch ext {
        case "PI1", "PI2", "PI3":
            return "Degas"
        case "PC1", "PC2", "PC3":
            return "Degas Elite"
        case "NEO":
            return "NEOchrome"
        case "TNY", "TN1", "TN2", "TN3":
            return "Tiny"
        case "IFF", "LBM":
            return "IFF"
        case "IMG":
            return "GEM IMG"
        case "SPU", "SPC":
            return "Spectrum 512"
        default:
            break
        }

        // Check by file content
        if data.count >= 4 {
            // Degas format check
            if data.count == 32034 || data.count == 32066 {
                let resolution = UInt16(data[0]) | (UInt16(data[1]) << 8)
                if resolution <= 2 {
                    return "Degas"
                }
            }

            // NEOchrome format (starts with 0x00 0x00 for resolution)
            if data.count == 32128 {
                return "NEOchrome"
            }

            // IFF/ILBM check
            if data[0] == 0x46 && data[1] == 0x4F && data[2] == 0x52 && data[3] == 0x4D {
                return "IFF"
            }
        }

        return ext.isEmpty ? "Unknown" : ext
    }

    // MARK: - Image Type Detection

    private func detectImageType(name: String, data: Data) -> (isImage: Bool, imageType: AppleIIImageType) {
        let ext = (name as NSString).pathExtension.uppercased()

        // Check by extension first
        switch ext {
        case "PI1", "PI2", "PI3":
            // Try to decode to get the actual resolution
            let result = AtariSTDecoder.decodeDegas(data: data)
            if result.image != nil {
                return (true, result.type)
            }
            return (true, .DEGAS(resolution: "Low", colors: 16))

        case "PC1", "PC2", "PC3":
            // Compressed Degas Elite - would need decoder support
            return (true, .DEGAS(resolution: "Low", colors: 16))

        case "NEO":
            let result = AtariSTDecoder.decodeNEOchrome(data: data)
            if result.image != nil {
                return (true, result.type)
            }
            return (true, .NEOchrome(colors: 16))

        case "IFF", "LBM":
            return (true, .IFF(width: 320, height: 200, colors: "32"))

        default:
            break
        }

        // Check by file content
        if data.count >= 4 {
            // Degas format check
            if data.count == 32034 || data.count == 32066 {
                let result = AtariSTDecoder.decodeDegas(data: data)
                if result.image != nil {
                    return (true, result.type)
                }
            }

            // NEOchrome format
            if data.count == 32128 {
                let result = AtariSTDecoder.decodeNEOchrome(data: data)
                if result.image != nil {
                    return (true, result.type)
                }
            }

            // IFF/ILBM check
            if data[0] == 0x46 && data[1] == 0x4F && data[2] == 0x52 && data[3] == 0x4D {
                return (true, .IFF(width: 320, height: 200, colors: "32"))
            }
        }

        return (false, .Unknown)
    }
}
