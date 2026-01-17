#!/usr/bin/env swift

import Foundation

// Read the disk image
let diskPath = "/Users/wally/Downloads/random disk.dsk"
guard let diskData = try? Data(contentsOf: URL(fileURLWithPath: diskPath)) else {
    print("Error: Could not read disk image")
    exit(1)
}

func sectorOffset(track: Int, sector: Int) -> Int {
    return (track * 16 * 256) + (sector * 256)
}

func extractFile(track: Int, sector: Int) -> Data {
    var fileData = Data()
    var currentTrack = track
    var currentSector = sector
    var iterations = 0

    while currentTrack != 0 && iterations < 1000 {
        iterations += 1
        let offset = sectorOffset(track: currentTrack, sector: currentSector)

        let nextTrack = Int(diskData[offset + 1])
        let nextSector = Int(diskData[offset + 2])

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

// Test first file: PIC.DALLAS1 at track 3, sector 13
let catalogOffset = sectorOffset(track: 17, sector: 15)
let trackList = Int(diskData[catalogOffset + 11])
let sectorList = Int(diskData[catalogOffset + 12])

print("First file track/sector: \(trackList)/\(sectorList)")

let rawFileData = extractFile(track: trackList, sector: sectorList)
print("Raw file size: \(rawFileData.count) bytes")

if rawFileData.count > 4 {
    let loadAddr = Int(rawFileData[0]) | (Int(rawFileData[1]) << 8)
    let length = Int(rawFileData[2]) | (Int(rawFileData[3]) << 8)

    print("Load address: $\(String(format: "%04X", loadAddr))")
    print("Length: \(length)")
    print("Length check: \(length > 100 && length <= rawFileData.count - 4)")
    print("Load addr check: \(loadAddr >= 0x0800 && loadAddr <= 0xBFFF)")

    if length > 100 && length <= rawFileData.count - 4 && loadAddr >= 0x0800 && loadAddr <= 0xBFFF {
        let strippedData = rawFileData.subdata(in: 4..<(4 + length))
        print("Stripped data size: \(strippedData.count) bytes")
        print("Size in HGR range (8184-8200): \(strippedData.count >= 8184 && strippedData.count <= 8200)")
    }
}
