import Foundation
import AppKit

// MARK: - Disk Image Reader

class DiskImageReader {
    
    static func readDiskImage(data: Data) -> [DiskImageFile] {
        var files: [DiskImageFile] = []
        
        if let twoImgFiles = read2IMG(data: data) {
            files.append(contentsOf: twoImgFiles)
        }
        else if let proDOSFiles = readProDOSDSK(data: data) {
            files.append(contentsOf: proDOSFiles)
        }
        else if let dos33Files = readDOS33DSK(data: data) {
            files.append(contentsOf: dos33Files)
        }
        else if let hdvFiles = readHDV(data: data) {
            files.append(contentsOf: hdvFiles)
        }
        
        return files
    }
    
    // MARK: - 2IMG Format
    
    static func read2IMG(data: Data) -> [DiskImageFile]? {
        guard data.count >= 64 else {
            return nil
        }
        
        let signature = String(data: data.subdata(in: 0..<4), encoding: .ascii)
        guard signature == "2IMG" else {
            return nil
        }
        
        let imageFormat = data[12]
        
        let dataOffset = Int(data[24]) | (Int(data[25]) << 8) | (Int(data[26]) << 16) | (Int(data[27]) << 24)
        let dataLength = Int(data[28]) | (Int(data[29]) << 8) | (Int(data[30]) << 16) | (Int(data[31]) << 24)
        
        let actualDataLength: Int
        if dataLength == 0 {
            actualDataLength = data.count - dataOffset
        } else {
            actualDataLength = min(dataLength, data.count - dataOffset)
        }
        
        guard dataOffset < data.count else {
            return nil
        }
        
        let endOffset = min(dataOffset + actualDataLength, data.count)
        let diskData = data.subdata(in: dataOffset..<endOffset)
        
        if imageFormat == 0 {
            return readDOS33DSK(data: diskData)
        } else if imageFormat == 1 {
            return readProDOSDSK(data: diskData)
        }
        
        return nil
    }
    
    // MARK: - ProDOS DSK Format
    
    static func readProDOSDSK(data: Data) -> [DiskImageFile]? {
        let blockSize = 512
        
        guard data.count >= blockSize * 2 else {
            return nil
        }
        
        let volumeDirBlock = 2
        let volumeDirOffset = volumeDirBlock * blockSize
        
        guard volumeDirOffset + blockSize <= data.count else {
            return nil
        }
        
        let storageType = (data[volumeDirOffset + 4] & 0xF0) >> 4
        guard storageType == 0x0F else {
            return nil
        }
        
        var files: [DiskImageFile] = []
        
        let entriesPerBlock = 13
        var currentBlock = volumeDirBlock
        
        for _ in 0..<10 {
            let blockOffset = currentBlock * blockSize
            guard blockOffset + blockSize <= data.count else { break }
            
            let startEntry = (currentBlock == volumeDirBlock) ? 1 : 0
            
            for entryIdx in startEntry..<entriesPerBlock {
                let entryOffset = blockOffset + 4 + (entryIdx * 39)
                guard entryOffset + 39 <= data.count else { continue }
                
                let entryStorageType = (data[entryOffset] & 0xF0) >> 4
                guard entryStorageType > 0 else { continue }
                
                let nameLength = Int(data[entryOffset] & 0x0F)
                guard nameLength > 0 && nameLength <= 15 else { continue }
                
                let fileName = String(data: data.subdata(in: (entryOffset + 1)..<(entryOffset + 1 + nameLength)), encoding: .ascii) ?? ""
                
                let fileType = data[entryOffset + 16]
                let keyBlock = Int(data[entryOffset + 17]) | (Int(data[entryOffset + 18]) << 8)
                let blocksUsed = Int(data[entryOffset + 19]) | (Int(data[entryOffset + 20]) << 8)
                let eof = Int(data[entryOffset + 21]) | (Int(data[entryOffset + 22]) << 8) | (Int(data[entryOffset + 23]) << 16)
                
                // Read auxType from offset +31 (ProDOS spec)
                let auxType = Int(data[entryOffset + 31]) | (Int(data[entryOffset + 32]) << 8)
                
                if fileType == 0xC0 || fileType == 0xC1 || fileType == 0x08 || fileType == 0x06 {
                    if let fileData = extractProDOSFile(data: data, keyBlock: keyBlock, blocksUsed: blocksUsed, eof: eof, storageType: Int(entryStorageType)) {
                        // Encode ProDOS file type info in filename for decoder detection
                        let fileNameWithType = String(format: "%@#%02x%04x", fileName, fileType, auxType)
                        let result = SHRDecoder.decode(data: fileData, filename: fileNameWithType)
                        if result.type != AppleIIImageType.Unknown, let _ = result.image {
                            files.append(DiskImageFile(name: fileName, data: fileData, type: result.type))
                        }
                    }
                }
            }
            
            let nextBlock = Int(data[blockOffset + 2]) | (Int(data[blockOffset + 3]) << 8)
            if nextBlock == 0 { break }
            currentBlock = nextBlock
        }
        
        return files.isEmpty ? nil : files
    }
    
