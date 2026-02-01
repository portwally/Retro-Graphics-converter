import Foundation
import AppKit

/// Reader for BBC Micro disk images (.ssd, .dsd files with DFS filesystem)
/// Supports:
/// - .ssd: Single-sided 40/80 track (100KB/200KB)
/// - .dsd: Double-sided 40/80 track (200KB/400KB)
class BBCMicroDiskReader {

    // MARK: - Types

    struct DiskGeometry {
        let bytesPerSector: Int
        let sectorsPerTrack: Int
        let tracks: Int
        let sides: Int
        let totalSectors: Int

        var totalSize: Int { totalSectors * bytesPerSector }
    }

    struct DirectoryEntry {
        let filename: String
        let directory: Character
        let locked: Bool
        let loadAddress: UInt32
        let execAddress: UInt32
        let length: UInt32
        let startSector: UInt16

        var fullName: String {
            let trimmedName = filename.trimmingCharacters(in: .whitespaces)
            if directory == "$" {
                return trimmedName
            }
            return ":\(directory).\(trimmedName)"
        }

        var displayName: String {
            filename.trimmingCharacters(in: .whitespaces)
        }

        var isValid: Bool {
            !filename.trimmingCharacters(in: .whitespaces).isEmpty && startSector > 1
        }
    }

    // MARK: - Detection

    /// Check if data appears to be a BBC Micro DFS disk image
    func canRead(data: Data) -> Bool {
        // Must have at least the catalog sectors (0 and 1)
        guard data.count >= 512 else { return false }

        // BBC Micro DFS disks come in standard sizes (with some tolerance)
        // 100KB (40 track SS), 200KB (40 track DS or 80 track SS), 400KB (80 track DS)
        let validSizeRanges: [(min: Int, max: Int)] = [
            (99 * 1024, 105 * 1024),    // ~100KB: 40 track SS
            (195 * 1024, 210 * 1024),   // ~200KB: 40 track DS or 80 track SS
            (395 * 1024, 410 * 1024),   // ~400KB: 80 track DS
        ]

        let sizeIsValid = validSizeRanges.contains { data.count >= $0.min && data.count <= $0.max }
        guard sizeIsValid else { return false }

        // Validate DFS catalog structure in sector 1
        // Byte 5 should contain number of entries × 8 (max 31 entries = 248)
        let numEntriesRaw = data[256 + 5]
        let numEntries = numEntriesRaw / 8
        guard numEntries <= 31 else { return false }

        // Sector count check - sector info at bytes 6-7 of sector 1
        // Byte 6: bits 0-1 = sector count high, bits 4-5 = boot option
        let sectorsHigh = data[256 + 6] & 0x03
        let sectorsLow = data[256 + 7]
        let totalSectors = (Int(sectorsHigh) << 8) | Int(sectorsLow)

        // Total sectors should be reasonable for disk size
        // Note: DFS catalog only describes one side, so for DSD disks the sector count
        // may be half the physical capacity. Also some tools write incorrect sector counts.
        let expectedSectors = data.count / 256
        // Be lenient - some disks report much fewer sectors than physical capacity
        guard totalSectors > 0 && totalSectors <= expectedSectors + 10 else { return false }

        // Check disk title - should be printable ASCII, spaces, nulls, or high-bit set chars
        // Some old disks have non-standard characters, so be lenient
        var invalidChars = 0
        for i in 0..<8 {
            let byte = data[i] & 0x7F  // Mask off high bit
            if byte != 0 && (byte < 0x20 || byte > 0x7E) {
                invalidChars += 1
            }
        }
        // Allow up to 2 invalid characters (some disks have control codes)
        guard invalidChars <= 2 else { return false }

        return true
    }

    // MARK: - Reading

