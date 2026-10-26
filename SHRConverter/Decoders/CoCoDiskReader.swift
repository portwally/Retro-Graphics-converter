import Foundation
import AppKit

/// Reader for TRS-80 CoCo disk images (.dsk files with RS-DOS filesystem)
/// Supports 156KB (35 tracks SS) and 312KB (35 tracks DS) disk images
class CoCoDiskReader {

    // MARK: - Constants

    private let bytesPerSector = 256
    private let sectorsPerTrack = 18
    private let bytesPerGranule = 2304  // 9 sectors * 256 bytes
    private let directoryTrack = 17
    private let directoryStartSector = 2  // Sectors 2-10 contain directory (0-indexed)
    private let fatSector = 1  // Sector 1 contains FAT (0-indexed)

    // MARK: - Types

    /// How the files on a volume are recorded.
    /// - standard: RS-DOS as written by Disk BASIC (and BitPast since its RS-DOS fix): name in
    ///   bytes 0-7, extension 8-10, type 11, last-sector byte count big-endian; granules 34-67
    ///   skip the directory track.
    /// - legacyBitPast: disks from BitPast versions before that fix, recognised by granules 34
    ///   and 35 marked $FC: entries shifted by one byte and granules numbered straight through.
    enum Layout {
        case standard
        case legacyBitPast
    }

    struct DirectoryEntry {
        let fileType: UInt8         // standard: 0 BASIC, 1 data, 2 machine language, 3 text
        let name: String            // 8 characters
        let ext: String             // 3 characters
        let asciiFlag: UInt8        // 0=binary, 0xFF=ASCII
        let firstGranule: UInt8     // First granule number
        let lastSectorBytes: Int    // Bytes used in last sector
        let layout: Layout

        var fullName: String {
            let trimmedName = name.trimmingCharacters(in: .whitespaces)
            let trimmedExt = ext.trimmingCharacters(in: .whitespaces)
            if trimmedExt.isEmpty {
                return trimmedName
            }
            return "\(trimmedName).\(trimmedExt)"
        }

        var fileTypeString: String {
            switch layout {
            case .standard:
                switch fileType {
                case 0: return "BAS"
                case 1: return "DAT"
                case 2: return "BIN"
                case 3: return "TXT"
                default: return "???"
                }
            case .legacyBitPast:
                switch fileType {
                case 1: return "BAS"
                case 2: return "BIN"
                case 3: return "ML"
                default: return "???"
                }
            }
        }
    }

    /// One RS-DOS volume: a single-sided disk, or one side of a double-sided one
    private struct Volume {
        let data: Data
        /// Byte offset of a sector (0-based within the track)
        let sectorOffset: (_ track: Int, _ sector: Int) -> Int
        /// Old BitPast double-sided disks put side 1 after side 0 and number its granules 70-139
        var granuleCount = 68
    }

    // MARK: - Detection

    /// Check if data appears to be a CoCo RS-DOS disk image
    func canRead(data: Data) -> Bool {
        // CoCo disks are typically:
        // 156KB single-sided (35 tracks * 18 sectors * 256 bytes = 161,280 bytes)
        // 312KB double-sided (same * 2 = 322,560 bytes)
        // Some emulators pad to 160KB or 180KB (up to 360KB)

        // Accept sizes within reasonable range for CoCo disks
        // The smallest RS-DOS disk is 35 tracks x 18 sectors x 256 bytes = 161,280 bytes.
        // (A lower limit lets 143,360-byte Apple II disks through to the FAT heuristics below.)
        let minSize = 161280
        let maxSize = 380000  // ~370KB maximum
        guard data.count >= minSize && data.count <= maxSize else { return false }

        let volume = volumes(of: data)[0]

        // Read FAT sector and validate
        let fatOffset = volume.sectorOffset(directoryTrack, fatSector)
        guard fatOffset + 68 <= data.count else { return false }

        // Check if FAT has reasonable values
        // Each granule entry should be:
        // 0x00-0x8F: Next granule number (up to 143 for double-sided disks)
        // 0xC0-0xC9: Last granule marker (0-9 sectors used)
        // 0xFC: System use / unavailable (old BitPast disks, directory track)
        // 0xFF: Free granule
        var validFATEntries = 0
        var freeGranules = 0
        for i in 0..<68 {
            let entry = data[fatOffset + i]
            if entry <= 0x8F || (entry >= 0xC0 && entry <= 0xC9) || entry == 0xFC || entry == 0xFF {
                validFATEntries += 1
            }
            if entry == 0xFF {
                freeGranules += 1
            }
        }

        // At least 90% of FAT entries should be valid
        guard validFATEntries >= 60 else { return false }

        // An unformatted (all free) or fully used disk must at least start with a real entry
        let firstEntry = volume.sectorOffset(directoryTrack, directoryStartSector)
        guard firstEntry < data.count else { return false }
        if freeGranules == 0 || freeGranules == 68 {
            return !readDirectory(volume: volume, layout: layout(fat: readFAT(volume: volume))).isEmpty
        }
        return true
    }

