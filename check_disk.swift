#!/usr/bin/env swift

import Foundation

// Read the disk image
let diskPath = "/Users/wally/Downloads/random disk.dsk"
guard let diskData = try? Data(contentsOf: URL(fileURLWithPath: diskPath)) else {
    print("Error: Could not read disk image")
    exit(1)
}

print("Disk size: \(diskData.count) bytes")
print()

// Read VTOC (Track 17, Sector 0)
let vtocOffset = (17 * 16 * 256) + (0 * 256)
let catalogTrack = Int(diskData[vtocOffset + 1])
let catalogSector = Int(diskData[vtocOffset + 2])

print("VTOC at Track 17, Sector 0")
print("Catalog starts at Track \(catalogTrack), Sector \(catalogSector)")
print()

// Function to calculate sector offset
func sectorOffset(track: Int, sector: Int) -> Int {
    return (track * 16 * 256) + (sector * 256)
}

// Function to extract file from track/sector list
func extractFile(track: Int, sector: Int) -> Data {
    var fileData = Data()
    var currentTrack = track
    var currentSector = sector
    var iterations = 0

    while currentTrack != 0 && iterations < 1000 {
        iterations += 1
        let offset = sectorOffset(track: currentTrack, sector: currentSector)

        // Read next track/sector from T/S list
        let nextTrack = Int(diskData[offset + 1])
        let nextSector = Int(diskData[offset + 2])

        // Read data sectors from offset 12 onwards (pairs of track/sector)
        for i in stride(from: 12, to: 256, by: 2) {
            let dataTrack = Int(diskData[offset + i])
            let dataSector = Int(diskData[offset + i + 1])

            if dataTrack == 0 { break }

            let dataOffset = sectorOffset(track: dataTrack, sector: dataSector)
            fileData.append(diskData.subdata(in: dataOffset..<(dataOffset + 256)))
        }

        currentTrack = nextTrack
        currentSector = nextSector
    }

    return fileData
}

// Read catalog entries
var currentTrack = catalogTrack
var currentSector = catalogSector
var entryNum = 0

print("Files on disk:")
print(String(repeating: "=", count: 80))

while currentTrack != 0 {
    let catalogOffset = sectorOffset(track: currentTrack, sector: currentSector)

    // Next catalog sector
    let nextTrack = Int(diskData[catalogOffset + 1])
    let nextSector = Int(diskData[catalogOffset + 2])

    // Read 7 file entries per catalog sector
    for i in 0..<7 {
        let entryOffset = catalogOffset + 11 + (i * 35)
        let fileTrack = Int(diskData[entryOffset])

        if fileTrack != 0 && fileTrack != 255 {
            entryNum += 1

            let fileSector = Int(diskData[entryOffset + 1])
            let fileType = diskData[entryOffset + 2]
            let fileTypeLocked = (fileType & 0x80) != 0
            let fileTypeCode = fileType & 0x7F

            // Extract filename (30 bytes, high bit stripped)
            var filename = ""
            for j in 0..<30 {
                let byte = diskData[entryOffset + 3 + j]
                if byte & 0x7F == 0 { break }
                filename += String(Character(UnicodeScalar(byte & 0x7F)))
            }
            filename = filename.trimmingCharacters(in: .whitespaces)

            let sectorsUsed = Int(diskData[entryOffset + 33]) | (Int(diskData[entryOffset + 34]) << 8)

            // Extract file data
            let fileData = extractFile(track: fileTrack, sector: fileSector)

            // Check for binary header
            var actualData = fileData
            var loadAddr = 0
            var fileLength = fileData.count

            if fileData.count > 4 {
                loadAddr = Int(fileData[0]) | (Int(fileData[1]) << 8)
                let headerLength = Int(fileData[2]) | (Int(fileData[3]) << 8)

                if headerLength > 100 && headerLength <= fileData.count - 4 &&
                   loadAddr >= 0x0800 && loadAddr <= 0xBFFF {
                    actualData = fileData.subdata(in: 4..<(4 + headerLength))
                    fileLength = headerLength
                }
            }

            // Determine file type string
            var typeStr = ""
            switch fileTypeCode {
            case 0x00: typeStr = "T"  // Text
            case 0x01: typeStr = "I"  // Integer BASIC
            case 0x02: typeStr = "A"  // Applesoft BASIC
            case 0x04: typeStr = "B"  // Binary
            case 0x08: typeStr = "S"  // S type
            case 0x10: typeStr = "R"  // Relocatable
            case 0x20: typeStr = "a"  // a type
            case 0x40: typeStr = "b"  // b type
            default: typeStr = "?"
            }
            if fileTypeLocked { typeStr = "*" + typeStr }

            // Check if it could be HGR
            let couldBeHGR = (fileTypeCode == 0x04 || fileTypeCode == 0x00) && (
                actualData.count == 8192 ||
                (actualData.count >= 8180 && actualData.count <= 8200) ||
                (loadAddr == 0x2000 && actualData.count >= 8180)
            )

            print("\(entryNum). \(filename)")
            print("   Type: \(typeStr) (\(String(format: "0x%02X", fileTypeCode)))  Sectors: \(sectorsUsed)  Size: \(fileData.count) bytes")
            if loadAddr != 0 {
                print("   Load Address: $\(String(format: "%04X", loadAddr))  Data Size: \(fileLength) bytes")
            }
            if couldBeHGR {
                print("   *** LIKELY HGR PICTURE ***")
                print("   Reason: Size=\(actualData.count), LoadAddr=$\(String(format: "%04X", loadAddr))")
            }
            print()
        }
    }

    currentTrack = nextTrack
    currentSector = nextSector

    if currentTrack == 0 { break }
}

print(String(repeating: "=", count: 80))
print("Total files: \(entryNum)")