    /// Read all files from the BBC Micro disk image
    /// - Parameters:
    ///   - data: The disk image data
    ///   - diskFilename: Optional disk filename to detect mode hints (e.g., "mode0" in filename)
    func readDisk(data: Data, diskFilename: String? = nil) -> [DiskCatalogEntry]? {
        guard data.count >= 512 else { return nil }

        let geometry = detectGeometry(data: data)

        // Detect mode hint from disk filename (e.g., "bbc_double_mode0.dsd" -> mode 0)
        let modeHint = detectModeHint(from: diskFilename)

        // Read catalog
        let entries = readCatalog(data: data)
        guard !entries.isEmpty || entries.count == 0 else { return nil }  // Empty disk is valid

        var catalogEntries: [DiskCatalogEntry] = []

        for entry in entries {
            guard entry.isValid else { continue }

            if let fileData = extractFile(data: data, entry: entry, geometry: geometry) {
                let fileTypeStr = detectFileType(entry: entry, data: fileData)
                let (isImage, imageType) = detectImageType(entry: entry, data: fileData, modeHint: modeHint)

                let catalogEntry = DiskCatalogEntry(
                    name: entry.displayName,
                    fileType: 0,
                    fileTypeString: fileTypeStr,
                    size: Int(entry.length),
                    blocks: nil,
                    loadAddress: Int(entry.loadAddress),
                    length: Int(entry.length),
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

    // MARK: - Geometry Detection

    private func detectGeometry(data: Data) -> DiskGeometry {
        let bytesPerSector = 256
        let sectorsPerTrack = 10

        switch data.count {
        case 100 * 1024:  // 100KB - 40 track single-sided
            return DiskGeometry(
                bytesPerSector: bytesPerSector,
                sectorsPerTrack: sectorsPerTrack,
                tracks: 40,
                sides: 1,
                totalSectors: 400
            )
        case 200 * 1024:  // 200KB - 40 track double-sided or 80 track single-sided
            // Assume 40 track DS (more common)
            return DiskGeometry(
                bytesPerSector: bytesPerSector,
                sectorsPerTrack: sectorsPerTrack,
                tracks: 40,
                sides: 2,
                totalSectors: 800
            )
        case 400 * 1024:  // 400KB - 80 track double-sided
            return DiskGeometry(
                bytesPerSector: bytesPerSector,
                sectorsPerTrack: sectorsPerTrack,
                tracks: 80,
                sides: 2,
                totalSectors: 1600
            )
        default:
            // Calculate from actual size
            let totalSectors = data.count / bytesPerSector
            return DiskGeometry(
                bytesPerSector: bytesPerSector,
                sectorsPerTrack: sectorsPerTrack,
                tracks: totalSectors / sectorsPerTrack,
                sides: 1,
                totalSectors: totalSectors
            )
        }
    }

    // MARK: - Catalog Reading

    private func readCatalog(data: Data) -> [DirectoryEntry] {
        guard data.count >= 512 else { return [] }

        // Get number of entries from sector 1, byte 5
        let numEntriesRaw = data[256 + 5]
        let numEntries = Int(numEntriesRaw) / 8

        guard numEntries > 0 && numEntries <= 31 else { return [] }

        var entries: [DirectoryEntry] = []

        for i in 0..<numEntries {
            // Entry data is split between sector 0 and sector 1
            // Sector 0: bytes 8 + i*8 to 8 + i*8 + 7 (filename + directory)
            // Sector 1: bytes 8 + i*8 to 8 + i*8 + 7 (addresses + length + start sector)

            let s0Offset = 8 + i * 8
            let s1Offset = 256 + 8 + i * 8

            guard s0Offset + 8 <= 256 && s1Offset + 8 <= data.count else { break }

            // Read filename (7 chars) from sector 0
            var filenameBytes = [UInt8](data[s0Offset..<s0Offset + 7])
            // Mask off high bits (used for other purposes in some DFS variants)
            for j in 0..<7 {
                filenameBytes[j] = filenameBytes[j] & 0x7F
            }
            let filename = String(bytes: filenameBytes, encoding: .ascii) ?? ""

            // Directory character and locked flag from sector 0, byte 7
            let dirByte = data[s0Offset + 7]
            let directory = Character(UnicodeScalar(dirByte & 0x7F))
            let locked = (dirByte & 0x80) != 0

            // Read addresses and length from sector 1
            let loadAddrLow = UInt16(data[s1Offset]) | (UInt16(data[s1Offset + 1]) << 8)
            let execAddrLow = UInt16(data[s1Offset + 2]) | (UInt16(data[s1Offset + 3]) << 8)
            let lengthLow = UInt16(data[s1Offset + 4]) | (UInt16(data[s1Offset + 5]) << 8)

            // Extra bits byte
            let extraBits = data[s1Offset + 6]
            // Bits 0-1: exec address bits 16-17
            // Bits 2-3: length bits 16-17
            // Bits 4-5: load address bits 16-17
            // Bits 6-7: start sector bits 8-9

            let execAddrHigh = UInt32(extraBits & 0x03) << 16
            let lengthHigh = UInt32((extraBits >> 2) & 0x03) << 16
            let loadAddrHigh = UInt32((extraBits >> 4) & 0x03) << 16
            let startSectorHigh = UInt16((extraBits >> 6) & 0x03) << 8

            let loadAddress = UInt32(loadAddrLow) | loadAddrHigh
            let execAddress = UInt32(execAddrLow) | execAddrHigh
            let length = UInt32(lengthLow) | lengthHigh

            // Start sector
            let startSectorLow = data[s1Offset + 7]
            var startSector = UInt16(startSectorLow) | startSectorHigh

            // Validate start sector - some tools (like BitPast) incorrectly set high bits
            // If calculated sector is outside disk, use just the low byte
            let maxSectors = data.count / 256
            if startSector >= maxSectors {
                startSector = UInt16(startSectorLow)
            }

            let entry = DirectoryEntry(
                filename: filename,
                directory: directory,
                locked: locked,
                loadAddress: loadAddress,
                execAddress: execAddress,
                length: length,
                startSector: startSector
            )

            entries.append(entry)
        }

        return entries
    }

    // MARK: - File Extraction

    private func extractFile(data: Data, entry: DirectoryEntry, geometry: DiskGeometry) -> Data? {
        guard entry.length > 0 else { return Data() }

        let startOffset = Int(entry.startSector) * geometry.bytesPerSector
        let length = Int(entry.length)

        guard startOffset >= 0 && startOffset + length <= data.count else { return nil }

        return Data(data[startOffset..<startOffset + length])
    }

    // MARK: - Mode Hint Detection

    /// Detect BBC Micro screen mode from disk filename
    /// - Parameter filename: The disk filename (e.g., "bbc_double_mode0.dsd")
    /// - Returns: The detected mode (0-5) or nil if not detected
    private func detectModeHint(from filename: String?) -> Int? {
        guard let name = filename?.lowercased() else { return nil }

        // Look for "mode X" or "mode_X" or "modeX" patterns
        if name.contains("mode0") || name.contains("mode_0") || name.contains("mode 0") {
            return 0
        }
        if name.contains("mode1") || name.contains("mode_1") || name.contains("mode 1") {
            return 1
        }
        if name.contains("mode2") || name.contains("mode_2") || name.contains("mode 2") {
            return 2
        }
        if name.contains("mode4") || name.contains("mode_4") || name.contains("mode 4") {
            return 4
        }
        if name.contains("mode5") || name.contains("mode_5") || name.contains("mode 5") {
            return 5
        }

        return nil
    }

    // MARK: - File Type Detection

    private func detectFileType(entry: DirectoryEntry, data: Data) -> String {
        let filename = entry.displayName.uppercased()

        // Check by extension
        if let dotIdx = filename.lastIndex(of: ".") {
            let ext = String(filename[filename.index(after: dotIdx)...]).uppercased()

            switch ext {
            // BBC Micro screen modes
            case "SCR", "SCREEN":
                return "Screen Data"
            case "MODE0", "M0":
                return "MODE 0 Screen"
            case "MODE1", "M1":
                return "MODE 1 Screen"
            case "MODE2", "M2":
                return "MODE 2 Screen"
            case "MODE4", "M4":
                return "MODE 4 Screen"
            case "MODE5", "M5":
                return "MODE 5 Screen"
            // Program types
            case "BAS", "BASIC":
                return "BASIC Program"
            case "TXT", "TEXT":
                return "Text File"
            default:
                break
            }
        }

        // Check by load address (BBC Micro conventions)
        // &FFFF0E00 = BitPast default / BASIC program area
        // &FFFF3000 = Screen memory (MODE 0,1,2)
        // &FFFF5800 = Screen memory (MODE 4,5)
        // &FFFF1900 = BASIC workspace

        let loadAddr = entry.loadAddress & 0xFFFF  // Low 16 bits

        // Valid sizes for BBC Micro screen files (with optional embedded palette)
        let is20KBScreen = data.count >= 20480 && data.count <= 20489
        let is10KBScreen = data.count >= 10240 && data.count <= 10245

        // Screen memory detection by load address
        if (loadAddr == 0x3000 || loadAddr == 0x0E00) && is20KBScreen {
            return "Screen (20KB)"
        }
        if (loadAddr == 0x5800 || loadAddr == 0x0E00) && is10KBScreen {
            return "Screen (10KB)"
        }

        // BASIC program detection
        if data.count >= 2 && data[0] == 0x0D {
            // BASIC programs often start with carriage return
            return "BASIC Program"
        }

        // Size-based detection for screen files
        if is20KBScreen {
            return "Screen (20KB)"
        }
        if is10KBScreen {
            return "Screen (10KB)"
        }

        return "Binary"
    }

    // MARK: - Image Type Detection

    /// Detect if file is an image and determine its type
    /// - Parameters:
    ///   - entry: The directory entry
    ///   - data: The file data
    ///   - modeHint: Optional mode hint from disk filename
    private func detectImageType(entry: DirectoryEntry, data: Data, modeHint: Int? = nil) -> (isImage: Bool, imageType: AppleIIImageType) {
        let filename = entry.displayName.uppercased()

        // Check by extension
        if let dotIdx = filename.lastIndex(of: ".") {
            let ext = String(filename[filename.index(after: dotIdx)...]).uppercased()

            switch ext {
            case "MODE0", "M0":
                if data.count >= 20480 {
                    return (true, .BBCMicro(mode: 0, colors: 2))
                }
            case "MODE1", "M1":
                if data.count >= 20480 {
                    return (true, .BBCMicro(mode: 1, colors: 4))
                }
            case "MODE2", "M2":
                if data.count >= 20480 {
                    return (true, .BBCMicro(mode: 2, colors: 16))
                }
            case "MODE4", "M4":
                if data.count >= 10240 {
                    return (true, .BBCMicro(mode: 4, colors: 2))
                }
            case "MODE5", "M5":
                if data.count >= 10240 {
                    return (true, .BBCMicro(mode: 5, colors: 4))
                }
            default:
                break
            }
        }

        // Check by filename patterns
        if filename.contains("MODE0") || filename.contains("MODE 0") {
            if data.count >= 20480 {
                return (true, .BBCMicro(mode: 0, colors: 2))
            }
        }
        if filename.contains("MODE1") || filename.contains("MODE 1") {
            if data.count >= 20480 {
                return (true, .BBCMicro(mode: 1, colors: 4))
            }
        }
        if filename.contains("MODE2") || filename.contains("MODE 2") {
            if data.count >= 20480 {
                return (true, .BBCMicro(mode: 2, colors: 16))
            }
        }
        if filename.contains("MODE4") || filename.contains("MODE 4") {
            if data.count >= 10240 {
                return (true, .BBCMicro(mode: 4, colors: 2))
            }
        }
        if filename.contains("MODE5") || filename.contains("MODE 5") {
            if data.count >= 10240 {
                return (true, .BBCMicro(mode: 5, colors: 4))
            }
        }

        // Check by load address and size
        let loadAddr = entry.loadAddress & 0xFFFF

        // Valid sizes for BBC Micro screen files:
        // 20KB modes (0,1,2): 20480 base, or with embedded palette: 20483 (mode 0), 20485 (mode 1), 20489 (mode 2)
        // 10KB modes (4,5): 10240 base, or with embedded palette: 10243 (mode 4), 10245 (mode 5)
        let is20KBScreen = data.count >= 20480 && data.count <= 20489
        let is10KBScreen = data.count >= 10240 && data.count <= 10245

        // MODE 0,1,2: 20KB screen at &3000 or &0E00 (BitPast default)
        if (loadAddr == 0x3000 || loadAddr == 0x0E00) && is20KBScreen {
            // Use mode hint from disk filename if available, otherwise default to MODE 1
            if let hint = modeHint, [0, 1, 2].contains(hint) {
                let colors = hint == 0 ? 2 : (hint == 1 ? 4 : 16)
                return (true, .BBCMicro(mode: hint, colors: colors))
            }
            return (true, .BBCMicro(mode: 1, colors: 4))
        }

        // MODE 4,5: 10KB screen at &5800 or &0E00 (BitPast default)
        if (loadAddr == 0x5800 || loadAddr == 0x0E00) && is10KBScreen {
            // Use mode hint from disk filename if available, otherwise default to MODE 5
            if let hint = modeHint, [4, 5].contains(hint) {
                let colors = hint == 4 ? 2 : 4
                return (true, .BBCMicro(mode: hint, colors: colors))
            }
            return (true, .BBCMicro(mode: 5, colors: 4))
        }

        // Size-based detection (fallback) - use mode hint if available
        if is20KBScreen {
            if let hint = modeHint, [0, 1, 2].contains(hint) {
                let colors = hint == 0 ? 2 : (hint == 1 ? 4 : 16)
                return (true, .BBCMicro(mode: hint, colors: colors))
            }
            return (true, .BBCMicro(mode: 1, colors: 4))
        }
        if is10KBScreen {
            if let hint = modeHint, [4, 5].contains(hint) {
                let colors = hint == 4 ? 2 : 4
                return (true, .BBCMicro(mode: hint, colors: colors))
            }
            return (true, .BBCMicro(mode: 5, colors: 4))
        }

        return (false, .Unknown)
    }

    // MARK: - Disk Title

    func readDiskTitle(data: Data) -> String {
        guard data.count >= 512 else { return "" }

        // First 8 bytes of sector 0 + first 4 bytes of sector 1
        var titleBytes: [UInt8] = []

        for i in 0..<8 {
            let byte = data[i]
            if byte == 0 { break }
            titleBytes.append(byte & 0x7F)
        }

        for i in 0..<4 {
            let byte = data[256 + i]
            if byte == 0 { break }
            titleBytes.append(byte & 0x7F)
        }

        return String(bytes: titleBytes, encoding: .ascii)?.trimmingCharacters(in: .whitespaces) ?? ""
    }

    // MARK: - Disk Info

    func getDiskInfo(data: Data) -> (title: String, entries: Int, bootOption: Int, sectors: Int) {
        guard data.count >= 512 else { return ("", 0, 0, 0) }

        let title = readDiskTitle(data: data)

        let numEntriesRaw = data[256 + 5]
        let numEntries = Int(numEntriesRaw) / 8

        let bootOption = Int(data[256 + 6]) & 0x03

        let sectorsHigh = (data[256 + 6] >> 4) & 0x03
        let sectorsLow = data[256 + 7]
        let totalSectors = (Int(sectorsHigh) << 8) | Int(sectorsLow)

        return (title, numEntries, bootOption, totalSectors)
    }
}