    // MARK: - Volumes

    /// Splits an image into its RS-DOS volumes. Double-sided images (with or without the 2-byte
    /// JVC header) interleave the sides track by track, and each side is its own volume.
    private func volumes(of data: Data) -> [Volume] {
        let trackBytes = sectorsPerTrack * bytesPerSector
        let singleSided = 35 * trackBytes
        let headerSize = data.count % trackBytes == 2 ? 2 : 0   // JVC header: sectors per track, sides
        let sides = headerSize == 2 && data[1] == 2 ? 2 : (data.count - headerSize >= 2 * singleSided ? 2 : 1)

        let plain = Volume(data: data) { track, sector in headerSize + (track * self.sectorsPerTrack + sector) * self.bytesPerSector }
        guard sides == 2 else { return [plain] }

        // Old BitPast double-sided disks: side 1 follows side 0, one FAT for both sides
        if headerSize == 0, layout(fat: readFAT(volume: plain)) == .legacyBitPast {
            var legacy = plain
            legacy.granuleCount = 140
            return [legacy]
        }

        return (0..<2).map { side in
            Volume(data: data) { track, sector in
                headerSize + ((track * 2 + side) * self.sectorsPerTrack + sector) * self.bytesPerSector
            }
        }
    }

    private func readFAT(volume: Volume) -> [UInt8] {
        let fatOffset = volume.sectorOffset(directoryTrack, fatSector)
        var fat = [UInt8](repeating: 0xFF, count: volume.granuleCount)
        for i in 0..<min(volume.granuleCount, bytesPerSector) where fatOffset + i < volume.data.count {
            fat[i] = volume.data[fatOffset + i]
        }
        return fat
    }

    /// Old BitPast marked the two directory-track granules (34 and 35) as $FC; RS-DOS never uses $FC
    private func layout(fat: [UInt8]) -> Layout {
        fat.count > 35 && fat[34] == 0xFC && fat[35] == 0xFC ? .legacyBitPast : .standard
    }

    // MARK: - Reading

    /// Read all files from the CoCo disk image
    func readDisk(data: Data) -> [DiskCatalogEntry]? {
        let allVolumes = volumes(of: data)
        var catalogEntries: [DiskCatalogEntry] = []

        for (side, volume) in allVolumes.enumerated() {
            let fat = readFAT(volume: volume)
            let layout = layout(fat: fat)
            // Files on the second side get a folder-like prefix (each side is its own volume)
            let prefix = allVolumes.count > 1 && side > 0 ? "Side \(side + 1)/" : ""

            for entry in readDirectory(volume: volume, layout: layout) {
                guard let fileData = extractFile(volume: volume, entry: entry, fat: fat, layout: layout) else { continue }
                let (isImage, imageType) = detectImageType(name: entry.fullName, data: fileData)

                catalogEntries.append(DiskCatalogEntry(
                    name: prefix + entry.fullName,
                    fileType: UInt8(entry.fileType),
                    fileTypeString: entry.fileTypeString,
                    size: fileData.count,
                    blocks: (fileData.count + bytesPerGranule - 1) / bytesPerGranule,
                    loadAddress: nil,
                    length: nil,
                    data: fileData,
                    isImage: isImage,
                    imageType: imageType,
                    isDirectory: false,
                    children: nil
                ))
            }
        }

        return catalogEntries.isEmpty ? nil : catalogEntries
    }

