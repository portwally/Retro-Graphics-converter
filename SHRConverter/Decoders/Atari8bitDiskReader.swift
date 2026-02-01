import Foundation
import AppKit

/// Reader for Atari 8-bit disk images (.atr files)
/// Supports Atari DOS 2.0/2.5 filesystem on single, enhanced, and double density disks
class Atari8bitDiskReader {

    // MARK: - Constants

    private let atrMagic: UInt16 = 0x0296  // ATR signature bytes 0x96 0x02 (little-endian)

    // MARK: - Types

    enum DensityType {
        case single      // 40 tracks × 18 sectors × 128 bytes = 92,160 bytes
        case enhanced    // 40 tracks × 26 sectors × 128 bytes = 133,120 bytes
        case double_     // 40 tracks × 18 sectors × 256 bytes = 183,936 bytes
    }

    struct ATRHeader {
        let magic: UInt16
        let paragraphsLow: UInt16
        let sectorSize: UInt16
        let paragraphsHigh: UInt16
        let flags: UInt8

        var totalParagraphs: UInt32 {
            UInt32(paragraphsLow) | (UInt32(paragraphsHigh) << 16)
        }

        var totalBytes: Int {
            Int(totalParagraphs) * 16
        }
    }

    struct DiskGeometry {
        let sectorSize: Int
        let bootSectorSize: Int  // First 3 sectors are always 128 bytes (traditional ATR)
        let totalSectors: Int
        let density: DensityType
        var uniformSectors: Bool = false  // BitPast-style: all sectors same size
    }

    struct DirectoryEntry {
        let flags: UInt8
        let sectorCount: UInt16
        let startSector: UInt16
        let filename: String
        let extension_: String

        var isDeleted: Bool { flags == 0x00 || flags == 0x80 }
        var isInUse: Bool {
            // Valid DOS 2.0 flags: 0x42 (in use), 0x43 (in use, locked), 0x03 (DOS 2.5)
            // Bits: bit 6 = in use, bit 5 = locked, bit 1 = DOS 2.5/open for output, bit 0 = open for input
            let validFlags: [UInt8] = [0x42, 0x43, 0x62, 0x63, 0x02, 0x03, 0x22, 0x23]
            return validFlags.contains(flags)
        }
        var isLocked: Bool { (flags & 0x20) != 0 }
        var isDirectory: Bool { false }  // Atari DOS 2.0 doesn't support directories

        var fullName: String {
            let trimmedName = filename.trimmingCharacters(in: .whitespaces)
            let trimmedExt = extension_.trimmingCharacters(in: .whitespaces)
            if trimmedExt.isEmpty {
                return trimmedName
            }
            return "\(trimmedName).\(trimmedExt)"
        }

        /// Check if filename contains valid Atari DOS characters
        var hasValidFilename: Bool {
            let trimmedName = filename.trimmingCharacters(in: .whitespaces)
            guard !trimmedName.isEmpty else { return false }

            // Valid Atari DOS filename characters: A-Z, 0-9, and some punctuation
            let validChars = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
            for char in trimmedName.unicodeScalars {
                if !validChars.contains(char) {
                    return false
                }
            }
            return true
        }
    }

    // MARK: - Detection

    /// Check if data appears to be an ATR disk image
    func canRead(data: Data) -> Bool {
        // ATR header is 16 bytes
        guard data.count >= 16 else { return false }

        // Check magic number (0x96 0x02 = 0x9602 little-endian)
        let magic = UInt16(data[0]) | (UInt16(data[1]) << 8)
        guard magic == atrMagic else { return false }

        // Parse header
        guard let header = parseATRHeader(data: data) else { return false }

        // Validate sector size
        guard header.sectorSize == 128 || header.sectorSize == 256 || header.sectorSize == 512 else {
            return false
        }

        // Validate data size matches header
        let expectedDataSize = header.totalBytes
        let actualDataSize = data.count - 16  // Subtract header

        // Allow some tolerance for padding
        guard actualDataSize >= expectedDataSize - 256 else { return false }

        return true
    }

    // MARK: - Reading