    static func extractProDOSFile(data: Data, keyBlock: Int, blocksUsed: Int, eof: Int, storageType: Int) -> Data? {
        let blockSize = 512
        var fileData = Data()
        
        if storageType == 1 {
            let offset = keyBlock * blockSize
            guard offset + blockSize <= data.count else { return nil }
            fileData = data.subdata(in: offset..<min(offset + eof, offset + blockSize))
        } else if storageType == 2 {
            let indexOffset = keyBlock * blockSize
            guard indexOffset + blockSize <= data.count else { return nil }
            
            for i in 0..<256 {
                let blockNum = Int(data[indexOffset + i]) | (Int(data[indexOffset + i + 256]) << 8)
                if blockNum == 0 { break }
                
                let blockOffset = blockNum * blockSize
                guard blockOffset + blockSize <= data.count else { continue }
                
                let bytesToRead = min(blockSize, eof - fileData.count)
                if bytesToRead > 0 {
                    fileData.append(data.subdata(in: blockOffset..<(blockOffset + bytesToRead)))
                }
                
                if fileData.count >= eof { break }
            }
        } else if storageType == 3 {
            let masterIndexOffset = keyBlock * blockSize
            guard masterIndexOffset + blockSize <= data.count else { return nil }
            
            for masterIdx in 0..<256 {
                let indexBlockNum = Int(data[masterIndexOffset + masterIdx]) | (Int(data[masterIndexOffset + masterIdx + 256]) << 8)
                if indexBlockNum == 0 { break }
                
                let indexOffset = indexBlockNum * blockSize
                guard indexOffset + blockSize <= data.count else { continue }
                
                for i in 0..<256 {
                    let blockNum = Int(data[indexOffset + i]) | (Int(data[indexOffset + i + 256]) << 8)
                    if blockNum == 0 { break }
                    
                    let blockOffset = blockNum * blockSize
                    guard blockOffset + blockSize <= data.count else { continue }
                    
                    let bytesToRead = min(blockSize, eof - fileData.count)
                    if bytesToRead > 0 {
                        fileData.append(data.subdata(in: blockOffset..<(blockOffset + bytesToRead)))
                    }
                    
                    if fileData.count >= eof { break }
                }
                
                if fileData.count >= eof { break }
            }
        }
        
        return fileData.isEmpty ? nil : fileData
    }
    
    // MARK: - DOS 3.3 DSK Format
    
    static func readDOS33DSK(data: Data) -> [DiskImageFile]? {
        let sectorSize = 256
        let sectorsPerTrack = 16
        let tracks = 35
        
        guard data.count >= sectorSize * sectorsPerTrack * tracks else {
            return nil
        }
        
        let vtocTrack = 17
        let vtocSector = 0
        let vtocOffset = (vtocTrack * sectorsPerTrack + vtocSector) * sectorSize
        
        guard vtocOffset + sectorSize <= data.count else {
            return nil
        }
        
        let catalogTrack = Int(data[vtocOffset + 1])
        guard catalogTrack == 17 else {
            return nil
        }
        
        var files: [DiskImageFile] = []
        
        var currentTrack = 17
        var currentSector = 15
        
        for _ in 0..<100 {
            let catalogOffset = (currentTrack * sectorsPerTrack + currentSector) * sectorSize
            guard catalogOffset + sectorSize <= data.count else { break }
            
            for entryIdx in 0..<7 {
                let entryOffset = catalogOffset + 11 + (entryIdx * 35)
                guard entryOffset + 35 <= data.count else { continue }
                
                let trackList = Int(data[entryOffset])
                let sectorList = Int(data[entryOffset + 1])
                
                if trackList == 0 || trackList == 0xFF { continue }
                
                var fileName = ""
                for i in 0..<30 {
                    let char = data[entryOffset + 3 + i] & 0x7F
                    if char == 0 || char == 0x20 { break }
                    if char > 0 {
                        fileName.append(Character(UnicodeScalar(char)))
                    }
                }
                fileName = fileName.trimmingCharacters(in: .whitespaces)
                
                let fileType = data[entryOffset + 2] & 0x7F
                
                if fileType == 0x42 || fileType == 0x49 || fileType == 0x41 || fileType == 0x04 {
                    if let fileData = extractDOS33File(data: data, trackList: trackList, sectorList: sectorList, sectorsPerTrack: sectorsPerTrack, sectorSize: sectorSize) {
                        let result = SHRDecoder.decode(data: fileData, filename: fileName)
                        if result.type != AppleIIImageType.Unknown, let _ = result.image {
                            files.append(DiskImageFile(name: fileName, data: fileData, type: result.type))
                        }
                    }
                }
            }
            
            let nextTrack = Int(data[catalogOffset + 1])
            let nextSector = Int(data[catalogOffset + 2])
            
            if nextTrack == 0 { break }
            currentTrack = nextTrack
            currentSector = nextSector
        }
        
        return files.isEmpty ? nil : files
    }
    