    // MARK: - Directory Reading

    private func readDirectory(volume: Volume, layout: Layout) -> [DirectoryEntry] {
        let data = volume.data
        var entries: [DirectoryEntry] = []

        // Directory spans sectors 3-11 (9 sectors), 8 entries of 32 bytes each
        for sector in directoryStartSector..<(directoryStartSector + 9) {
            let sectorOffset = volume.sectorOffset(directoryTrack, sector)
            guard sectorOffset + bytesPerSector <= data.count else { break }

            for entryIndex in 0..<8 {
                let e = sectorOffset + (entryIndex * 32)

                // Where the name starts, and what marks an unused or killed entry
                let nameOffset = layout == .standard ? 0 : 1
                let marker = data[e]
                if marker == 0xFF { return entries }  // end of the directory
                if marker == 0x00 && (layout == .standard || data[e + 13] == 0x00) { continue }  // killed

                func text(_ offset: Int, _ count: Int) -> String {
                    String((0..<count).compactMap { i -> Character? in
                        let byte = data[e + offset + i]
                        return byte >= 0x20 && byte < 0x7F ? Character(UnicodeScalar(byte)) : nil
                    })
                }

                let entry: DirectoryEntry
                switch layout {
                case .standard:
                    entry = DirectoryEntry(
                        fileType: data[e + 11], name: text(nameOffset, 8), ext: text(8, 3),
                        asciiFlag: data[e + 12], firstGranule: data[e + 13],
                        lastSectorBytes: Int(data[e + 14]) << 8 | Int(data[e + 15]), layout: layout)
                case .legacyBitPast:
                    entry = DirectoryEntry(
                        fileType: marker, name: text(nameOffset, 8), ext: text(9, 3),
                        asciiFlag: data[e + 12], firstGranule: data[e + 13],
                        lastSectorBytes: Int(data[e + 14]) | Int(data[e + 15]) << 8, layout: layout)
                }

                if Int(entry.firstGranule) < volume.granuleCount && !entry.fullName.isEmpty {
                    entries.append(entry)
                }
            }
        }

        return entries
    }

    // MARK: - File Extraction

    private func extractFile(volume: Volume, entry: DirectoryEntry, fat: [UInt8], layout: Layout) -> Data? {
        let data = volume.data
        var fileData = Data()
        var currentGranule = entry.firstGranule
        var granulesRead = 0

        while granulesRead < fat.count {
            guard Int(currentGranule) < fat.count else { break }

            let fatEntry = fat[Int(currentGranule)]
            let granuleOffset = granuleOffset(granule: Int(currentGranule), volume: volume, layout: layout)
            guard granuleOffset >= 0 && granuleOffset < data.count else { break }

            // The last granule's entry is $C0 + the number of sectors used (0-9)
            let isLastGranule = fatEntry >= 0xC0 && fatEntry <= 0xC9
            let sectorsToRead = isLastGranule ? Int(fatEntry & 0x0F) : 9
            if isLastGranule && sectorsToRead == 0 { break }

            for sector in 0..<sectorsToRead {
                let sectorOffset = granuleOffset + (sector * bytesPerSector)
                guard sectorOffset + bytesPerSector <= data.count else { break }
                fileData.append(data[sectorOffset..<sectorOffset + bytesPerSector])
            }

            if isLastGranule {
                // Trim the last sector to the byte count from the directory
                if entry.lastSectorBytes > 0 && entry.lastSectorBytes < bytesPerSector {
                    fileData = fileData.prefix(fileData.count - bytesPerSector + entry.lastSectorBytes)
                }
                break
            }

            // Follow FAT chain
            currentGranule = fatEntry
            granulesRead += 1
        }

        return fileData.isEmpty ? nil : fileData
    }

