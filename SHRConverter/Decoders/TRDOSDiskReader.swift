import Foundation
import AppKit

/// Reader for ZX Spectrum TR-DOS disk images (.trd files)
/// Supports Beta Disk Interface filesystem used on ZX Spectrum computers
class TRDOSDiskReader {

    // MARK: - Constants

    private let sectorSize = 256
    /// A .trd file is a plain run of logical tracks of 16 sectors each (a double-sided disk
    /// simply alternates sides). Some tools number sectors 0-31 per cylinder instead; which of
    /// the two a disk uses is detected from its directory.
    private let standardSectorsPerTrack = 16
    private let cylinderSectorsPerTrack = 32
    private let directoryTrack = 0
    private let directorySectors = 8  // Sectors 0-7 contain directory
    private let directoryEntrySize = 16

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

    // MARK: - Detection

    /// Check if data appears to be a TR-DOS disk image
    func canRead(data: Data) -> Bool {
        // A full disk is 163,840 to 819,200 bytes, but images are often cut off after the last
        // used track, so anything that holds the directory and the info sector is accepted.
        guard data.count >= 9 * sectorSize, data.count <= 860160, data.count % sectorSize == 0 else {
            return false
        }

        // Read disk info sector (track 0, sector 8)
        let infoOffset = 8 * sectorSize  // track 0, sector 8 - the same in both layouts
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
        let sectorsPerTrack = detectSectorsPerTrack(entries: entries)

        for entry in entries {
            guard !entry.isDeleted && !entry.isEndOfDirectory else { continue }
            guard entry.length > 0 else { continue }

            // Extract file data
            if let fileData = extractFile(data: data, entry: entry, sectorsPerTrack: sectorsPerTrack) {
                files.append((name: entry.fullName, data: fileData))
            }
        }

        return files.isEmpty ? nil : files
    }

    // MARK: - Sector Access

    /// TR-DOS stores files back to back, so in the right layout each file starts exactly where
    /// the previous one ends. Count how often that holds for 16 and for 32 sectors per track.
    private func detectSectorsPerTrack(entries: [DirectoryEntry]) -> Int {
        // A start sector above 15 can only exist in the 32-sector numbering
        if entries.contains(where: { $0.startSector >= UInt8(standardSectorsPerTrack) }) {
            return cylinderSectorsPerTrack
        }

        var fits16 = 0, fits32 = 0
        for (current, next) in zip(entries, entries.dropFirst()) {
            let sectors = Int(current.sectorCount)
            if Int(current.startTrack) * 16 + Int(current.startSector) + sectors == Int(next.startTrack) * 16 + Int(next.startSector) { fits16 += 1 }
            if Int(current.startTrack) * 32 + Int(current.startSector) + sectors == Int(next.startTrack) * 32 + Int(next.startSector) { fits32 += 1 }
        }
        return fits32 > fits16 ? cylinderSectorsPerTrack : standardSectorsPerTrack
    }

    /// Calculate byte offset for a given track and sector
    private func getSectorOffset(track: Int, sector: Int, sectorsPerTrack: Int) -> Int {
        return (track * sectorsPerTrack + sector) * sectorSize
    }

    /// Read a sector from the disk image
    private func readSector(data: Data, track: Int, sector: Int, sectorsPerTrack: Int) -> Data? {
        let offset = getSectorOffset(track: track, sector: sector, sectorsPerTrack: sectorsPerTrack)
        guard offset >= 0 && offset + sectorSize <= data.count else { return nil }
        return data.subdata(in: offset..<(offset + sectorSize))
    }

    // MARK: - Directory Parsing

    /// Parse the directory from track 0, sectors 0-7
    private func parseDirectory(data: Data) -> [DirectoryEntry]? {
        var entries: [DirectoryEntry] = []

        // Directory is in track 0, sectors 0-7 (8 sectors total)
        for sectorNum in 0..<directorySectors {
            guard let sectorData = readSector(data: data, track: 0, sector: sectorNum, sectorsPerTrack: standardSectorsPerTrack) else {
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
    private func extractFile(data: Data, entry: DirectoryEntry, sectorsPerTrack: Int) -> Data? {
        var fileData = Data()
        var currentTrack = Int(entry.startTrack)
        var currentSector = Int(entry.startSector)
        var bytesRemaining = Int(entry.length)
        var sectorsRead = 0
        let maxSectors = Int(entry.sectorCount)

        while bytesRemaining > 0 && sectorsRead < maxSectors {
            guard let sectorData = readSector(data: data, track: currentTrack, sector: currentSector, sectorsPerTrack: sectorsPerTrack) else {
                break
            }

            let bytesToRead = min(bytesRemaining, sectorSize)
            fileData.append(sectorData.prefix(bytesToRead))
            bytesRemaining -= bytesToRead
            sectorsRead += 1

            // Move to next sector
            currentSector += 1
            if currentSector >= sectorsPerTrack {
                currentSector = 0
                currentTrack += 1
            }
        }

        return fileData.isEmpty ? nil : fileData
    }
}