    static func extractDOS33File(data: Data, trackList: Int, sectorList: Int, sectorsPerTrack: Int, sectorSize: Int) -> Data? {
        var fileData = Data()
        var currentTrack = trackList
        var currentSector = sectorList
        
        for _ in 0..<1000 {
            let tsListOffset = (currentTrack * sectorsPerTrack + currentSector) * sectorSize
            guard tsListOffset + sectorSize <= data.count else { break }
            
            for pairIdx in 0..<122 {
                let track = Int(data[tsListOffset + 12 + (pairIdx * 2)])
                let sector = Int(data[tsListOffset + 12 + (pairIdx * 2) + 1])
                
                if track == 0 { break }
                
                let dataOffset = (track * sectorsPerTrack + sector) * sectorSize
                guard dataOffset + sectorSize <= data.count else { continue }
                
                fileData.append(data.subdata(in: dataOffset..<(dataOffset + sectorSize)))
            }
            
            let nextTrack = Int(data[tsListOffset + 1])
            let nextSector = Int(data[tsListOffset + 2])
            
            if nextTrack == 0 { break }
            currentTrack = nextTrack
            currentSector = nextSector
        }
        
        // Strip DOS 3.3 binary header (4 bytes: load address + length)
        if fileData.count > 4 {
            let loadAddr = Int(fileData[0]) | (Int(fileData[1]) << 8)
            let length = Int(fileData[2]) | (Int(fileData[3]) << 8)
            
            if length > 100 && length <= fileData.count - 4 && loadAddr >= 0x0800 && loadAddr <= 0xBFFF {
                fileData = fileData.subdata(in: 4..<(4 + length))
            }
        }
        
        return fileData.isEmpty ? nil : fileData
    }
    
    // MARK: - HDV Format
    
    static func readHDV(data: Data) -> [DiskImageFile]? {
        return readProDOSDSK(data: data)
    }
}

// MARK: - Catalog Reading Extension

extension DiskImageReader {
    static func readDiskCatalog(data: Data, filename: String = "Unknown") -> DiskCatalog? {
        // 2IMG Format
        if let catalog = read2IMGCatalogFull(data: data, filename: filename) {
            return catalog
        }
        
        // Direct Disk Images with Order Detection
        let result = readDiskCatalogWithOrderDetection(data: data, filename: filename)
        
        return result
    }
    
    static func read2IMGCatalogFull(data: Data, filename: String) -> DiskCatalog? {
        guard data.count >= 64 else { return nil }
        
        let signature = String(data: data.subdata(in: 0..<4), encoding: .ascii)
        guard signature == "2IMG" else { return nil }
        
        let imageFormat = data[12]
        let dataOffset = Int(data[24]) | (Int(data[25]) << 8) | (Int(data[26]) << 16) | (Int(data[27]) << 24)
        let dataLength = Int(data[28]) | (Int(data[29]) << 8) | (Int(data[30]) << 16) | (Int(data[31]) << 24)
        
        let actualDataLength: Int
        if dataLength == 0 {
            actualDataLength = data.count - dataOffset
        } else {
            actualDataLength = min(dataLength, data.count - dataOffset)
        }
        guard dataOffset < data.count else { return nil }
        
        let endOffset = min(dataOffset + actualDataLength, data.count)
        let diskData = data.subdata(in: dataOffset..<endOffset)
        
        if imageFormat == 0 {
            return readDOS33CatalogFull(data: diskData, filename: filename)
        } else if imageFormat == 1 {
            return readProDOSCatalogFull(data: diskData, filename: filename)
        }
        
        return nil
    }
    
