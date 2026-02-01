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
    private let maxDirectoryEntries = 72  // 9 sectors * 8 entries per sector

    // MARK: - Types

    struct DirectoryEntry {
        let fileType: UInt8         // File type: 0=killed, 1=BASIC, 2=binary/data, 3=ML, 0xFF=unused
        let name: String            // 8 characters
        let ext: String             // 3 characters
        let asciiFlag: UInt8        // 0=binary, 0xFF=ASCII
        let firstGranule: UInt8     // First granule number
        let lastSectorBytes: Int    // Bytes used in last sector

        var isDeleted: Bool { fileType == 0x00 }
        var isUnused: Bool { fileType == 0xFF }
        var isValid: Bool { !isDeleted && !isUnused && firstGranule < 140 }  // Support larger disks

        var fullName: String {
            let trimmedName = name.trimmingCharacters(in: .whitespaces)
            let trimmedExt = ext.trimmingCharacters(in: .whitespaces)
            if trimmedExt.isEmpty {
                return trimmedName
            }
            return "\(trimmedName).\(trimmedExt)"
        }

        var fileTypeString: String {
            switch fileType {
            case 0: return "DEL"
            case 1: return "BAS"
            case 2: return "BIN"
            case 3: return "ML"
            default: return "???"
            }
        }
    }

    // MARK: - Detection

    /// Check if data appears to be a CoCo RS-DOS disk image
    func canRead(data: Data) -> Bool {
        // CoCo disks are typically:
        // 156KB single-sided (35 tracks * 18 sectors * 256 bytes = 161,280 bytes)
        // 312KB double-sided (same * 2 = 322,560 bytes)
        // Some emulators pad to 160KB or 180KB (up to 360KB)

        // Accept sizes within reasonable range for CoCo disks
        let minSize = 140000  // ~137KB minimum
        let maxSize = 380000  // ~370KB maximum
        guard data.count >= minSize && data.count <= maxSize else { return false }

        // Check for valid directory structure on track 17
        let dirOffset = getTrackOffset(track: directoryTrack)
        guard dirOffset + (sectorsPerTrack * bytesPerSector) <= data.count else { return false }

        // Read FAT sector and validate
        let fatOffset = dirOffset + (fatSector * bytesPerSector)
        guard fatOffset + 68 <= data.count else { return false }

        // Check if FAT has reasonable values
        // Each granule entry should be:
        // 0x00-0x8F: Next granule number (up to 143 for double-sided disks)
        // 0xC0-0xC9: Last granule marker (0-9 sectors used)
        // 0xFC: System use / unavailable (used by BitPast for directory track)
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

        // There should be some free granules (unless disk is completely full)
        // and not ALL granules free (that would indicate an unformatted disk)
        guard freeGranules > 0 && freeGranules < 68 else {
            // Allow fully used disks, but check directory
            let firstDirOffset = dirOffset + (directoryStartSector * bytesPerSector)
            guard firstDirOffset < data.count else { return false }

            // First directory entry should have valid status
            let firstStatus = data[firstDirOffset]
            if firstStatus != 0xFF && firstStatus <= 3 {
                return true  // Has at least one file
            }
            return false
        }

        // Check first directory entry for valid structure
        let firstDirOffset = dirOffset + (directoryStartSector * bytesPerSector)
        if firstDirOffset < data.count {
            let firstStatus = data[firstDirOffset]
            // First entry should be a file (0-3), deleted (0), or unused (0xFF)
            if firstStatus <= 3 || firstStatus == 0xFF {
                return true
            }
        }

        return validFATEntries >= 60
    }

    // MARK: - Reading

    /// Read all files from the CoCo disk image
    func readDisk(data: Data) -> [DiskCatalogEntry]? {
        // Calculate total tracks and granules based on disk size
        let totalTracks = data.count / (sectorsPerTrack * bytesPerSector)
        let granulesPerSide = 70  // 35 tracks × 2 granules per track (includes directory track 17)
        let isDoubleSided = totalTracks > 40
        let maxGranules = isDoubleSided ? granulesPerSide * 2 : granulesPerSide  // 140 or 70

        // Read FAT (full sector to support double-sided)
        let fatOffset = getTrackOffset(track: directoryTrack) + (fatSector * bytesPerSector)
        guard fatOffset + bytesPerSector <= data.count else { return nil }

        var fat = [UInt8](repeating: 0xFF, count: maxGranules)
        for i in 0..<min(maxGranules, bytesPerSector) {
            fat[i] = data[fatOffset + i]
        }

        // Read directory entries
        let entries = readDirectory(data: data)
        guard !entries.isEmpty else { return nil }

        // Build catalog entries
        var catalogEntries: [DiskCatalogEntry] = []

        for entry in entries {
            guard entry.isValid else { continue }

            // Extract file data
            if let fileData = extractFile(data: data, entry: entry, fat: fat) {
                let (isImage, imageType) = detectImageType(name: entry.fullName, data: fileData)

                let catalogEntry = DiskCatalogEntry(
                    name: entry.fullName,
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
                )
                catalogEntries.append(catalogEntry)
            }
        }

        return catalogEntries
    }

    // MARK: - Directory Reading

    private func readDirectory(data: Data) -> [DirectoryEntry] {
        var entries: [DirectoryEntry] = []
        let dirBaseOffset = getTrackOffset(track: directoryTrack)

        // Directory spans sectors 3-11 (9 sectors)
        for sector in directoryStartSector..<(directoryStartSector + 9) {
            let sectorOffset = dirBaseOffset + (sector * bytesPerSector)
            guard sectorOffset + bytesPerSector <= data.count else { break }

            // Each sector contains 8 directory entries (32 bytes each)
            for entryIndex in 0..<8 {
                let entryOffset = sectorOffset + (entryIndex * 32)
                guard entryOffset + 32 <= data.count else { break }

                // Byte 0 is file type: 0=killed, 1=BASIC, 2=binary, 3=ML, 0xFF=unused
                let fileType = data[entryOffset]

                // Stop at first unused entry
                if fileType == 0xFF {
                    // Check if this is truly the end
                    let nextOffset = entryOffset + 32
                    if nextOffset < data.count && data[nextOffset] == 0xFF {
                        return entries
                    }
                }

                // Skip deleted entries (type 0 with no first granule)
                if fileType == 0x00 && data[entryOffset + 13] == 0x00 {
                    continue
                }

                // Parse filename (bytes 1-8)
                var nameChars = [Character]()
                for i in 0..<8 {
                    let byte = data[entryOffset + 1 + i]
                    if byte >= 0x20 && byte < 0x7F {
                        nameChars.append(Character(UnicodeScalar(byte)))
                    }
                }
                let name = String(nameChars)

                // Parse extension (bytes 9-11)
                var extChars = [Character]()
                for i in 0..<3 {
                    let byte = data[entryOffset + 9 + i]
                    if byte >= 0x20 && byte < 0x7F {
                        extChars.append(Character(UnicodeScalar(byte)))
                    }
                }
                let ext = String(extChars)

                // Byte 12: ASCII flag (0=binary, 0xFF=ASCII)
                let asciiFlag = data[entryOffset + 12]
                // Byte 13: First granule number
                let firstGranule = data[entryOffset + 13]
                // Bytes 14-15: Bytes used in last sector (little-endian)
                let lastSectorBytes = Int(data[entryOffset + 14]) | (Int(data[entryOffset + 15]) << 8)

                let entry = DirectoryEntry(
                    fileType: fileType,
                    name: name,
                    ext: ext,
                    asciiFlag: asciiFlag,
                    firstGranule: firstGranule,
                    lastSectorBytes: lastSectorBytes
                )

                if entry.isValid {
                    entries.append(entry)
                }
            }
        }

        return entries
    }

    // MARK: - File Extraction

    private func extractFile(data: Data, entry: DirectoryEntry, fat: [UInt8]) -> Data? {
        var fileData = Data()
        var currentGranule = entry.firstGranule
        var granulesRead = 0
        let maxGranules = fat.count  // Support single and double-sided disks

        while granulesRead < maxGranules {
            guard Int(currentGranule) < fat.count else { break }

            let fatEntry = fat[Int(currentGranule)]

            // Calculate granule offset
            let granuleOffset = getGranuleOffset(granule: Int(currentGranule))
            guard granuleOffset >= 0 && granuleOffset < data.count else { break }

            // Determine how many sectors to read from this granule
            let sectorsToRead: Int
            let isLastGranule = fatEntry >= 0xC0 && fatEntry <= 0xC9

            if isLastGranule {
                // Last granule: low nibble indicates sectors used (0-9)
                sectorsToRead = Int(fatEntry & 0x0F)
                if sectorsToRead == 0 {
                    break  // No more data
                }
            } else {
                sectorsToRead = 9  // Full granule
            }

            // Read sectors from this granule
            for sector in 0..<sectorsToRead {
                let sectorOffset = granuleOffset + (sector * bytesPerSector)
                guard sectorOffset + bytesPerSector <= data.count else { break }

                let sectorData = data[sectorOffset..<sectorOffset + bytesPerSector]
                fileData.append(sectorData)
            }

            if isLastGranule {
                // Trim to exact size using lastSectorBytes
                if entry.lastSectorBytes > 0 && entry.lastSectorBytes <= bytesPerSector {
                    let fullSectorsBytes = (sectorsToRead - 1) * bytesPerSector
                    let totalBytes = fullSectorsBytes + entry.lastSectorBytes
                    let previousBytes = fileData.count - (sectorsToRead * bytesPerSector)
                    if previousBytes + totalBytes < fileData.count {
                        fileData = fileData.prefix(previousBytes + totalBytes)
                    }
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

    private func getTrackOffset(track: Int) -> Int {
        return track * sectorsPerTrack * bytesPerSector
    }

    private func getGranuleOffset(granule: Int) -> Int {
        // RS-DOS standard: granule N is on track N/2
        // Each track has 2 granules (9 sectors each = 2304 bytes per granule)
        // Track 17 (directory) has granules 34-35 (marked as system use in FAT)
        //
        // Double-sided disks: granules 0-69 on side 0, 70-139 on side 1
        // (70 granules per side = 35 tracks × 2 granules/track)

        let granulesPerSide = 70  // 35 tracks × 2 granules per track
        let side = granule / granulesPerSide
        let granuleWithinSide = granule % granulesPerSide

        // Simple calculation: track = granule / 2
        let track = granuleWithinSide / 2
        let granuleInTrack = granuleWithinSide % 2
        let sectorInTrack = granuleInTrack * 9

        // Side offset: side 1 starts after all 35 tracks of side 0
        let sideOffset = side * 35 * sectorsPerTrack * bytesPerSector

        return sideOffset + (track * sectorsPerTrack + sectorInTrack) * bytesPerSector
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
