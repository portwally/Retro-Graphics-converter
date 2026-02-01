import Foundation
import AppKit

/// Reader for ZX Spectrum TR-DOS disk images (.trd files)
/// Supports Beta Disk Interface filesystem used on ZX Spectrum computers
class TRDOSDiskReader {

    // MARK: - Constants

    private let sectorSize = 256
    private let sectorsPerTrack = 16
    private let sectorsPerTrackDS = 32  // Double-sided: 16 sectors per side × 2 sides
    private let directoryTrack = 0
    private let directorySectors = 8  // Sectors 0-7 contain directory
    private let maxDirectoryEntries = 128
    private let directoryEntrySize = 16
    private let diskInfoSector = 8  // Track 0, sector 8 contains disk info

    // MARK: - Types

    struct DiskGeometry {
        let tracks: Int
        let sides: Int
        let totalSectors: Int

        var totalBytes: Int {
            totalSectors * 256
        }
    }

    struct DirectoryEntry {
        let filename: String       // 8 chars
        let extension_: String     // 1 char (B, C, D, #)
        let startAddress: UInt16   // For Code files
        let length: UInt16         // Length in bytes
        let sectorCount: UInt8     // Length in sectors
        let startSector: UInt8     // 1-16
        let startTrack: UInt8      // 0-159

        var isDeleted: Bool {
            filename.first == "\u{00}" || filename.first == "\u{01}"
        }

        var isEndOfDirectory: Bool {
            filename.first == "\u{00}"
        }

        var fullName: String {
            let trimmedName = filename.trimmingCharacters(in: .whitespaces)
                .trimmingCharacters(in: .controlCharacters)
            let trimmedExt = extension_.trimmingCharacters(in: .whitespaces)
            if trimmedExt.isEmpty || trimmedExt == " " {
                return trimmedName
            }
            return "\(trimmedName).\(trimmedExt)"
        }

        var fileTypeDescription: String {
            switch extension_ {
            case "B": return "BASIC"
            case "C": return "Code"
            case "D": return "Data"
            case "#": return "Sequential"
            default: return extension_
            }
        }
    }

    struct DiskInfo {
        let firstFreeSector: UInt8
        let firstFreeTrack: UInt8
        let diskType: UInt8
        let fileCount: UInt8
        let freeSectors: UInt16
        let trdosId: UInt8
        let diskLabel: String

        var isValid: Bool {
            trdosId == 0x10
        }

        var diskTypeDescription: String {
            switch diskType {
            case 0x16: return "80 track DS"
            case 0x17: return "40 track DS"
            case 0x18: return "80 track SS"
            case 0x19: return "40 track SS"
            default: return "Unknown (\(String(format: "0x%02X", diskType)))"
            }
        }
    }

    // MARK: - Detection

    /// Check if data appears to be a TR-DOS disk image
    func canRead(data: Data) -> Bool {
        // Common TR-DOS disk sizes
        let validSizes = [
            655360,   // 80 track DS (most common)
            327680,   // 40 track DS or 80 track SS
            163840,   // 40 track SS
            819200,   // Extended 80 track DS
            737280    // 80 track DS (alternative)
        ]

        // Check for reasonable size
        guard validSizes.contains(data.count) || (data.count >= 163840 && data.count <= 860160) else {
            return false
        }

        // Read disk info sector (track 0, sector 8)
        let infoOffset = getSectorOffset(track: 0, sector: 8)
        guard infoOffset + 256 <= data.count else { return false }

        // Check TR-DOS signature byte at offset 231 (0x10)
        let signatureByte = data[infoOffset + 231]
        guard signatureByte == 0x10 else { return false }

        // Additional validation: check disk type byte
        let diskType = data[infoOffset + 227]
        let validDiskTypes: [UInt8] = [0x16, 0x17, 0x18, 0x19]
        guard validDiskTypes.contains(diskType) else { return false }

        return true
    }

    // MARK: - Reading

    /// Read all files from a TR-DOS disk image
    func readDisk(data: Data) -> [(name: String, data: Data)]? {
        guard canRead(data: data) else { return nil }

        // Parse directory
        guard let entries = parseDirectory(data: data) else { return nil }

        var files: [(name: String, data: Data)] = []

        for entry in entries {
            guard !entry.isDeleted && !entry.isEndOfDirectory else { continue }
            guard entry.length > 0 else { continue }

            // Extract file data
            if let fileData = extractFile(data: data, entry: entry) {
                files.append((name: entry.fullName, data: fileData))
            }
        }

        return files.isEmpty ? nil : files
    }

    // MARK: - Sector Access

    /// Calculate byte offset for a given track and sector
    /// For double-sided disks: sector 0-15 = side 0, sector 16-31 = side 1
    /// Linear layout: track * 32 + sector (for DS disks)
    private func getSectorOffset(track: Int, sector: Int) -> Int {
        // Linear sector addressing for double-sided disks
        let logicalSector = track * sectorsPerTrackDS + sector
        return logicalSector * sectorSize
    }