    static func readProDOSCatalogFull(data: Data, filename: String) -> DiskCatalog? {
        let blockSize = 512
        guard data.count >= blockSize * 3 else { return nil }
        
        for volumeDirBlock in [2, 1] {
            let volumeDirOffset = volumeDirBlock * blockSize
            guard volumeDirOffset + blockSize <= data.count else { continue }
            
            let storageType = (data[volumeDirOffset + 4] & 0xF0) >> 4
            guard storageType == 0x0F else { continue }
            
            let volumeNameLength = Int(data[volumeDirOffset + 4] & 0x0F)
            guard volumeNameLength > 0 && volumeNameLength <= 15 else { continue }
            
            var volumeName = ""
            for i in 0..<volumeNameLength {
                volumeName.append(Character(UnicodeScalar(data[volumeDirOffset + 5 + i])))
            }
            
            let entries = readProDOSDirectoryForCatalog(data: data, startBlock: volumeDirBlock, blockSize: blockSize, parentPath: "")
            
            if !entries.isEmpty {
                return DiskCatalog(
                    diskName: volumeName.isEmpty ? filename : volumeName,
                    diskFormat: "ProDOS",
                    diskSize: data.count,
                    entries: entries
                )
            }
        }
        
        return nil
    }
    
    static func readProDOSDirectoryForCatalog(data: Data, startBlock: Int, blockSize: Int, parentPath: String) -> [DiskCatalogEntry] {
        var entries: [DiskCatalogEntry] = []
        var currentBlock = startBlock
        
        for _ in 0..<100 {
            let blockOffset = currentBlock * blockSize
            guard blockOffset + blockSize <= data.count else { break }
            
            let entriesPerBlock = currentBlock == startBlock ? 12 : 13
            let entryStart = currentBlock == startBlock ? 4 + 39 : 4
            
            for entryIdx in 0..<entriesPerBlock {
                let entryOffset = blockOffset + entryStart + (entryIdx * 39)
                guard entryOffset + 39 <= data.count else { continue }
                
                let entryStorageType = (data[entryOffset] & 0xF0) >> 4
                if entryStorageType == 0 { continue }
                
                let nameLength = Int(data[entryOffset] & 0x0F)
                var fileName = ""
                for i in 0..<nameLength {
                    fileName.append(Character(UnicodeScalar(data[entryOffset + 1 + i])))
                }
                
                let fileType = data[entryOffset + 16]
                let keyPointer = Int(data[entryOffset + 17]) | (Int(data[entryOffset + 18]) << 8)
                let blocksUsed = Int(data[entryOffset + 19]) | (Int(data[entryOffset + 20]) << 8)
                let eof = Int(data[entryOffset + 21]) | (Int(data[entryOffset + 22]) << 8) | (Int(data[entryOffset + 23]) << 16)
                
                let fullPath = parentPath.isEmpty ? fileName : "\(parentPath)/\(fileName)"
                
                if entryStorageType == 0x0D {
                    let subEntries = readProDOSDirectoryForCatalog(data: data, startBlock: keyPointer, blockSize: blockSize, parentPath: fullPath)
                    
                    let dirEntry = DiskCatalogEntry(
                        name: fileName,
                        fileType: 0x0F,
                        fileTypeString: "DIR",
                        size: subEntries.reduce(0) { $0 + $1.size },
                        blocks: blocksUsed,
                        loadAddress: nil,
                        length: nil,
                        data: Data(),
                        isImage: false,
                        imageType: .Unknown,
                        isDirectory: true,
                        children: subEntries
                    )
                    entries.append(dirEntry)
                } else {
                    if let fileData = extractProDOSFile(data: data, keyBlock: keyPointer, blocksUsed: blocksUsed, eof: eof, storageType: Int(entryStorageType)) {
                        var loadAddr: Int? = nil
                        var length: Int? = nil
                        if fileData.count > 4 && (fileType == 0x04 || fileType == 0x06) {
                            let potentialLoadAddr = Int(fileData[0]) | (Int(fileData[1]) << 8)
                            let potentialLength = Int(fileData[2]) | (Int(fileData[3]) << 8)
                            
                            if potentialLoadAddr < 0xC000 && potentialLength > 0 && potentialLength < 0x8000 {
                                loadAddr = potentialLoadAddr
                                length = potentialLength
                            }
                        }

                        let couldBeGraphics = (fileType == 0x04 || fileType == 0x06) && (
                            fileData.count == 8192 ||
                            fileData.count == 16384 ||
                            fileData.count == 32768 ||
                            fileData.count == 8196 ||
                            fileData.count == 16388 ||
                            fileData.count == 32772
                        )

                        let fileTypeInfo = ProDOSFileTypeInfo.getFileTypeInfo(fileType: fileType, auxType: loadAddr)

                        let result: (image: CGImage?, type: AppleIIImageType)
                        if couldBeGraphics || fileTypeInfo.isGraphics {
                            result = SHRDecoder.decode(data: fileData, filename: fileName)
                        } else {
                            result = (image: nil, type: .Unknown)
                        }

                        let isImage = result.image != nil && result.type != .Unknown
                        
                        let displayFileType: UInt8
                        if couldBeGraphics && isImage {
                            if fileData.count >= 16380 && fileData.count <= 16400 {
                                displayFileType = 0x08
                            } else {
                                displayFileType = 0x08
                            }
                        } else {
                            displayFileType = fileType
                        }

                        let displayAuxType: Int?
                        if couldBeGraphics && isImage {
                            if fileData.count >= 16380 && fileData.count <= 16400 {
                                displayAuxType = 0x4000
                            } else if fileData.count >= 8180 && fileData.count <= 8200 {
                                displayAuxType = 0x2000
                            } else {
                                displayAuxType = loadAddr
                            }
                        } else {
                            displayAuxType = loadAddr
                        }

                        let entry = DiskCatalogEntry(
                            name: fileName,
                            fileType: displayFileType,
                            fileTypeString: String(format: "$%02X", fileType),
                            size: fileData.count,
                            blocks: blocksUsed,
                            loadAddress: displayAuxType,
                            length: length,
                            data: fileData,
                            isImage: isImage,
                            imageType: result.type,
                            isDirectory: false,
                            children: nil
                        )
                        entries.append(entry)
                    }
                }
            }
            
            let nextBlock = Int(data[blockOffset + 2]) | (Int(data[blockOffset + 3]) << 8)
            if nextBlock == 0 { break }
            currentBlock = nextBlock
        }
        
        return entries
    }
    