    /// Read all files from the ATR disk image
    func readDisk(data: Data) -> [DiskCatalogEntry]? {
        guard let header = parseATRHeader(data: data) else { return nil }
        guard var geometry = determineGeometry(header: header, dataSize: data.count - 16) else { return nil }

        // Try to detect if disk uses uniform sectors (BitPast-style) or traditional ATR format
        // Check for valid VTOC at uniform sector offset first (more common with modern tools)
        if detectUniformSectors(data: data, geometry: geometry) {
            geometry.uniformSectors = true
        }

        // Read directory using DOS filesystem
        let entries = readDirectory(data: data, geometry: geometry)

        var catalogEntries: [DiskCatalogEntry] = []

        for entry in entries {
            guard entry.isInUse && !entry.isDeleted && entry.hasValidFilename else { continue }

            // Additional validation: start sector must be reasonable
            guard entry.startSector > 0 && entry.startSector < geometry.totalSectors else { continue }

            if let fileData = extractFile(data: data, entry: entry, geometry: geometry) {
                let fileTypeStr = detectFileType(name: entry.fullName, data: fileData)
                let (isImage, imageType) = detectImageType(name: entry.fullName, data: fileData)

                let catalogEntry = DiskCatalogEntry(
                    name: entry.fullName,
                    fileType: 0,
                    fileTypeString: fileTypeStr,
                    size: fileData.count,
                    blocks: Int(entry.sectorCount),
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

        // If no files found via DOS, try raw graphics extraction
        if catalogEntries.isEmpty {
            catalogEntries = extractRawGraphics(data: data)
        }

        return catalogEntries.isEmpty ? nil : catalogEntries
    }

    /// Detect if disk uses uniform sector sizes (BitPast-style) vs traditional ATR
    private func detectUniformSectors(data: Data, geometry: DiskGeometry) -> Bool {
        let headerSize = 16

        // Check for valid VTOC at sector 360 using uniform offsets
        let uniformVtocOffset = headerSize + (360 - 1) * geometry.sectorSize
        guard uniformVtocOffset + 5 <= data.count else { return false }

        // VTOC should have DOS type at offset 0 (0x02 for DOS 2.0/2.5)
        let dosType = data[uniformVtocOffset]
        if dosType == 0x02 {
            // Also check directory at sector 361
            let uniformDirOffset = headerSize + (361 - 1) * geometry.sectorSize
            if uniformDirOffset + 1 <= data.count {
                let dirFlags = data[uniformDirOffset]
                // Valid directory entry flags: 0x42 (in use), 0x00 (empty)
                if dirFlags == 0x42 || dirFlags == 0x00 || dirFlags == 0x43 {
                    return true
                }
            }
        }

        return false
    }

    // MARK: - Raw Graphics Extraction

    /// Extract graphics from raw disk (no filesystem)
    private func extractRawGraphics(data: Data) -> [DiskCatalogEntry] {
        let headerSize = 16
        guard data.count > headerSize else { return [] }

        let diskData = data.subdata(in: headerSize..<data.count)
        var entries: [DiskCatalogEntry] = []

        // Standard Atari graphics screen size
        let screenSize = 7680  // 40 bytes × 192 lines

        // Extract images at screen boundaries
        var imageIndex = 0
        var offset = 0

        while offset + screenSize <= diskData.count {
            let imageData = diskData.subdata(in: offset..<(offset + screenSize))

            // Check if this region has significant non-zero content
            let nonZeroCount = imageData.filter { $0 != 0 }.count
            if nonZeroCount > 100 {  // At least ~1.3% non-zero (avoid blank images)
                let imageName = String(format: "IMAGE%02d.GR15", imageIndex + 1)
                let (isImage, imageType) = detectImageType(name: imageName, data: imageData)

                let entry = DiskCatalogEntry(
                    name: imageName,
                    fileType: 0,
                    fileTypeString: "GR.15",
                    size: imageData.count,
                    blocks: (imageData.count + 255) / 256,
                    loadAddress: nil,
                    length: nil,
                    data: imageData,
                    isImage: isImage,
                    imageType: imageType,
                    isDirectory: false,
                    children: nil
                )
                entries.append(entry)
                imageIndex += 1
            }

            offset += screenSize
        }

        return entries
    }

    // MARK: - Header Parsing

    private func parseATRHeader(data: Data) -> ATRHeader? {
        guard data.count >= 16 else { return nil }

        let magic = UInt16(data[0]) | (UInt16(data[1]) << 8)
        let paragraphsLow = UInt16(data[2]) | (UInt16(data[3]) << 8)
        let sectorSize = UInt16(data[4]) | (UInt16(data[5]) << 8)
        let paragraphsHigh = UInt16(data[6]) | (UInt16(data[7]) << 8)
        let flags = data[8]

        return ATRHeader(
            magic: magic,
            paragraphsLow: paragraphsLow,
            sectorSize: sectorSize,
            paragraphsHigh: paragraphsHigh,
            flags: flags
        )
    }

    private func determineGeometry(header: ATRHeader, dataSize: Int) -> DiskGeometry? {
        let sectorSize = Int(header.sectorSize)

        // First 3 sectors are always 128 bytes regardless of disk density
        let bootSectorSize = 128

        // Calculate total sectors based on data size
        // Data size = 3 × 128 + (totalSectors - 3) × sectorSize
        let bootArea = 3 * bootSectorSize
        let remainingData = dataSize - bootArea

        let totalSectors: Int
        let density: DensityType

        if sectorSize == 128 {
            totalSectors = dataSize / 128
            if totalSectors <= 720 {
                density = .single
            } else {
                density = .enhanced
            }
        } else {
            // Double density: first 3 sectors are 128, rest are 256
            totalSectors = 3 + (remainingData / sectorSize)
            density = .double_
        }

        return DiskGeometry(
            sectorSize: sectorSize,
            bootSectorSize: bootSectorSize,
            totalSectors: totalSectors,
            density: density
        )
    }

    // MARK: - Sector Access

    /// Get offset in ATR file for a given sector (1-based)
    private func sectorOffset(sector: Int, geometry: DiskGeometry) -> Int {
        // Sectors are 1-based
        guard sector >= 1 else { return -1 }

        let headerSize = 16

        // BitPast-style: all sectors are same size
        if geometry.uniformSectors {
            return headerSize + (sector - 1) * geometry.sectorSize
        }

        // Traditional ATR: boot sectors (1-3) are 128 bytes, rest use sectorSize
        if sector <= 3 {
            return headerSize + (sector - 1) * 128
        } else {
            let bootArea = 3 * 128
            return headerSize + bootArea + (sector - 4) * geometry.sectorSize
        }
    }

    /// Read a sector from the disk
    private func readSector(data: Data, sector: Int, geometry: DiskGeometry) -> Data? {
        let offset = sectorOffset(sector: sector, geometry: geometry)
        guard offset >= 0 else { return nil }

        // Determine sector size
        let size: Int
        if geometry.uniformSectors {
            size = geometry.sectorSize
        } else {
            size = sector <= 3 ? 128 : geometry.sectorSize
        }

        guard offset + size <= data.count else { return nil }

        return data.subdata(in: offset..<(offset + size))
    }

    // MARK: - Directory Reading

    /// Read directory entries from sectors 361-368
    private func readDirectory(data: Data, geometry: DiskGeometry) -> [DirectoryEntry] {
        var entries: [DirectoryEntry] = []

        // Directory spans sectors 361-368 (8 sectors)
        for dirSector in 361...368 {
            guard let sectorData = readSector(data: data, sector: dirSector, geometry: geometry) else {
                continue
            }

            // Each sector holds 8 entries (16 bytes each for 128-byte sectors)
            let entriesPerSector = sectorData.count / 16

            for i in 0..<entriesPerSector {
                let entryOffset = i * 16
                guard entryOffset + 16 <= sectorData.count else { break }

                let flags = sectorData[entryOffset]

                // Skip empty/unused entries and deleted entries
                if flags == 0x00 || flags == 0x80 { continue }

                // Skip entries with invalid flag values (not standard DOS 2.0 flags)
                let validFlags: [UInt8] = [0x42, 0x43, 0x62, 0x63, 0x02, 0x03, 0x22, 0x23]
                if !validFlags.contains(flags) { continue }

                let sectorCountLow = sectorData[entryOffset + 1]
                let sectorCountHigh = sectorData[entryOffset + 2]
                let sectorCount = UInt16(sectorCountLow) | (UInt16(sectorCountHigh) << 8)

                let startSectorLow = sectorData[entryOffset + 3]
                let startSectorHigh = sectorData[entryOffset + 4]
                let startSector = UInt16(startSectorLow) | (UInt16(startSectorHigh) << 8)

                // Filename: bytes 5-12 (8 characters)
                let filenameBytes = sectorData[(entryOffset + 5)..<(entryOffset + 13)]
                let filename = String(bytes: filenameBytes, encoding: .ascii)?
                    .trimmingCharacters(in: .whitespaces) ?? ""

                // Extension: bytes 13-15 (3 characters)
                let extBytes = sectorData[(entryOffset + 13)..<(entryOffset + 16)]
                let ext = String(bytes: extBytes, encoding: .ascii)?
                    .trimmingCharacters(in: .whitespaces) ?? ""

                let entry = DirectoryEntry(
                    flags: flags,
                    sectorCount: sectorCount,
                    startSector: startSector,
                    filename: filename,
                    extension_: ext
                )

                entries.append(entry)
            }
        }

        return entries
    }

    // MARK: - File Extraction

    /// Extract file data by following sector chain
    private func extractFile(data: Data, entry: DirectoryEntry, geometry: DiskGeometry) -> Data? {
        guard entry.startSector > 0 else { return Data() }

        // First try DOS 2.0 sector chain extraction
        var fileData = extractFileWithChain(data: data, entry: entry, geometry: geometry)

        // If chain extraction failed or got too little data, try sequential extraction
        // (BitPast and some other tools write files without proper sector links)
        let expectedMinSize = min(Int(entry.sectorCount) * 125, 7680)  // Typical GR file size
        if fileData.count < expectedMinSize {
            let sequentialData = extractFileSequential(data: data, entry: entry, geometry: geometry)
            if sequentialData.count > fileData.count {
                fileData = sequentialData
            }
        }

        return fileData
    }

    /// Extract file by following DOS 2.0 sector chain
    private func extractFileWithChain(data: Data, entry: DirectoryEntry, geometry: DiskGeometry) -> Data {
        var fileData = Data()
        var currentSector = Int(entry.startSector)
        var sectorsRead = 0
        let maxSectors = Int(entry.sectorCount) + 10  // Allow some tolerance

        while currentSector > 0 && sectorsRead < maxSectors {
            guard let sectorData = readSector(data: data, sector: currentSector, geometry: geometry) else {
                break
            }

            // DOS 2.0 sector format - link bytes are at the END of the sector:
            // For 128-byte sectors: 125 data bytes + 3 link bytes (at 125, 126, 127)
            // For 256-byte sectors: 253 data bytes + 3 link bytes (at 253, 254, 255)
            // Link format:
            //   Byte N-2: File number (bits 2-7) + next sector high (bits 0-1)
            //   Byte N-1: Next sector low byte
            //   Byte N:   Bytes used in this sector

            let dataBytes: Int
            let nextSector: Int
            let sectorLen = sectorData.count

            if sectorLen >= 128 {
                // DOS 2.0 format with sector linking - link bytes at end of sector
                let linkOffset = sectorLen - 3
                let maxDataBytes = sectorLen - 3

                let linkByte = sectorData[linkOffset]
                let nextLow = sectorData[linkOffset + 1]
                let bytesUsed = sectorData[linkOffset + 2]

                nextSector = Int(nextLow) | (Int(linkByte & 0x03) << 8)
                dataBytes = bytesUsed > 0 && bytesUsed <= maxDataBytes ? Int(bytesUsed) : maxDataBytes

                // Append only the data portion
                fileData.append(sectorData[0..<dataBytes])
            } else {
                // Smaller sector or different format - use all data
                fileData.append(sectorData)
                nextSector = 0
            }

            currentSector = nextSector
            sectorsRead += 1

            // End of file marker
            if nextSector == 0 { break }
        }

        return fileData
    }

    /// Extract file by reading sequential sectors (fallback for non-DOS format)
    private func extractFileSequential(data: Data, entry: DirectoryEntry, geometry: DiskGeometry) -> Data {
        var fileData = Data()
        let startSector = Int(entry.startSector)
        let sectorCount = Int(entry.sectorCount)

        for i in 0..<sectorCount {
            let sector = startSector + i
            guard let sectorData = readSector(data: data, sector: sector, geometry: geometry) else {
                break
            }

            // For sequential reading, use full sector data (no link bytes)
            fileData.append(sectorData)
        }

        return fileData
    }

    // MARK: - File Type Detection

    private func detectFileType(name: String, data: Data) -> String {
        let ext = (name as NSString).pathExtension.uppercased()

        switch ext {
        // Atari 8-bit graphics formats
        case "GR8":
            return "Graphics 8 (Hi-Res)"
        case "GR9":
            return "Graphics 9 (GTIA)"
        case "GR15", "GR7":
            return "Graphics 15/7 (4-color)"
        case "GR10":
            return "Graphics 10 (9 colors)"
        case "GR11":
            return "Graphics 11 (GTIA)"
        case "GR1", "GR2", "GR3", "GR4", "GR5", "GR6":
            // Detect by file size: GR.10 = 7689 bytes, GR.15 = 7684 bytes
            if data.count == 7689 {
                return "Graphics 10 (9 colors)"
            }
            return "Graphics 15 (4-color)"
        case "MIC":
            return "MicroIllustrator"
        case "PIC":
            return "Atari Picture"
        // Other formats
        case "BAS":
            return "Atari BASIC"
        case "COM", "XEX":
            return "Executable"
        case "OBJ":
            return "Object File"
        case "DAT":
            return "Data"
        case "TXT", "DOC":
            return "Text"
        case "FNT":
            return "Font"
        default:
            break
        }

        // Check for binary load file header
        if data.count >= 4 && data[0] == 0xFF && data[1] == 0xFF {
            return "Atari Binary"
        }

        return ext.isEmpty ? "Unknown" : ext
    }

    // MARK: - Image Type Detection

    private func detectImageType(name: String, data: Data) -> (isImage: Bool, imageType: AppleIIImageType) {
        let ext = (name as NSString).pathExtension.uppercased()

        // Check by extension
        switch ext {
        case "GR8":
            if data.count >= 7680 {
                return (true, .Atari8bit(mode: "GR.8", colors: 2))
            }
        case "GR9":
            if data.count >= 7680 {
                return (true, .Atari8bit(mode: "GR.9", colors: 8))
            }
        case "GR15", "GR7":
            if data.count >= 7680 {
                return (true, .Atari8bit(mode: "GR.15", colors: 4))
            }
        case "GR10":
            if data.count >= 7680 {
                return (true, .Atari8bit(mode: "GR.10", colors: 9))
            }
        case "GR11":
            if data.count >= 7680 {
                return (true, .Atari8bit(mode: "GR.11", colors: 16))
            }
        case "GR1", "GR2", "GR3", "GR4", "GR5", "GR6":
            // BitPast exports - extension gets truncated by Atari DOS
            // Detect by embedded palette size: GR.10 = 7689 (9 colors), GR.15 = 7684 (4 colors)
            if data.count == 7689 {
                return (true, .Atari8bit(mode: "GR.10", colors: 9))
            } else if data.count >= 7680 {
                return (true, .Atari8bit(mode: "GR.15", colors: 4))
            }
        case "MIC":
            if data.count >= 7680 {
                return (true, .Atari8bit(mode: "MIC", colors: 4))
            }
        case "PIC":
            // Generic picture - try to detect
            if data.count == 7680 {
                return (true, .Atari8bit(mode: "GR.15", colors: 4))
            } else if data.count >= 7680 && data.count <= 7800 {
                return (true, .Atari8bit(mode: "MIC", colors: 4))
            }
        default:
            break
        }

        // Check by file size (common Atari graphics sizes)
        if data.count == 7680 {
            // Could be GR.8, GR.9, GR.15 - assume GR.15 for art files
            return (true, .Atari8bit(mode: "GR.15", colors: 4))
        } else if data.count >= 7680 && data.count <= 7800 {
            // Likely MIC format
            return (true, .Atari8bit(mode: "MIC", colors: 4))
        }

        return (false, .Unknown)
    }
}