    // MARK: - Offset Calculations

    private func granuleOffset(granule: Int, volume: Volume, layout: Layout) -> Int {
        // Each track holds two granules of 9 sectors
        switch layout {
        case .standard:
            // Granules 0-33 are tracks 0-16; granules 34-67 skip the directory track (17)
            let track = granule / 2 + (granule >= 34 ? 1 : 0)
            return volume.sectorOffset(track, (granule % 2) * 9)
        case .legacyBitPast:
            // Old BitPast: granule n on track n/2; on double-sided disks granules 70-139 are side 1,
            // stored after the 35 tracks of side 0
            let side = granule / 70
            let withinSide = granule % 70
            return volume.sectorOffset(side * 35 + withinSide / 2, (withinSide % 2) * 9)
        }
    }

    // MARK: - Image Type Detection

    private func detectImageType(name: String, data: Data) -> (isImage: Bool, imageType: AppleIIImageType) {
        let ext = (name as NSString).pathExtension.lowercased()

        // Check for CoCo graphics by extension
        switch ext {
        case "bin", "pix", "pic", "max":
            // Check for common CoCo graphics sizes
            if data.count == 6144 {
                // PMODE 3 or PMODE 4
                return (true, .TRS80(model: "CoCo", resolution: "256x192"))
            } else if data.count == 3072 {
                // PMODE 0/1
                return (true, .TRS80(model: "CoCo", resolution: "128x96"))
            } else if data.count >= 32000 && data.count <= 32768 {
                // CoCo 3 320x200 or 640x200 - detect mode
                if data.count == 32000 && detectCoCo3_640Mode(data: data) {
                    return (true, .TRS80(model: "CoCo 3", resolution: "640x200, 4 colors"))
                }
                return (true, .TRS80(model: "CoCo 3", resolution: "320x200, 16 colors"))
            }

        case "cm3", "pi3", "mg3":
            // CoCo 3 graphics - various sizes depending on mode
            // 320x200 16-color: ~32000 bytes
            // 640x200 4-color: 32000 bytes
            // 320x192/199: ~30720-31744 bytes
            if data.count >= 24000 {
                if data.count == 32000 && detectCoCo3_640Mode(data: data) {
                    return (true, .TRS80(model: "CoCo 3", resolution: "640x200, 4 colors"))
                }
                return (true, .TRS80(model: "CoCo 3", resolution: "320x200, 16 colors"))
            }

        default:
            break
        }

        // Check by content/size
        if data.count == 6144 {
            return (true, .TRS80(model: "CoCo", resolution: "256x192"))
        } else if data.count == 6145 || data.count == 6149 {
            // 6144 + header byte(s)
            return (true, .TRS80(model: "CoCo", resolution: "256x192"))
        } else if data.count >= 24000 && data.count <= 33000 {
            // CoCo 3 modes - detect 640x200 vs 320x200
            if data.count == 32000 && detectCoCo3_640Mode(data: data) {
                return (true, .TRS80(model: "CoCo 3", resolution: "640x200, 4 colors"))
            }
            return (true, .TRS80(model: "CoCo 3", resolution: "320x200, 16 colors"))
        }

        // Check for ML binary with header (5 byte header: 0x00, length-2, load addr-2)
        if data.count >= 5 && data[0] == 0x00 {
            let length = Int(data[1]) | (Int(data[2]) << 8)
            if length == data.count - 5 {
                // Valid ML header, check if payload is graphics size
                if length == 6144 {
                    return (true, .TRS80(model: "CoCo", resolution: "256x192"))
                } else if length >= 32000 && length <= 32768 {
                    return (true, .TRS80(model: "CoCo 3", resolution: "320x200, 16 colors"))
                }
            }
        }

        return (false, .Unknown)
    }