    static func readDOS33CatalogFull(data: Data, filename: String) -> DiskCatalog? {
        let sectorSize = 256
        let sectorsPerTrack = 16
        let tracks = 35
        
        guard data.count >= sectorSize * sectorsPerTrack * tracks else {
            return nil
        }
        
        let vtocTrack = 17
        let vtocSector = 0
        let vtocOffset = (vtocTrack * sectorsPerTrack + vtocSector) * sectorSize
        
        guard vtocOffset + sectorSize <= data.count else {
            return nil
        }
        
        let catalogTrack = Int(data[vtocOffset + 1])
        
        guard catalogTrack == 17 else {
            return nil
        }
        
        var entries: [DiskCatalogEntry] = []
        var currentTrack = 17
        var currentSector = 15
        
        for _ in 0..<100 {
            let catalogOffset = (currentTrack * sectorsPerTrack + currentSector) * sectorSize
            guard catalogOffset + sectorSize <= data.count else { break }
            
            for entryIdx in 0..<7 {
                let entryOffset = catalogOffset + 11 + (entryIdx * 35)
                guard entryOffset + 35 <= data.count else { continue }
                
                let trackList = Int(data[entryOffset])
                let sectorList = Int(data[entryOffset + 1])
                
                if trackList == 0 || trackList == 0xFF { continue }
                
                var fileName = ""
                for i in 0..<30 {
                    let char = data[entryOffset + 3 + i] & 0x7F
                    if char == 0 || char == 0x20 { break }
                    if char > 0 {
                        fileName.append(Character(UnicodeScalar(char)))
                    }
                }
                fileName = fileName.trimmingCharacters(in: .whitespaces)
                
                let fileType = data[entryOffset + 2]
                let sectorsUsed = Int(data[entryOffset + 33]) | (Int(data[entryOffset + 34]) << 8)
                
                if let fileData = extractDOS33File(data: data, trackList: trackList, sectorList: sectorList, sectorsPerTrack: sectorsPerTrack, sectorSize: sectorSize) {
                    var loadAddr: Int? = nil
                    var length: Int? = nil
                    if fileData.count > 4 && (fileType & 0x7F == 0x04 || fileType & 0x7F == 0x06) {
                        loadAddr = Int(fileData[0]) | (Int(fileData[1]) << 8)
                        length = Int(fileData[2]) | (Int(fileData[3]) << 8)
                    }

                    let couldBeGraphics = (fileType & 0x7F == 0x04 || fileType & 0x7F == 0x06) && (
                        fileData.count == 8192 ||
                        fileData.count == 16384 ||
                        fileData.count == 32768 ||
                        fileData.count == 8196 ||
                        fileData.count == 16388 ||
                        fileData.count == 32772 ||
                        (fileData.count >= 8180 && fileData.count <= 8200) ||
                        (fileData.count >= 16380 && fileData.count <= 16400) ||
                        (fileData.count >= 32760 && fileData.count <= 32780) ||
                        (loadAddr == 0x2000 && fileData.count >= 8180) ||
                        (loadAddr == 0x4000 && fileData.count >= 16380)
                    )

                    let result: (image: CGImage?, type: AppleIIImageType)
                    if couldBeGraphics {
                        result = SHRDecoder.decode(data: fileData, filename: fileName)
                    } else {
                        result = (image: nil, type: .Unknown)
                    }

                    let isImage = result.image != nil && result.type != .Unknown

                    let proDOSFileType: UInt8 = couldBeGraphics ? 0x08 : (fileType & 0x7F)

                    let displayAuxType: Int?
                    if couldBeGraphics && isImage {
                        if fileData.count >= 16380 && fileData.count <= 16400 {
                            displayAuxType = 0x4000
                        } else if fileData.count >= 8180 && fileData.count <= 8200 {
                            displayAuxType = 0x2000
                        } else {
                            displayAuxType = loadAddr
                        }
                    } else {
                        displayAuxType = loadAddr
                    }

                    let entry = DiskCatalogEntry(
                        name: fileName,
                        fileType: proDOSFileType,
                        fileTypeString: String(format: "$%02X", fileType & 0x7F),
                        size: fileData.count,
                        blocks: sectorsUsed,
                        loadAddress: displayAuxType,
                        length: length,
                        data: fileData,
                        isImage: isImage,
                        imageType: result.type,
                        isDirectory: false,
                        children: nil
                    )
                    entries.append(entry)
                }
            }
            
            let nextTrack = Int(data[catalogOffset + 1])
            let nextSector = Int(data[catalogOffset + 2])
            
            if nextTrack == 0 { break }
            currentTrack = nextTrack
            currentSector = nextSector
        }
        
        return DiskCatalog(
            diskName: filename,
            diskFormat: "DOS 3.3",
            diskSize: data.count,
            entries: entries
        )
    }
}