    /// Read a sector from the disk image
    private func readSector(data: Data, track: Int, sector: Int) -> Data? {
        let offset = getSectorOffset(track: track, sector: sector)
        guard offset >= 0 && offset + sectorSize <= data.count else { return nil }
        return data.subdata(in: offset..<(offset + sectorSize))
    }

    // MARK: - Directory Parsing

    /// Parse disk info from track 0, sector 8
    private func parseDiskInfo(data: Data) -> DiskInfo? {
        let infoOffset = getSectorOffset(track: 0, sector: 8)
        guard infoOffset + 256 <= data.count else { return nil }

        let firstFreeSector = data[infoOffset + 225]
        let firstFreeTrack = data[infoOffset + 226]
        let diskType = data[infoOffset + 227]
        let fileCount = data[infoOffset + 228]
        let freeSectors = UInt16(data[infoOffset + 229]) | (UInt16(data[infoOffset + 230]) << 8)
        let trdosId = data[infoOffset + 231]

        // Read disk label (8 characters at offset 245)
        var labelBytes = [UInt8]()
        for i in 0..<8 {
            labelBytes.append(data[infoOffset + 245 + i])
        }
        let diskLabel = String(bytes: labelBytes, encoding: .ascii)?
            .trimmingCharacters(in: .whitespaces)
            .trimmingCharacters(in: .controlCharacters) ?? ""

        return DiskInfo(
            firstFreeSector: firstFreeSector,
            firstFreeTrack: firstFreeTrack,
            diskType: diskType,
            fileCount: fileCount,
            freeSectors: freeSectors,
            trdosId: trdosId,
            diskLabel: diskLabel
        )
    }

    /// Parse the directory from track 0, sectors 0-7
    private func parseDirectory(data: Data) -> [DirectoryEntry]? {
        var entries: [DirectoryEntry] = []

        // Directory is in track 0, sectors 0-7 (8 sectors total)
        for sectorNum in 0..<directorySectors {
            guard let sectorData = readSector(data: data, track: 0, sector: sectorNum) else {
                continue
            }

            // Each sector contains 16 directory entries (256 / 16 = 16)
            for entryIndex in 0..<16 {
                let entryOffset = entryIndex * directoryEntrySize

                // Read filename (8 bytes)
                var filenameBytes = [UInt8]()
                for i in 0..<8 {
                    filenameBytes.append(sectorData[entryOffset + i])
                }

                // Check for end of directory
                if filenameBytes[0] == 0x00 {
                    // End marker - stop processing
                    return entries
                }

                // Skip deleted entries (first byte = 0x01)
                if filenameBytes[0] == 0x01 {
                    continue
                }

                let filename = String(bytes: filenameBytes, encoding: .ascii)?
                    .trimmingCharacters(in: .controlCharacters) ?? ""

                // Extension type (1 byte)
                let extByte = sectorData[entryOffset + 8]
                let extension_ = String(bytes: [extByte], encoding: .ascii) ?? ""

                // Start address (2 bytes, little-endian)
                let startAddress = UInt16(sectorData[entryOffset + 9]) |
                                   (UInt16(sectorData[entryOffset + 10]) << 8)

                // Length in bytes (2 bytes, little-endian)
                let length = UInt16(sectorData[entryOffset + 11]) |
                             (UInt16(sectorData[entryOffset + 12]) << 8)

                // Length in sectors (1 byte)
                let sectorCount = sectorData[entryOffset + 13]

                // Starting sector (1 byte, 0-31 for double-sided)
                let startSector = sectorData[entryOffset + 14]

                // Starting track (1 byte)
                let startTrack = sectorData[entryOffset + 15]

                let entry = DirectoryEntry(
                    filename: filename,
                    extension_: extension_,
                    startAddress: startAddress,
                    length: length,
                    sectorCount: sectorCount,
                    startSector: startSector,
                    startTrack: startTrack
                )

                entries.append(entry)
            }
        }

        return entries
    }

    // MARK: - File Extraction

    /// Extract file data following the sector chain
    private func extractFile(data: Data, entry: DirectoryEntry) -> Data? {
        var fileData = Data()
        var currentTrack = Int(entry.startTrack)
        var currentSector = Int(entry.startSector)
        var bytesRemaining = Int(entry.length)
        var sectorsRead = 0
        let maxSectors = Int(entry.sectorCount)

        while bytesRemaining > 0 && sectorsRead < maxSectors {
            guard let sectorData = readSector(data: data, track: currentTrack, sector: currentSector) else {
                break
            }

            let bytesToRead = min(bytesRemaining, sectorSize)
            fileData.append(sectorData.prefix(bytesToRead))
            bytesRemaining -= bytesToRead
            sectorsRead += 1

            // Move to next sector (double-sided: 32 sectors per track)
            currentSector += 1
            if currentSector >= sectorsPerTrackDS {
                currentSector = 0
                currentTrack += 1
            }
        }

        return fileData.isEmpty ? nil : fileData
    }
}