    /// Detect if CoCo 3 32000-byte file is 640x200 4-color or 320x200 16-color
    /// Uses heuristics based on nibble patterns and distribution analysis
    private func detectCoCo3_640Mode(data: Data) -> Bool {
        // In 640x200 4-color mode (2bpp), each byte = 4 pixels with values 0-3
        // When read as 4bpp nibbles:
        //   high nibble = pixel0 * 4 + pixel1
        //   low nibble = pixel2 * 4 + pixel3

        let sampleSize = min(data.count, 32000)
        var nibbleHistogram = [Int](repeating: 0, count: 16)

        for i in 0..<sampleSize {
            let byte = data[i]
            let highNibble = Int((byte >> 4) & 0x0F)
            let lowNibble = Int(byte & 0x0F)
            nibbleHistogram[highNibble] += 1
            nibbleHistogram[lowNibble] += 1
        }

        let totalNibbles = sampleSize * 2

        // Heuristic 1: Check uniformity of nibble distribution (chi-squared test)
        let expectedPerNibble = Double(totalNibbles) / 16.0
        var chiSquared = 0.0
        for count in nibbleHistogram {
            let diff = Double(count) - expectedPerNibble
            chiSquared += (diff * diff) / expectedPerNibble
        }
        let isUniform = chiSquared < 8000

        // Heuristic 2: Count significantly used nibble values
        let threshold = totalNibbles / 100
        var significantNibbles = 0
        for count in nibbleHistogram {
            if count > threshold {
                significantNibbles += 1
            }
        }
        let hasWideDistribution = significantNibbles >= 12

        // Heuristic 3: Check diagonal nibbles (solid color pairs: 0,5,10,15)
        let diagonalNibbles = nibbleHistogram[0] + nibbleHistogram[5] + nibbleHistogram[10] + nibbleHistogram[15]
        let diagonalRatio = Double(diagonalNibbles) / Double(totalNibbles)
        let hasDiagonalPresence = diagonalRatio > 0.15

        // Heuristic 4: Check 2-bit value distribution (at least 3 of 4 values used)
        var twoBitHistogram = [Int](repeating: 0, count: 4)
        for i in 0..<sampleSize {
            let byte = data[i]
            twoBitHistogram[Int((byte >> 6) & 0x03)] += 1
            twoBitHistogram[Int((byte >> 4) & 0x03)] += 1
            twoBitHistogram[Int((byte >> 2) & 0x03)] += 1
            twoBitHistogram[Int(byte & 0x03)] += 1
        }
        let totalTwoBit = sampleSize * 4
        let twoBitThreshold = totalTwoBit / 50
        var significantTwoBitValues = 0
        for count in twoBitHistogram {
            if count > twoBitThreshold {
                significantTwoBitValues += 1
            }
        }
        let hasReasonableTwoBit = significantTwoBitValues >= 3

        // Heuristic 5: Row-to-row correlation (real images have similar adjacent rows)
        var rowCorrelation = 0
        let bytesPerRow = 160
        let rowsToCheck = min(100, sampleSize / bytesPerRow - 1)
        for row in 0..<rowsToCheck {
            for col in 0..<bytesPerRow {
                let offset1 = row * bytesPerRow + col
                let offset2 = (row + 1) * bytesPerRow + col
                if offset2 < data.count {
                    let diff = abs(Int(data[offset1]) - Int(data[offset2]))
                    if diff < 64 {
                        rowCorrelation += 1
                    }
                }
            }
        }
        let totalRowChecks = rowsToCheck * bytesPerRow
        let rowCorrelationRatio = totalRowChecks > 0 ? Double(rowCorrelation) / Double(totalRowChecks) : 0
        let hasRowCorrelation = rowCorrelationRatio > 0.30

        // Score-based decision (lowered threshold)
        var score = 0
        if isUniform { score += 2 }
        if hasWideDistribution { score += 2 }
        if hasDiagonalPresence { score += 1 }
        if hasReasonableTwoBit { score += 2 }
        if hasRowCorrelation { score += 1 }

        return score >= 3
    }
}