// MARK: - Disk Order Conversion

extension DiskImageReader {
    
    static func convertDOSOrderToProDOSOrder(data: Data) -> Data? {
        guard data.count == 143360 else { return nil }
        
        var proDOSData = Data(count: data.count)
        
        let dosToProDOS: [Int] = [
            0x0, 0x7, 0xE, 0x6, 0xD, 0x5, 0xC, 0x4,
            0xB, 0x3, 0xA, 0x2, 0x9, 0x1, 0x8, 0xF
        ]
        
        let sectorsPerTrack = 16
        let sectorSize = 256
        let tracks = 35
        
        for track in 0..<tracks {
            for dosSector in 0..<sectorsPerTrack {
                let proDOSSector = dosToProDOS[dosSector]
                
                let dosOffset = (track * sectorsPerTrack + dosSector) * sectorSize
                let proDOSOffset = (track * sectorsPerTrack + proDOSSector) * sectorSize
                
                proDOSData[proDOSOffset..<(proDOSOffset + sectorSize)] = data[dosOffset..<(dosOffset + sectorSize)]
            }
        }
        
        return proDOSData
    }
    
    static func readDiskCatalogWithOrderDetection(data: Data, filename: String) -> DiskCatalog? {
        if let catalog = readProDOSCatalogFull(data: data, filename: filename) {
            if catalog.totalFiles > 0 {
                return catalog
            }
        }
        
        if let catalog = readDOS33CatalogFull(data: data, filename: filename) {
            return catalog
        }
        
        if data.count == 143360 {
            if let convertedData = convertDOSOrderToProDOSOrder(data: data) {
                if let catalog = readProDOSCatalogFull(data: convertedData, filename: filename) {
                    if catalog.totalFiles > 0 {
                        return catalog
                    }
                }
            }
        }
        
        return nil
    }
}
