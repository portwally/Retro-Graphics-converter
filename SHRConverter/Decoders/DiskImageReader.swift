import Foundation
import AppKit

// MARK: - Disk Image Reader

class DiskImageReader {
    
    static func readDiskImage(data: Data) -> [DiskImageFile] {
        var files: [DiskImageFile] = []

        if let twoImgFiles = read2IMG(data: data) {
            files.append(contentsOf: twoImgFiles)
        }
        else if let adfFiles = readADF(data: data) {
            files.append(contentsOf: adfFiles)
        }
        else if let cpcFiles = readCPCDSK(data: data) {
            files.append(contentsOf: cpcFiles)
        }
        else if let stFiles = readAtariST(data: data) {
            files.append(contentsOf: stFiles)
        }
        else if let msxFiles = readMSX(data: data) {
            files.append(contentsOf: msxFiles)
        }
        else if let atari8bitFiles = readAtari8bit(data: data) {
            files.append(contentsOf: atari8bitFiles)
        }
        else if let d64Files = readD64(data: data) {
            files.append(contentsOf: d64Files)
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

    // MARK: - Atari ST Disk Image

    static func readAtariST(data: Data) -> [DiskImageFile]? {
        let reader = AtariSTDiskReader()
        guard reader.canRead(data: data) else { return nil }

        guard let entries = reader.readDisk(data: data) else { return nil }

        var files: [DiskImageFile] = []

        for entry in entries {
            // Try to decode as image
            var imageData: Data? = nil
            var imageType: AppleIIImageType = .Unknown

            let ext = (entry.name as NSString).pathExtension.lowercased()

            // Atari ST image types
            if ["pi1", "pi2", "pi3", "pc1", "pc2", "pc3"].contains(ext) {
                let (cgImage, type) = AtariSTDecoder.decode(data: entry.data)
                if cgImage != nil {
                    imageData = entry.data
                    imageType = type
                }
            } else if ["neo"].contains(ext) {
                let (cgImage, type) = AtariSTDecoder.decodeNEOchrome(data: entry.data)
                if cgImage != nil {
                    imageData = entry.data
                    imageType = type
                }
            } else if ["iff", "lbm"].contains(ext) {
                let (cgImage, type) = AmigaIFFDecoder.decode(data: entry.data)
                if cgImage != nil {
                    imageData = entry.data
                    imageType = type
                }
            }

            if imageData != nil {
                files.append(DiskImageFile(
                    name: entry.name,
                    data: entry.data,
                    type: imageType
                ))
            }
        }

        return files.isEmpty ? nil : files
    }

    // MARK: - MSX Disk Image

    static func readMSX(data: Data) -> [DiskImageFile]? {
        let reader = MSXDiskReader()
        guard reader.canRead(data: data) else { return nil }

        guard let entries = reader.readDisk(data: data) else { return nil }

        var files: [DiskImageFile] = []

        for entry in entries {
            // Try to decode as image
            var imageData: Data? = nil
            var imageType: AppleIIImageType = .Unknown

            let ext = (entry.name as NSString).pathExtension.lowercased()

            // MSX image types
            if ["sc2", "grp", "sc5", "sc7", "sc8", "sr5", "sr7", "sr8", "ge5", "ge7", "ge8"].contains(ext) {
                let result = MSXDecoder.decode(data: entry.data, filename: entry.name)
                if result.image != nil {
                    imageData = entry.data
                    imageType = result.type
                }
            }

            if imageData != nil {
                files.append(DiskImageFile(
                    name: entry.name,
                    data: entry.data,
                    type: imageType
                ))
            }
        }

        return files.isEmpty ? nil : files
    }

    // MARK: - Atari 8-bit ATR Disk Image

    static func readAtari8bit(data: Data) -> [DiskImageFile]? {
        let reader = Atari8bitDiskReader()
        guard reader.canRead(data: data) else { return nil }

        guard let entries = reader.readDisk(data: data) else { return nil }

        var files: [DiskImageFile] = []

        for entry in entries {
            // Try to decode as image
            var imageData: Data? = nil
            var imageType: AppleIIImageType = .Unknown

            let ext = (entry.name as NSString).pathExtension.lowercased()

            // Atari 8-bit image types
            if ["gr8", "gr9", "gr15", "gr7", "gr11", "gr1", "gr2", "gr3", "gr4", "gr5", "gr6", "mic", "pic"].contains(ext) {
                let result = Atari8bitDecoder.decode(data: entry.data, filename: entry.name)
                if result.image != nil {
                    imageData = entry.data
                    imageType = result.type
                }
            }

            if imageData != nil {
                files.append(DiskImageFile(
                    name: entry.name,
                    data: entry.data,
                    type: imageType
                ))
            }
        }

        return files.isEmpty ? nil : files
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

            // Calculate how many blocks we need based on EOF
            let blocksNeeded = (eof + blockSize - 1) / blockSize

            for i in 0..<min(256, blocksNeeded) {
                let blockNum = Int(data[indexOffset + i]) | (Int(data[indexOffset + i + 256]) << 8)

                let bytesToRead = min(blockSize, eof - fileData.count)
                if bytesToRead <= 0 { break }

                if blockNum == 0 {
                    // Sparse block - fill with zeros
                    fileData.append(Data(repeating: 0, count: bytesToRead))
                } else {
                    let blockOffset = blockNum * blockSize
                    guard blockOffset + blockSize <= data.count else {
                        // Block out of range - treat as sparse
                        fileData.append(Data(repeating: 0, count: bytesToRead))
                        continue
                    }
                    fileData.append(data.subdata(in: blockOffset..<(blockOffset + bytesToRead)))
                }

                if fileData.count >= eof { break }
            }
        } else if storageType == 3 {
            let masterIndexOffset = keyBlock * blockSize
            guard masterIndexOffset + blockSize <= data.count else { return nil }

            // Calculate how many index blocks we need based on EOF
            let blocksNeeded = (eof + blockSize - 1) / blockSize
            let indexBlocksNeeded = (blocksNeeded + 255) / 256

            for masterIdx in 0..<min(128, indexBlocksNeeded) {
                let indexBlockNum = Int(data[masterIndexOffset + masterIdx]) | (Int(data[masterIndexOffset + masterIdx + 256]) << 8)

                // Calculate how many data blocks in this index block
                let blocksInThisIndex = min(256, blocksNeeded - (masterIdx * 256))

                if indexBlockNum == 0 {
                    // Sparse index block - fill with zeros for all blocks it would contain
                    for _ in 0..<blocksInThisIndex {
                        let bytesToRead = min(blockSize, eof - fileData.count)
                        if bytesToRead <= 0 { break }
                        fileData.append(Data(repeating: 0, count: bytesToRead))
                    }
                    if fileData.count >= eof { break }
                    continue
                }

                let indexOffset = indexBlockNum * blockSize
                guard indexOffset + blockSize <= data.count else { continue }

                for i in 0..<blocksInThisIndex {
                    let blockNum = Int(data[indexOffset + i]) | (Int(data[indexOffset + i + 256]) << 8)

                    let bytesToRead = min(blockSize, eof - fileData.count)
                    if bytesToRead <= 0 { break }

                    if blockNum == 0 {
                        // Sparse block - fill with zeros
                        fileData.append(Data(repeating: 0, count: bytesToRead))
                    } else {
                        let blockOffset = blockNum * blockSize
                        guard blockOffset + blockSize <= data.count else {
                            fileData.append(Data(repeating: 0, count: bytesToRead))
                            continue
                        }
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
                
                let fileType = data[entryOffset + 2]
                let fileTypeUnlocked = fileType & 0x7F

                if fileTypeUnlocked == 0x02 || fileTypeUnlocked == 0x01 || fileTypeUnlocked == 0x04 || fileTypeUnlocked == 0x06 {
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
    
    static func extractDOS33File(data: Data, trackList: Int, sectorList: Int, sectorsPerTrack: Int, sectorSize: Int, stripHeader: Bool = true) -> Data? {
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

        // Strip DOS 3.3 binary header (4 bytes: load address + length) if requested
        if stripHeader && fileData.count > 4 {
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

    // MARK: - Amiga ADF Format

    static func readADF(data: Data) -> [DiskImageFile]? {
        // ADF sizes: 901120 (DD), 1802240 (HD)
        let validSizes = [901120, 1802240]
        guard validSizes.contains(data.count) else { return nil }

        // Check root block for AmigaDOS signature
        let isDD = data.count == 901120
        let rootBlock = isDD ? 880 : 1760
        guard let rootData = readADFBlock(data: data, block: rootBlock) else { return nil }

        // Validate root block type (T_HEADER = 2) and secondary type (ST_ROOT = 1)
        let blockType = readADFLong(data: rootData, offset: 0)
        let secType = readADFLong(data: rootData, offset: 508)
        guard blockType == 2 && secType == 1 else { return nil }

        var files: [DiskImageFile] = []

        // Read hash table (72 entries starting at offset 24)
        for i in 0..<72 {
            let hashEntry = readADFLong(data: rootData, offset: 24 + (i * 4))
            if hashEntry == 0 { continue }

            // Follow hash chain
            var currentBlock = Int(hashEntry)
            var visited = Set<Int>()

            while currentBlock != 0 && !visited.contains(currentBlock) {
                visited.insert(currentBlock)

                guard let headerData = readADFBlock(data: data, block: currentBlock) else { break }

                let headerType = readADFLong(data: headerData, offset: 0)
                let headerSecType = readADFLong(data: headerData, offset: 508)

                // ST_FILE = -3 (0xFFFFFFFD)
                if headerType == 2 && headerSecType == 0xFFFFFFFD {
                    // It's a file
                    if let fileInfo = extractADFFile(data: data, headerBlock: currentBlock, headerData: headerData) {
                        // Check if it's an image file
                        let result = SHRDecoder.decode(data: fileInfo.data, filename: fileInfo.name)
                        if result.type != .Unknown, result.image != nil {
                            files.append(DiskImageFile(name: fileInfo.name, data: fileInfo.data, type: result.type))
                        }
                    }
                }

                // Follow hash chain (next entry with same hash)
                currentBlock = Int(readADFLong(data: headerData, offset: 504))
            }
        }

        return files.isEmpty ? nil : files
    }

    private static func readADFBlock(data: Data, block: Int) -> Data? {
        let blockSize = 512
        let offset = block * blockSize
        guard offset + blockSize <= data.count else { return nil }
        return data.subdata(in: offset..<(offset + blockSize))
    }

    private static func readADFLong(data: Data, offset: Int) -> UInt32 {
        guard offset + 4 <= data.count else { return 0 }
        // AmigaDOS uses big-endian
        return UInt32(data[offset]) << 24 | UInt32(data[offset + 1]) << 16 |
               UInt32(data[offset + 2]) << 8 | UInt32(data[offset + 3])
    }

    private static func readADFString(data: Data, offset: Int, maxLength: Int) -> String {
        guard offset < data.count else { return "" }
        let length = min(Int(data[offset]), maxLength)
        guard offset + 1 + length <= data.count else { return "" }
        var name = ""
        for i in 0..<length {
            let char = data[offset + 1 + i]
            if char == 0 { break }
            name.append(Character(UnicodeScalar(char)))
        }
        return name
    }

    private static func extractADFFile(data: Data, headerBlock: Int, headerData: Data) -> (name: String, data: Data)? {
        // Read filename from header (offset 432, BCPL string: length byte + chars)
        let fileName = readADFString(data: headerData, offset: 432, maxLength: 30)
        guard !fileName.isEmpty else { return nil }

        // Get file size (offset 324, 4 bytes)
        let fileSize = Int(readADFLong(data: headerData, offset: 324))
        guard fileSize > 0 else { return nil }

        // Determine if OFS or FFS by checking data block structure
        // First data block is at offset 16 in header
        let firstDataBlock = Int(readADFLong(data: headerData, offset: 16))
        guard firstDataBlock > 0 else { return nil }

        guard let firstBlockData = readADFBlock(data: data, block: firstDataBlock) else { return nil }

        // Check if OFS (has header) or FFS (pure data)
        let dataBlockType = readADFLong(data: firstBlockData, offset: 0)
        let isOFS = (dataBlockType == 8) // T_DATA = 8

        var fileData = Data()

        if isOFS {
            // OFS: Data blocks have headers
            // Header: type(4), headerKey(4), seqNum(4), dataSize(4), nextData(4), checksum(4), data(488)
            // Use the data block table from header (more reliable than following chain)
            var dataBlocksWithSeq: [(seq: Int, block: Int)] = []

            // Collect data block pointers from header (offsets 308 down to 24, 72 entries max)
            for i in 0..<72 {
                let offset = 308 - (i * 4)
                if offset < 24 { break }
                let blockPtr = Int(readADFLong(data: headerData, offset: offset))
                if blockPtr == 0 { break }
                // Read sequence number from the data block
                if let blockData = readADFBlock(data: data, block: blockPtr) {
                    let blockType = readADFLong(data: blockData, offset: 0)
                    if blockType == 8 { // T_DATA
                        let seqNum = Int(readADFLong(data: blockData, offset: 8))
                        dataBlocksWithSeq.append((seqNum, blockPtr))
                    }
                }
            }

            // Check for extension blocks (at offset 496)
            var extensionBlock = Int(readADFLong(data: headerData, offset: 496))
            var visitedExt = Set<Int>()

            while extensionBlock != 0 && !visitedExt.contains(extensionBlock) {
                visitedExt.insert(extensionBlock)
                guard let extData = readADFBlock(data: data, block: extensionBlock) else { break }

                // Read more data block pointers from extension
                for i in 0..<72 {
                    let offset = 308 - (i * 4)
                    if offset < 24 { break }
                    let blockPtr = Int(readADFLong(data: extData, offset: offset))
                    if blockPtr == 0 { break }
                    if let blockData = readADFBlock(data: data, block: blockPtr) {
                        let blockType = readADFLong(data: blockData, offset: 0)
                        if blockType == 8 {
                            let seqNum = Int(readADFLong(data: blockData, offset: 8))
                            dataBlocksWithSeq.append((seqNum, blockPtr))
                        }
                    }
                }
                extensionBlock = Int(readADFLong(data: extData, offset: 496))
            }

            // If block table didn't have enough blocks, scan for remaining by headerKey
            let neededBlocks = (fileSize + 487) / 488
            if dataBlocksWithSeq.count < neededBlocks {
                let maxBlocks = data.count / 512
                for blkNum in 1..<maxBlocks {
                    if let blockData = readADFBlock(data: data, block: blkNum) {
                        let blockType = readADFLong(data: blockData, offset: 0)
                        let hdrKey = Int(readADFLong(data: blockData, offset: 4))
                        if blockType == 8 && hdrKey == headerBlock {
                            let seqNum = Int(readADFLong(data: blockData, offset: 8))
                            if !dataBlocksWithSeq.contains(where: { $0.seq == seqNum }) {
                                dataBlocksWithSeq.append((seqNum, blkNum))
                            }
                        }
                    }
                }
            }

            // Sort by sequence number and extract data
            dataBlocksWithSeq.sort { $0.seq < $1.seq }

            for (_, blockNum) in dataBlocksWithSeq {
                guard let blockData = readADFBlock(data: data, block: blockNum) else { continue }
                let dataSize = Int(readADFLong(data: blockData, offset: 12))
                let bytesToRead = min(dataSize, 488, fileSize - fileData.count)
                if bytesToRead > 0 && 24 + bytesToRead <= blockData.count {
                    fileData.append(blockData.subdata(in: 24..<(24 + bytesToRead)))
                }
                if fileData.count >= fileSize { break }
            }
        } else {
            // FFS: Pure data blocks, use extension blocks for block list
            // Read data block pointers from header extension area
            // Data blocks listed at offsets 308-51 (going backwards from 308)
            var dataBlocks: [Int] = []

            // First, collect data block pointers from header (offsets 308 down to 52, 72 entries max)
            for i in 0..<72 {
                let blockPtr = Int(readADFLong(data: headerData, offset: 308 - (i * 4)))
                if blockPtr == 0 { break }
                dataBlocks.append(blockPtr)
            }

            // Check for extension block (at offset 496)
            var extensionBlock = Int(readADFLong(data: headerData, offset: 496))
            var visited = Set<Int>()

            while extensionBlock != 0 && !visited.contains(extensionBlock) {
                visited.insert(extensionBlock)

                guard let extData = readADFBlock(data: data, block: extensionBlock) else { break }

                // Read more data block pointers from extension
                for i in 0..<72 {
                    let blockPtr = Int(readADFLong(data: extData, offset: 308 - (i * 4)))
                    if blockPtr == 0 { break }
                    dataBlocks.append(blockPtr)
                }

                extensionBlock = Int(readADFLong(data: extData, offset: 496))
            }

            // Read data from all data blocks
            for blockNum in dataBlocks {
                guard let blockData = readADFBlock(data: data, block: blockNum) else { continue }
                let bytesToRead = min(512, fileSize - fileData.count)
                if bytesToRead > 0 {
                    fileData.append(blockData.prefix(bytesToRead))
                }
                if fileData.count >= fileSize { break }
            }
        }

        // Trim to exact file size
        if fileData.count > fileSize {
            fileData = fileData.prefix(fileSize)
        }

        return fileData.isEmpty ? nil : (fileName, fileData)
    }

    // MARK: - Amstrad CPC DSK Format

    static func readCPCDSK(data: Data) -> [DiskImageFile]? {
        // Check for CPC DSK signature
        guard data.count >= 256 else { return nil }

        let header = String(data: data.subdata(in: 0..<34), encoding: .ascii) ?? ""
        let isExtended = header.hasPrefix("EXTENDED CPC DSK File")
        let isStandard = header.hasPrefix("MV - CPC")

        guard isExtended || isStandard else { return nil }

        // Parse disk information block
        let numTracks = Int(data[48])
        let numSides = Int(data[49])

        guard numTracks > 0 && numSides > 0 else { return nil }

        // Extract all files from the disk
        var files: [DiskImageFile] = []

        // Read directory from track 0 (typically sectors C1-C4 for DATA format)
        // The CPC uses a CP/M-like filesystem
        let directoryEntries = readCPCDirectory(data: data, isExtended: isExtended, numTracks: numTracks, numSides: numSides)

        for entry in directoryEntries {
            // Try to decode as image
            let result = SHRDecoder.decode(data: entry.data, filename: entry.name)
            if result.type != .Unknown, result.image != nil {
                files.append(DiskImageFile(name: entry.name, data: entry.data, type: result.type))
            }
        }

        return files.isEmpty ? nil : files
    }

    private static func readCPCDirectory(data: Data, isExtended: Bool, numTracks: Int, numSides: Int) -> [(name: String, data: Data)] {
        var files: [(name: String, data: Data)] = []

        // Build sector map from the disk image
        var sectorMap: [Int: [Int: Data]] = [:] // track -> sector -> data

        var offset = 256 // Start after disk info block

        for track in 0..<numTracks {
            for side in 0..<numSides {
                let trackIndex = track * numSides + side

                // Get track size
                var trackSize: Int
                if isExtended {
                    // Extended format: track sizes in table at offset 52
                    let sizeIndex = 52 + trackIndex
                    if sizeIndex < data.count {
                        trackSize = Int(data[sizeIndex]) * 256
                    } else {
                        continue
                    }
                } else {
                    // Standard format: fixed track size at offset 50-51 (little-endian)
                    trackSize = Int(data[50]) | (Int(data[51]) << 8)
                }

                if trackSize == 0 { continue }
                guard offset + trackSize <= data.count else { break }

                // Parse track information block
                let trackData = data.subdata(in: offset..<(offset + trackSize))
                if trackData.count >= 24 {
                    let trackSig = String(data: trackData.subdata(in: 0..<12), encoding: .ascii) ?? ""
                    if trackSig.hasPrefix("Track-Info") {
                        // Use PHYSICAL track number from header for proper AMSDOS block mapping
                        let physicalTrack = Int(trackData[16])
                        let sectorCount = Int(trackData[21])
                        let sectorSizeCode = Int(trackData[20])
                        let defaultSectorSize = 128 << sectorSizeCode

                        if sectorMap[physicalTrack] == nil {
                            sectorMap[physicalTrack] = [:]
                        }

                        var sectorOffset = 256 // Sector data starts after track info block

                        for sectorIndex in 0..<sectorCount {
                            let infoOffset = 24 + (sectorIndex * 8)
                            guard infoOffset + 8 <= trackData.count else { break }

                            let sectorID = Int(trackData[infoOffset + 2])
                            var sectorSize = defaultSectorSize

                            if isExtended {
                                // Extended format has actual sector size in info
                                let actualSize = Int(trackData[infoOffset + 6]) | (Int(trackData[infoOffset + 7]) << 8)
                                if actualSize > 0 {
                                    sectorSize = actualSize
                                }
                            }

                            if sectorOffset + sectorSize <= trackData.count {
                                let sectorData = trackData.subdata(in: sectorOffset..<(sectorOffset + sectorSize))
                                sectorMap[physicalTrack]?[sectorID] = sectorData
                            }

                            sectorOffset += sectorSize
                        }
                    }
                }

                offset += trackSize
            }
        }

        // Read directory entries from track 0 (sectors 0xC1-0xC4 for DATA format, or 0x41-0x44 for SYSTEM)
        var directoryData = Data()

        // Try DATA format sectors first (C1-C4 = 193-196)
        for sectorID in [0xC1, 0xC2, 0xC3, 0xC4] {
            if let sectorData = sectorMap[0]?[sectorID] {
                directoryData.append(sectorData)
            }
        }

        // If no data, try SYSTEM format sectors (41-44)
        if directoryData.isEmpty {
            for sectorID in [0x41, 0x42, 0x43, 0x44] {
                if let sectorData = sectorMap[0]?[sectorID] {
                    directoryData.append(sectorData)
                }
            }
        }

        // If still no data, try sectors 1-4 (some formats)
        if directoryData.isEmpty {
            for sectorID in 1...4 {
                if let sectorData = sectorMap[0]?[sectorID] {
                    directoryData.append(sectorData)
                }
            }
        }

        guard !directoryData.isEmpty else { return files }

        // Build linear sector list for block allocation
        // In AMSDOS DATA format: Block 0 starts at track 0 sector C5 (after directory C1-C4)
        // Use physical track numbers in order for proper block-to-sector mapping
        var linearSectors: [(track: Int, sectorID: Int)] = []

        // First: Track 0 data sectors (C5-C9, after directory)
        for sectorOffset in 4..<9 {  // C5-C9 (skip C1-C4 directory)
            let sectorID = 0xC1 + sectorOffset
            if sectorMap[0]?[sectorID] != nil {
                linearSectors.append((0, sectorID))
            }
        }

        // Then: Physical tracks 1-39 in order (some may be missing in incomplete disk images)
        for physTrack in 1..<40 {
            if let trackSectors = sectorMap[physTrack] {
                for sectorOffset in 0..<9 {  // C1-C9
                    let sectorID = 0xC1 + sectorOffset
                    if trackSectors[sectorID] != nil {
                        linearSectors.append((physTrack, sectorID))
                    }
                }
            }
        }

        // Parse CP/M directory entries (32 bytes each)
        var fileEntries: [String: [(extent: Int, blocks: [Int])]] = [:]

        for entryOffset in stride(from: 0, to: directoryData.count, by: 32) {
            guard entryOffset + 32 <= directoryData.count else { break }

            let userNumber = directoryData[entryOffset]
            if userNumber == 0xE5 { continue } // Deleted entry
            if userNumber > 15 { continue } // Invalid user number

            // Extract filename (8 bytes) and extension (3 bytes)
            var filename = ""
            for i in 1...8 {
                let char = directoryData[entryOffset + i] & 0x7F
                if char > 32 && char < 127 {
                    filename.append(Character(UnicodeScalar(char)))
                }
            }
            filename = filename.trimmingCharacters(in: .whitespaces)

            var ext = ""
            for i in 9...11 {
                let char = directoryData[entryOffset + i] & 0x7F
                if char > 32 && char < 127 {
                    ext.append(Character(UnicodeScalar(char)))
                }
            }
            ext = ext.trimmingCharacters(in: .whitespaces)

            if !ext.isEmpty {
                filename += "." + ext
            }

            if filename.isEmpty { continue }

            let extentLow = Int(directoryData[entryOffset + 12])
            let extentHigh = Int(directoryData[entryOffset + 14])
            let extent = extentLow + (extentHigh * 32)

            // Block pointers (16 bytes, either 8x 16-bit or 16x 8-bit depending on disk size)
            var blocks: [Int] = []
            for i in 0..<16 {
                let blockNum = Int(directoryData[entryOffset + 16 + i])
                if blockNum != 0 {
                    blocks.append(blockNum)
                }
            }

            if fileEntries[filename] == nil {
                fileEntries[filename] = []
            }
            fileEntries[filename]?.append((extent: extent, blocks: blocks))
        }

        // Extract file data for each file using linear sector mapping
        let sectorsPerBlock = 2  // 1024 / 512
        let reservedBlocks = 2   // Blocks 0-1 are reserved for directory in DATA format

        for (filename, extents) in fileEntries {
            let sortedExtents = extents.sorted { $0.extent < $1.extent }

            var fileData = Data()
            for extentInfo in sortedExtents {
                for blockNum in extentInfo.blocks {
                    // Block numbers in directory are absolute - subtract reserved blocks to get data index
                    guard blockNum >= reservedBlocks else { continue }
                    let firstSector = (blockNum - reservedBlocks) * sectorsPerBlock

                    for i in 0..<sectorsPerBlock {
                        let sectorIdx = firstSector + i
                        if sectorIdx >= 0 && sectorIdx < linearSectors.count {
                            let (track, sectorID) = linearSectors[sectorIdx]
                            if let sectorData = sectorMap[track]?[sectorID] {
                                fileData.append(sectorData)
                            }
                        }
                    }
                }
            }

            if !fileData.isEmpty {
                files.append((name: filename, data: fileData))
            }
        }

        return files
    }

    // MARK: - C64 D64 Format
    
    static func readD64(data: Data) -> [DiskImageFile]? {
        // D64 sizes: 174848 (with error bytes) or 174848-683 = 174165 (without)
        // Standard: 35 tracks, 683 sectors total
        let validSizes = [174848, 175531] // with/without error info
        
        guard validSizes.contains(data.count) else {
            return nil
        }
        
        var files: [DiskImageFile] = []
        
        // Track 18, Sector 0 = BAM (Block Availability Map) and Directory header
        let dirTrack = 18
        let dirSector = 0
        
        guard let bamData = readD64Sector(data: data, track: dirTrack, sector: dirSector) else {
            return nil
        }
        
        // Ensure BAM has enough data
        guard bamData.count >= 2 else {
            return nil
        }
        
        // First directory sector is at Track 18, Sector 1
        var currentTrack = Int(bamData[0])
        var currentSector = Int(bamData[1])
        var loopCount = 0
        
        while currentTrack != 0 && loopCount < 100 {
            loopCount += 1
            
            guard let sectorData = readD64Sector(data: data, track: currentTrack, sector: currentSector) else {
                break
            }
            
            // Ensure sector has enough data
            guard sectorData.count >= 2 else {
                break
            }
            
            // Each sector contains 8 directory entries (32 bytes each)
            for entryIdx in 0..<8 {
                let entryOffset = 2 + (entryIdx * 32)
                guard entryOffset + 32 <= sectorData.count else { continue }
                
                let fileType = sectorData[entryOffset]
                
                // Skip deleted or empty entries
                if fileType == 0 || fileType == 0x80 {
                    continue
                }
                
                // Read filename (16 bytes, PETSCII, padded with 0xA0)
                var fileName = ""
                for i in 0..<16 {
                    guard entryOffset + 3 + i < sectorData.count else { break }
                    let char = sectorData[entryOffset + 3 + i]
                    if char == 0xA0 || char == 0 { break }
                    fileName.append(Character(UnicodeScalar(char)))
                }
                
                if fileName.isEmpty { continue }
                
                // File location
                let fileTrack = Int(sectorData[entryOffset + 1])
                let fileSector = Int(sectorData[entryOffset + 2])
                
                // File size in sectors (2 bytes, little endian)
                let sizeInSectors = Int(sectorData[entryOffset + 28]) | (Int(sectorData[entryOffset + 29]) << 8)
                
                // Extract file data
                if let fileData = extractD64File(data: data, startTrack: fileTrack, startSector: fileSector) {
                    // Detect file type
                    let actualFileType = fileType & 0x07
                    let fileTypeString: String
                    switch actualFileType {
                    case 1: fileTypeString = "SEQ"
                    case 2: fileTypeString = "PRG"
                    case 3: fileTypeString = "USR"
                    case 4: fileTypeString = "REL"
                    default: fileTypeString = "???"
                    }
                    
                    // Check if it's a graphics file
                    let result: (image: CGImage?, type: AppleIIImageType)
                    let isGraphics = (fileData.count >= 9000 && fileData.count <= 10020)
                    
                    if isGraphics {
                        result = SHRDecoder.decode(data: fileData, filename: fileName)
                    } else {
                        result = (nil, .Unknown)
                    }
                    
                    let imageType = result.type
                    
                    files.append(DiskImageFile(
                        name: "\(fileName).\(fileTypeString.lowercased())",
                        data: fileData,
                        type: imageType
                    ))
                }
            }
            
            // Next directory sector
            currentTrack = Int(sectorData[0])
            currentSector = Int(sectorData[1])
        }
        
        return files.isEmpty ? nil : files
    }
    
    private static func readD64Sector(data: Data, track: Int, sector: Int) -> Data? {
        // C64 1541 disk geometry
        let sectorsPerTrack: [Int] = [
            // Tracks 1-17: 21 sectors
            21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21, 21,
            // Tracks 18-24: 19 sectors
            19, 19, 19, 19, 19, 19, 19,
            // Tracks 25-30: 18 sectors
            18, 18, 18, 18, 18, 18,
            // Tracks 31-35: 17 sectors
            17, 17, 17, 17, 17
        ]
        
        guard track >= 1 && track <= 35 else { return nil }
        guard sector >= 0 && sector < sectorsPerTrack[track - 1] else { return nil }
        
        // Calculate offset
        var offset = 0
        for t in 1..<track {
            offset += sectorsPerTrack[t - 1] * 256
        }
        offset += sector * 256
        
        guard offset + 256 <= data.count else { return nil }
        
        return data.subdata(in: offset..<(offset + 256))
    }
    
    private static func extractD64File(data: Data, startTrack: Int, startSector: Int) -> Data? {
        var fileData = Data()
        var currentTrack = startTrack
        var currentSector = startSector
        var visited = Set<String>()
        
        while currentTrack != 0 {
            let key = "\(currentTrack):\(currentSector)"
            if visited.contains(key) {
                break // Circular reference
            }
            visited.insert(key)
            
            guard let sectorData = readD64Sector(data: data, track: currentTrack, sector: currentSector) else {
                break
            }
            
            // Ensure we have at least 2 bytes
            guard sectorData.count >= 2 else {
                break
            }
            
            let nextTrack = Int(sectorData[0])
            let nextSector = Int(sectorData[1])
            
            if nextTrack == 0 {
                // Last sector: byte 1 contains number of bytes used (1-255)
                let bytesUsed = max(1, min(Int(sectorData[1]), 254))
                let endIdx = min(2 + bytesUsed, sectorData.count)
                if endIdx > 2 {
                    fileData.append(sectorData.subdata(in: 2..<endIdx))
                }
                break
            } else {
                // Full sector (254 bytes of data)
                let endIdx = min(256, sectorData.count)
                if endIdx > 2 {
                    fileData.append(sectorData.subdata(in: 2..<endIdx))
                }
                currentTrack = nextTrack
                currentSector = nextSector
            }
            
            // Safety check: limit iterations
            if visited.count > 1000 {
                break
            }
        }
        
        return fileData.isEmpty ? nil : fileData
    }
}

// MARK: - Catalog Reading Extension

extension DiskImageReader {
    static func readDiskCatalog(data: Data, filename: String = "Unknown") -> DiskCatalog? {
        // 2IMG Format
        if let catalog = read2IMGCatalogFull(data: data, filename: filename) {
            return catalog
        }

        // Amiga ADF Format
        if let catalog = readADFCatalogFull(data: data, filename: filename) {
            return catalog
        }

        // Amstrad CPC DSK Format (check before ProDOS/DOS 3.3 DSK since it has unique header)
        if let catalog = readCPCDSKCatalogFull(data: data, filename: filename) {
            return catalog
        }

        // Atari ST Disk Image
        if let catalog = readAtariSTCatalogFull(data: data, filename: filename) {
            return catalog
        }

        // MSX Disk Image
        if let catalog = readMSXCatalogFull(data: data, filename: filename) {
            return catalog
        }

        // Atari 8-bit ATR Disk Image
        if let catalog = readAtari8bitCatalogFull(data: data, filename: filename) {
            return catalog
        }

        // C64 D64 Format
        if let catalog = readD64CatalogFull(data: data, filename: filename) {
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

            // Validate volume name contains only valid ProDOS characters (A-Z, 0-9, .)
            // This prevents misidentifying random data as a ProDOS volume header
            var volumeName = ""
            var validName = true
            for i in 0..<volumeNameLength {
                let char = data[volumeDirOffset + 5 + i]
                // ProDOS names: uppercase letters A-Z (0x41-0x5A), digits 0-9 (0x30-0x39), period (0x2E)
                if (char >= 0x41 && char <= 0x5A) || (char >= 0x30 && char <= 0x39) || char == 0x2E {
                    volumeName.append(Character(UnicodeScalar(char)))
                } else {
                    validName = false
                    break
                }
            }
            guard validName else { continue }

            // Additional validation: check that the entry count field is reasonable
            let entryCount = Int(data[volumeDirOffset + 0x25]) | (Int(data[volumeDirOffset + 0x26]) << 8)
            guard entryCount < 1000 else { continue }  // Sanity check

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
                // Read auxType from directory entry (at offset +31, 2 bytes)
                let auxType = Int(data[entryOffset + 31]) | (Int(data[entryOffset + 32]) << 8)

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

                            // Only detect header if load address is a known graphics address
                            // AND the length makes sense for the file size
                            // This prevents false positives from graphics data that happens to look like a header
                            let isKnownGraphicsAddr = (potentialLoadAddr == 0x2000 || potentialLoadAddr == 0x4000)
                            let lengthMatchesFile = (potentialLength > 0 && potentialLength <= fileData.count - 4)

                            if isKnownGraphicsAddr && lengthMatchesFile {
                                loadAddr = potentialLoadAddr
                                length = potentialLength
                            }
                        }

                        // Check if this could be a graphics file
                        // Consider both size-based detection and auxType (load address) based detection
                        let hasGraphicsSize = (
                            fileData.count == 8184 ||  // HGR with 4-byte header minus padding
                            fileData.count == 8192 ||  // Standard HGR
                            fileData.count == 8196 ||  // HGR with 4-byte header
                            (fileData.count >= 8184 && fileData.count <= 8200) ||  // HGR range
                            fileData.count == 16384 || // Standard DHGR
                            fileData.count == 16388 || // DHGR with 4-byte header
                            (fileData.count >= 16380 && fileData.count <= 16400) ||  // DHGR range
                            fileData.count == 32768 || // Standard SHR
                            fileData.count == 32772 || // SHR with 4-byte header
                            (fileData.count >= 32760 && fileData.count <= 32780)  // SHR range
                        )
                        // Also check if auxType indicates a graphics load address
                        let hasGraphicsAuxType = (auxType == 0x2000 || auxType == 0x4000)
                        // Check for .3201 extension (Compressed 3200-Color Image)
                        let has3201Extension = fileName.lowercased().contains(".3201")
                        let couldBeGraphics = (fileType == 0x04 || fileType == 0x06) && (hasGraphicsSize || hasGraphicsAuxType || has3201Extension)

                        // Use auxType for PNT/PIC files, loadAddr for BIN files
                        let effectiveAuxType = (fileType == 0xC0 || fileType == 0xC1) ? auxType : (loadAddr ?? 0)
                        let fileTypeInfo = ProDOSFileTypeInfo.getFileTypeInfo(fileType: fileType, auxType: effectiveAuxType)

                        let result: (image: CGImage?, type: AppleIIImageType)
                        if couldBeGraphics || fileTypeInfo.isGraphics {
                            // Für BIN/TXT Dateien mit Graphics: 4-Byte-Header abschneiden falls vorhanden
                            var dataToDecode = fileData
                            if (fileType == 0x04 || fileType == 0x06) && loadAddr != nil && length != nil && fileData.count >= 4 {
                                // Header detected, strip it
                                dataToDecode = fileData.subdata(in: 4..<fileData.count)
                            }
                            // Construct filename with ProDOS type info (e.g., "FILENAME#c00001")
                            // This tells SHRDecoder the exact format for PNT/PIC files
                            let filenameWithType = String(format: "%@#%02x%04x", fileName, fileType, effectiveAuxType)
                            result = SHRDecoder.decode(data: dataToDecode, filename: filenameWithType)
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
                        if fileType == 0xC0 || fileType == 0xC1 {
                            // For PNT/PIC files, use the actual auxType from directory
                            displayAuxType = auxType
                        } else if couldBeGraphics && isImage {
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
                            fileType: fileType,  // Keep original fileType for proper detection
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
                
                if let fileData = extractDOS33File(data: data, trackList: trackList, sectorList: sectorList, sectorsPerTrack: sectorsPerTrack, sectorSize: sectorSize, stripHeader: false) {
                    var loadAddr: Int? = nil
                    var length: Int? = nil
                    if fileData.count > 4 && (fileType & 0x7F == 0x04 || fileType & 0x7F == 0x06) {
                        loadAddr = Int(fileData[0]) | (Int(fileData[1]) << 8)
                        length = Int(fileData[2]) | (Int(fileData[3]) << 8)
                    }

                    // Check for .3201 extension (Compressed 3200-Color Image)
                    let has3201Extension = fileName.lowercased().contains(".3201")
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
                        (loadAddr == 0x4000 && fileData.count >= 16380) ||
                        has3201Extension
                    )

                    // Strip header for decoding if it's a binary file with valid header
                    var dataToDecode = fileData
                    var hasValidHeader = false
                    if (fileType & 0x7F == 0x04 || fileType & 0x7F == 0x06),
                       let addr = loadAddr, let len = length,
                       len > 100 && len <= fileData.count - 4 && addr >= 0x0800 && addr <= 0xBFFF {
                        dataToDecode = fileData.subdata(in: 4..<(4 + len))
                        hasValidHeader = true
                    }

                    let result: (image: CGImage?, type: AppleIIImageType)
                    if couldBeGraphics {
                        result = SHRDecoder.decode(data: dataToDecode, filename: fileName)
                    } else {
                        result = (image: nil, type: .Unknown)
                    }

                    let isImage = result.image != nil && result.type != .Unknown

                    let proDOSFileType: UInt8 = couldBeGraphics ? 0x08 : (fileType & 0x7F)

                    let displayAuxType: Int?
                    if couldBeGraphics && isImage {
                        if dataToDecode.count >= 16380 && dataToDecode.count <= 16400 {
                            displayAuxType = 0x4000
                        } else if dataToDecode.count >= 8180 && dataToDecode.count <= 8200 {
                            displayAuxType = 0x2000
                        } else {
                            displayAuxType = loadAddr
                        }
                    } else {
                        displayAuxType = loadAddr
                    }

                    // Store stripped data for import (decoder expects raw image data without header)
                    let entry = DiskCatalogEntry(
                        name: fileName,
                        fileType: proDOSFileType,
                        fileTypeString: String(format: "$%02X", fileType & 0x7F),
                        size: fileData.count,
                        blocks: sectorsUsed,
                        loadAddress: displayAuxType,
                        length: length,
                        data: dataToDecode,
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
    
    static func readD64CatalogFull(data: Data, filename: String) -> DiskCatalog? {
        let validSizes = [174848, 175531]
        guard validSizes.contains(data.count) else { return nil }
        
        var entries: [DiskCatalogEntry] = []
        
        // Track 18, Sector 0 = BAM
        guard let bamData = readD64Sector(data: data, track: 18, sector: 0) else {
            return nil
        }
        
        // Ensure BAM has enough data
        guard bamData.count >= 2 && bamData.count >= 0x90 + 16 else {
            return nil
        }
        
        // Disk name starts at offset 0x90 (144), 16 bytes
        var diskName = ""
        for i in 0..<16 {
            let char = bamData[0x90 + i]
            if char == 0xA0 || char == 0 { break }
            diskName.append(Character(UnicodeScalar(char)))
        }
        if diskName.isEmpty { diskName = filename }
        
        // First directory sector
        var currentTrack = Int(bamData[0])
        var currentSector = Int(bamData[1])
        var loopCount = 0
        
        while currentTrack != 0 && loopCount < 100 {
            loopCount += 1
            
            guard let sectorData = readD64Sector(data: data, track: currentTrack, sector: currentSector) else {
                break
            }
            
            // Ensure sector has enough data
            guard sectorData.count >= 2 else {
                break
            }
            
            // 8 entries per sector
            for entryIdx in 0..<8 {
                let entryOffset = 2 + (entryIdx * 32)
                guard entryOffset + 32 <= sectorData.count else { continue }
                
                let fileType = sectorData[entryOffset]
                if fileType == 0 || fileType == 0x80 { continue }
                
                // Filename (16 bytes)
                var fileName = ""
                for i in 0..<16 {
                    guard entryOffset + 3 + i < sectorData.count else { break }
                    let char = sectorData[entryOffset + 3 + i]
                    if char == 0xA0 || char == 0 { break }
                    fileName.append(Character(UnicodeScalar(char)))
                }
                if fileName.isEmpty { continue }
                
                let fileTrack = Int(sectorData[entryOffset + 1])
                let fileSector = Int(sectorData[entryOffset + 2])
                let sizeInSectors = Int(sectorData[entryOffset + 28]) | (Int(sectorData[entryOffset + 29]) << 8)
                
                if let fileData = extractD64File(data: data, startTrack: fileTrack, startSector: fileSector) {
                    let actualFileType = fileType & 0x07
                    let fileTypeString: String
                    switch actualFileType {
                    case 1: fileTypeString = "SEQ"
                    case 2: fileTypeString = "PRG"
                    case 3: fileTypeString = "USR"
                    case 4: fileTypeString = "REL"
                    default: fileTypeString = "???"
                    }
                    
                    // Check for graphics
                    let isGraphics = (fileData.count >= 9000 && fileData.count <= 10020)
                    var result: (image: CGImage?, type: AppleIIImageType) = (nil, .Unknown)
                    
                    if isGraphics {
                        result = SHRDecoder.decode(data: fileData, filename: fileName)
                    }
                    
                    let isImage = result.image != nil && result.type != .Unknown
                    
                    let entry = DiskCatalogEntry(
                        name: fileName,
                        fileType: actualFileType,
                        fileTypeString: fileTypeString,
                        size: fileData.count,
                        blocks: sizeInSectors,
                        loadAddress: nil,
                        length: nil,
                        data: fileData,
                        isImage: isImage,
                        imageType: result.type,
                        isDirectory: false,
                        children: nil
                    )
                    entries.append(entry)
                }
            }
            
            currentTrack = Int(sectorData[0])
            currentSector = Int(sectorData[1])
        }
        
        return DiskCatalog(
            diskName: diskName,
            diskFormat: "C64 D64",
            diskSize: data.count,
            entries: entries
        )
    }

    static func readADFCatalogFull(data: Data, filename: String) -> DiskCatalog? {
        // ADF sizes: 901120 (DD), 1802240 (HD)
        let validSizes = [901120, 1802240]
        guard validSizes.contains(data.count) else { return nil }

        let isDD = data.count == 901120
        let rootBlock = isDD ? 880 : 1760
        guard let rootData = readADFBlock(data: data, block: rootBlock) else { return nil }

        // Validate root block type (T_HEADER = 2) and secondary type (ST_ROOT = 1)
        let blockType = readADFLong(data: rootData, offset: 0)
        let secType = readADFLong(data: rootData, offset: 508)
        guard blockType == 2 && secType == 1 else { return nil }

        // Read disk name (offset 432, BCPL string)
        let diskName = readADFString(data: rootData, offset: 432, maxLength: 30)

        var entries: [DiskCatalogEntry] = []

        // Read hash table (72 entries starting at offset 24)
        for i in 0..<72 {
            let hashEntry = readADFLong(data: rootData, offset: 24 + (i * 4))
            if hashEntry == 0 { continue }

            // Follow hash chain and collect entries
            var currentBlock = Int(hashEntry)
            var visited = Set<Int>()

            while currentBlock != 0 && !visited.contains(currentBlock) {
                visited.insert(currentBlock)

                guard let headerData = readADFBlock(data: data, block: currentBlock) else { break }

                let headerType = readADFLong(data: headerData, offset: 0)
                let headerSecType = readADFLong(data: headerData, offset: 508)

                if headerType == 2 {
                    let entryName = readADFString(data: headerData, offset: 432, maxLength: 30)

                    if headerSecType == 0xFFFFFFFD {
                        // ST_FILE = -3 (0xFFFFFFFD)
                        let fileSize = Int(readADFLong(data: headerData, offset: 324))

                        // Extract file data
                        var fileData = Data()
                        var isImage = false
                        var imageType: AppleIIImageType = .Unknown

                        if let extracted = extractADFFile(data: data, headerBlock: currentBlock, headerData: headerData) {
                            fileData = extracted.data
                            let result = SHRDecoder.decode(data: fileData, filename: entryName)
                            if result.type != .Unknown && result.image != nil {
                                isImage = true
                                imageType = result.type
                            }
                        }

                        let entry = DiskCatalogEntry(
                            name: entryName,
                            fileType: 0,
                            fileTypeString: getADFFileExtension(name: entryName),
                            size: fileSize,
                            blocks: (fileSize + 511) / 512,
                            loadAddress: nil,
                            length: nil,
                            data: fileData,
                            isImage: isImage,
                            imageType: imageType,
                            isDirectory: false,
                            children: nil
                        )
                        entries.append(entry)

                    } else if headerSecType == 2 {
                        // ST_DIR = 2 (directory)
                        let subEntries = readADFDirectoryEntries(data: data, dirHeaderBlock: currentBlock, dirHeaderData: headerData)

                        let entry = DiskCatalogEntry(
                            name: entryName,
                            fileType: 0x0F,
                            fileTypeString: "DIR",
                            size: subEntries.reduce(0) { $0 + $1.size },
                            blocks: 1,
                            loadAddress: nil,
                            length: nil,
                            data: Data(),
                            isImage: false,
                            imageType: .Unknown,
                            isDirectory: true,
                            children: subEntries
                        )
                        entries.append(entry)
                    }
                }

                // Follow hash chain
                currentBlock = Int(readADFLong(data: headerData, offset: 504))
            }
        }

        return DiskCatalog(
            diskName: diskName.isEmpty ? filename : diskName,
            diskFormat: isDD ? "Amiga ADF (DD)" : "Amiga ADF (HD)",
            diskSize: data.count,
            entries: entries
        )
    }

    private static func readADFDirectoryEntries(data: Data, dirHeaderBlock: Int, dirHeaderData: Data) -> [DiskCatalogEntry] {
        var entries: [DiskCatalogEntry] = []

        // Read hash table from directory header
        for i in 0..<72 {
            let hashEntry = readADFLong(data: dirHeaderData, offset: 24 + (i * 4))
            if hashEntry == 0 { continue }

            var currentBlock = Int(hashEntry)
            var visited = Set<Int>()

            while currentBlock != 0 && !visited.contains(currentBlock) {
                visited.insert(currentBlock)

                guard let headerData = readADFBlock(data: data, block: currentBlock) else { break }

                let headerType = readADFLong(data: headerData, offset: 0)
                let headerSecType = readADFLong(data: headerData, offset: 508)

                if headerType == 2 {
                    let entryName = readADFString(data: headerData, offset: 432, maxLength: 30)

                    if headerSecType == 0xFFFFFFFD {
                        // File
                        let fileSize = Int(readADFLong(data: headerData, offset: 324))

                        var fileData = Data()
                        var isImage = false
                        var imageType: AppleIIImageType = .Unknown

                        if let extracted = extractADFFile(data: data, headerBlock: currentBlock, headerData: headerData) {
                            fileData = extracted.data
                            let result = SHRDecoder.decode(data: fileData, filename: entryName)
                            if result.type != .Unknown && result.image != nil {
                                isImage = true
                                imageType = result.type
                            }
                        }

                        let entry = DiskCatalogEntry(
                            name: entryName,
                            fileType: 0,
                            fileTypeString: getADFFileExtension(name: entryName),
                            size: fileSize,
                            blocks: (fileSize + 511) / 512,
                            loadAddress: nil,
                            length: nil,
                            data: fileData,
                            isImage: isImage,
                            imageType: imageType,
                            isDirectory: false,
                            children: nil
                        )
                        entries.append(entry)

                    } else if headerSecType == 2 {
                        // Subdirectory - recursive call
                        let subEntries = readADFDirectoryEntries(data: data, dirHeaderBlock: currentBlock, dirHeaderData: headerData)

                        let entry = DiskCatalogEntry(
                            name: entryName,
                            fileType: 0x0F,
                            fileTypeString: "DIR",
                            size: subEntries.reduce(0) { $0 + $1.size },
                            blocks: 1,
                            loadAddress: nil,
                            length: nil,
                            data: Data(),
                            isImage: false,
                            imageType: .Unknown,
                            isDirectory: true,
                            children: subEntries
                        )
                        entries.append(entry)
                    }
                }

                currentBlock = Int(readADFLong(data: headerData, offset: 504))
            }
        }

        return entries
    }

    private static func getADFFileExtension(name: String) -> String {
        let ext = (name as NSString).pathExtension.lowercased()
        switch ext {
        case "iff", "ilbm", "lbm": return "IFF"
        case "info": return "INFO"
        case "txt", "doc": return "TXT"
        case "exe", "": return "FILE"
        default: return ext.uppercased()
        }
    }

    // MARK: - Amstrad CPC DSK Catalog

    static func readCPCDSKCatalogFull(data: Data, filename: String) -> DiskCatalog? {
        // Check for CPC DSK signature
        guard data.count >= 256 else { return nil }

        let header = String(data: data.subdata(in: 0..<34), encoding: .ascii) ?? ""
        let isExtended = header.hasPrefix("EXTENDED CPC DSK File")
        let isStandard = header.hasPrefix("MV - CPC")

        guard isExtended || isStandard else { return nil }

        // Parse disk information block
        let numTracks = Int(data[48])
        let numSides = Int(data[49])

        guard numTracks > 0 && numSides > 0 else { return nil }

        // Get disk name from creator field (bytes 34-47)
        var diskName = ""
        for i in 34..<48 {
            if i < data.count {
                let char = data[i]
                if char > 32 && char < 127 {
                    diskName.append(Character(UnicodeScalar(char)))
                }
            }
        }
        diskName = diskName.trimmingCharacters(in: .whitespaces)
        if diskName.isEmpty {
            diskName = (filename as NSString).deletingPathExtension
        }

        var entries: [DiskCatalogEntry] = []

        // Build sector map
        var sectorMap: [Int: [Int: Data]] = [:]
        var offset = 256

        for track in 0..<numTracks {
            for side in 0..<numSides {
                let trackIndex = track * numSides + side

                var trackSize: Int
                if isExtended {
                    let sizeIndex = 52 + trackIndex
                    if sizeIndex < data.count {
                        trackSize = Int(data[sizeIndex]) * 256
                    } else {
                        continue
                    }
                } else {
                    trackSize = Int(data[50]) | (Int(data[51]) << 8)
                }

                if trackSize == 0 { continue }
                guard offset + trackSize <= data.count else { break }

                let trackData = data.subdata(in: offset..<(offset + trackSize))
                if trackData.count >= 24 {
                    let trackSig = String(data: trackData.subdata(in: 0..<12), encoding: .ascii) ?? ""
                    if trackSig.hasPrefix("Track-Info") {
                        // Use PHYSICAL track number from header for proper AMSDOS block mapping
                        let physicalTrack = Int(trackData[16])
                        let sectorCount = Int(trackData[21])
                        let sectorSizeCode = Int(trackData[20])
                        let defaultSectorSize = 128 << sectorSizeCode

                        if sectorMap[physicalTrack] == nil {
                            sectorMap[physicalTrack] = [:]
                        }

                        var sectorOffset = 256

                        for sectorIndex in 0..<sectorCount {
                            let infoOffset = 24 + (sectorIndex * 8)
                            guard infoOffset + 8 <= trackData.count else { break }

                            let sectorID = Int(trackData[infoOffset + 2])
                            var sectorSize = defaultSectorSize

                            if isExtended {
                                let actualSize = Int(trackData[infoOffset + 6]) | (Int(trackData[infoOffset + 7]) << 8)
                                if actualSize > 0 {
                                    sectorSize = actualSize
                                }
                            }

                            if sectorOffset + sectorSize <= trackData.count {
                                let sectorData = trackData.subdata(in: sectorOffset..<(sectorOffset + sectorSize))
                                sectorMap[physicalTrack]?[sectorID] = sectorData
                            }

                            sectorOffset += sectorSize
                        }
                    }
                }

                offset += trackSize
            }
        }

        // Read directory
        var directoryData = Data()

        for sectorID in [0xC1, 0xC2, 0xC3, 0xC4] {
            if let sectorData = sectorMap[0]?[sectorID] {
                directoryData.append(sectorData)
            }
        }

        if directoryData.isEmpty {
            for sectorID in [0x41, 0x42, 0x43, 0x44] {
                if let sectorData = sectorMap[0]?[sectorID] {
                    directoryData.append(sectorData)
                }
            }
        }

        if directoryData.isEmpty {
            for sectorID in 1...4 {
                if let sectorData = sectorMap[0]?[sectorID] {
                    directoryData.append(sectorData)
                }
            }
        }

        guard !directoryData.isEmpty else {
            return DiskCatalog(
                diskName: diskName,
                diskFormat: isExtended ? "Amstrad CPC DSK (Extended)" : "Amstrad CPC DSK",
                diskSize: data.count,
                entries: entries
            )
        }

        // Build linear sector list for block allocation
        // In AMSDOS DATA format: Block 0 starts at track 0 sector C5 (after directory C1-C4)
        // Use physical track numbers in order for proper block-to-sector mapping
        var linearSectors: [(track: Int, sectorID: Int)] = []

        // First: Track 0 data sectors (C5-C9, after directory)
        for sectorOffset in 4..<9 {  // C5-C9 (skip C1-C4 directory)
            let sectorID = 0xC1 + sectorOffset
            if sectorMap[0]?[sectorID] != nil {
                linearSectors.append((0, sectorID))
            }
        }

        // Then: Physical tracks 1-39 in order (some may be missing in incomplete disk images)
        for physTrack in 1..<40 {
            if let trackSectors = sectorMap[physTrack] {
                for sectorOffset in 0..<9 {  // C1-C9
                    let sectorID = 0xC1 + sectorOffset
                    if trackSectors[sectorID] != nil {
                        linearSectors.append((physTrack, sectorID))
                    }
                }
            }
        }

        // Parse directory entries
        var fileEntries: [String: [(extent: Int, blocks: [Int], recordCount: Int)]] = [:]

        for entryOffset in stride(from: 0, to: directoryData.count, by: 32) {
            guard entryOffset + 32 <= directoryData.count else { break }

            let userNumber = directoryData[entryOffset]
            if userNumber == 0xE5 { continue }
            if userNumber > 15 { continue }

            var fname = ""
            for i in 1...8 {
                let char = directoryData[entryOffset + i] & 0x7F
                if char > 32 && char < 127 {
                    fname.append(Character(UnicodeScalar(char)))
                }
            }
            fname = fname.trimmingCharacters(in: .whitespaces)

            var ext = ""
            for i in 9...11 {
                let char = directoryData[entryOffset + i] & 0x7F
                if char > 32 && char < 127 {
                    ext.append(Character(UnicodeScalar(char)))
                }
            }
            ext = ext.trimmingCharacters(in: .whitespaces)

            if !ext.isEmpty {
                fname += "." + ext
            }

            if fname.isEmpty { continue }

            let extentLow = Int(directoryData[entryOffset + 12])
            let extentHigh = Int(directoryData[entryOffset + 14])
            let extent = extentLow + (extentHigh * 32)
            let recordCount = Int(directoryData[entryOffset + 15])

            var blocks: [Int] = []
            for i in 0..<16 {
                let blockNum = Int(directoryData[entryOffset + 16 + i])
                if blockNum != 0 {
                    blocks.append(blockNum)
                }
            }

            if fileEntries[fname] == nil {
                fileEntries[fname] = []
            }
            fileEntries[fname]?.append((extent: extent, blocks: blocks, recordCount: recordCount))
        }

        // Extract files and create catalog entries using linear sector mapping
        let sectorsPerBlock = 2  // 1024 / 512
        let reservedBlocks = 2   // Blocks 0-1 are reserved for directory in DATA format

        for (filename, extents) in fileEntries {
            let sortedExtents = extents.sorted { $0.extent < $1.extent }

            var fileData = Data()
            var totalRecords = 0

            for extentInfo in sortedExtents {
                totalRecords += extentInfo.recordCount
                for blockNum in extentInfo.blocks {
                    // Block numbers in directory are absolute - subtract reserved blocks to get data index
                    guard blockNum >= reservedBlocks else { continue }
                    let firstSector = (blockNum - reservedBlocks) * sectorsPerBlock

                    for i in 0..<sectorsPerBlock {
                        let sectorIdx = firstSector + i
                        if sectorIdx >= 0 && sectorIdx < linearSectors.count {
                            let (track, sectorID) = linearSectors[sectorIdx]
                            if let sectorData = sectorMap[track]?[sectorID] {
                                fileData.append(sectorData)
                            }
                        }
                    }
                }
            }

            // Trim to actual file size (records * 128)
            let actualSize = totalRecords * 128
            if fileData.count > actualSize && actualSize > 0 {
                fileData = fileData.prefix(actualSize)
            }

            // Check if it's an image - for CPC disks, force CPC format for .SCR files
            var isImage = false
            var imageType: AppleIIImageType = .Unknown

            if !fileData.isEmpty {
                let fileExt = (filename as NSString).pathExtension.lowercased()

                // For .SCR files from CPC disks, always treat as CPC graphics (don't fall back to other formats)
                if fileExt == "scr" {
                    let cpcResult = RetroDecoder.decodeAmstradCPC(data: fileData)
                    if cpcResult.image != nil {
                        isImage = true
                        imageType = cpcResult.type
                    } else {
                        // Even if decoder fails, mark as CPC so it's recognized
                        isImage = true
                        imageType = .AmstradCPC(mode: 1, colors: 4)
                    }
                } else if fileData.count >= 16000 && fileData.count <= 17000 {
                    // For 16KB files without .SCR extension, try CPC first
                    let cpcResult = RetroDecoder.decodeAmstradCPC(data: fileData)
                    if cpcResult.image != nil && cpcResult.type != .Unknown {
                        isImage = true
                        imageType = cpcResult.type
                    }
                }

                // Fall back to general decoder only for non-.SCR files
                if !isImage {
                    let result = SHRDecoder.decode(data: fileData, filename: filename)
                    if result.type != .Unknown && result.image != nil {
                        isImage = true
                        imageType = result.type
                    }
                }
            }

            let ext = (filename as NSString).pathExtension.uppercased()
            let fileTypeString = ext.isEmpty ? "BIN" : ext

            let entry = DiskCatalogEntry(
                name: filename,
                fileType: 0,
                fileTypeString: fileTypeString,
                size: fileData.count,
                blocks: sortedExtents.flatMap { $0.blocks }.count,
                loadAddress: nil,
                length: nil,
                data: fileData,
                isImage: isImage,
                imageType: imageType,
                isDirectory: false,
                children: nil
            )
            entries.append(entry)
        }

        // Sort entries by name
        entries.sort { $0.name.lowercased() < $1.name.lowercased() }

        return DiskCatalog(
            diskName: diskName,
            diskFormat: isExtended ? "Amstrad CPC DSK (Extended)" : "Amstrad CPC DSK",
            diskSize: data.count,
            entries: entries
        )
    }

    static func readAtariSTCatalogFull(data: Data, filename: String) -> DiskCatalog? {
        let reader = AtariSTDiskReader()
        guard reader.canRead(data: data) else { return nil }

        guard let diskEntries = reader.readDisk(data: data) else { return nil }

        // Determine disk format string based on size
        let diskFormat: String
        switch data.count {
        case 360 * 1024:
            diskFormat = "Atari ST (360KB SS/DD)"
        case 400 * 1024:
            diskFormat = "Atari ST (400KB SS/DD)"
        case 720 * 1024:
            diskFormat = "Atari ST (720KB DS/DD)"
        case 800 * 1024:
            diskFormat = "Atari ST (800KB DS/DD)"
        case 1440 * 1024:
            diskFormat = "Atari ST (1.44MB DS/HD)"
        default:
            diskFormat = "Atari ST"
        }

        let diskName = (filename as NSString).deletingPathExtension

        var entries: [DiskCatalogEntry] = []

        for diskEntry in diskEntries {
            var isImage = false
            var imageType: AppleIIImageType = .Unknown

            let ext = (diskEntry.name as NSString).pathExtension.lowercased()

            // Try to decode as Atari ST image format
            if ["pi1", "pi2", "pi3", "pc1", "pc2", "pc3"].contains(ext) {
                let result = AtariSTDecoder.decode(data: diskEntry.data)
                if result.image != nil {
                    isImage = true
                    imageType = result.type
                }
            } else if ext == "neo" {
                let result = AtariSTDecoder.decodeNEOchrome(data: diskEntry.data)
                if result.image != nil {
                    isImage = true
                    imageType = result.type
                }
            } else if ["iff", "lbm"].contains(ext) {
                let result = AmigaIFFDecoder.decode(data: diskEntry.data)
                if result.image != nil {
                    isImage = true
                    imageType = result.type
                }
            } else {
                // Try general decode for unknown extensions
                let result = SHRDecoder.decode(data: diskEntry.data, filename: diskEntry.name)
                if result.type != AppleIIImageType.Unknown && result.image != nil {
                    isImage = true
                    imageType = result.type
                }
            }

            let fileTypeString = ext.isEmpty ? "BIN" : ext.uppercased()

            let entry = DiskCatalogEntry(
                name: diskEntry.name,
                fileType: 0,
                fileTypeString: fileTypeString,
                size: diskEntry.size,
                blocks: (diskEntry.size + 1023) / 1024,
                loadAddress: nil,
                length: nil,
                data: diskEntry.data,
                isImage: isImage,
                imageType: imageType,
                isDirectory: false,
                children: nil
            )
            entries.append(entry)
        }

        // Sort entries by name
        entries.sort { $0.name.lowercased() < $1.name.lowercased() }

        return DiskCatalog(
            diskName: diskName,
            diskFormat: diskFormat,
            diskSize: data.count,
            entries: entries
        )
    }

    static func readMSXCatalogFull(data: Data, filename: String) -> DiskCatalog? {
        let reader = MSXDiskReader()
        guard reader.canRead(data: data) else { return nil }

        guard let diskEntries = reader.readDisk(data: data) else { return nil }

        // Determine disk format string based on size
        let diskFormat: String
        switch data.count {
        case 360 * 1024:
            diskFormat = "MSX (360KB SS/DD)"
        case 720 * 1024:
            diskFormat = "MSX (720KB DS/DD)"
        default:
            diskFormat = "MSX FAT12"
        }

        // Extract disk name from filename
        let diskName = (filename as NSString).deletingPathExtension

        var entries: [DiskCatalogEntry] = []

        for diskEntry in diskEntries {
            var isImage = diskEntry.isImage
            var imageType = diskEntry.imageType

            let ext = (diskEntry.name as NSString).pathExtension.lowercased()

            // Try to decode as MSX image format
            if ["sc2", "grp", "sc5", "sc7", "sc8", "sr5", "sr7", "sr8", "ge5", "ge7", "ge8", "pic"].contains(ext) {
                let result = MSXDecoder.decode(data: diskEntry.data, filename: diskEntry.name)
                if result.image != nil {
                    isImage = true
                    imageType = result.type
                }
            } else {
                // Try general decode for unknown extensions
                let result = SHRDecoder.decode(data: diskEntry.data, filename: diskEntry.name)
                if result.type != AppleIIImageType.Unknown && result.image != nil {
                    isImage = true
                    imageType = result.type
                }
            }

            let fileTypeString = ext.isEmpty ? "BIN" : ext.uppercased()

            let entry = DiskCatalogEntry(
                name: diskEntry.name,
                fileType: 0,
                fileTypeString: fileTypeString,
                size: diskEntry.size,
                blocks: (diskEntry.size + 1023) / 1024,
                loadAddress: nil,
                length: nil,
                data: diskEntry.data,
                isImage: isImage,
                imageType: imageType,
                isDirectory: false,
                children: nil
            )
            entries.append(entry)
        }

        // Sort entries by name
        entries.sort { $0.name.lowercased() < $1.name.lowercased() }

        return DiskCatalog(
            diskName: diskName,
            diskFormat: diskFormat,
            diskSize: data.count,
            entries: entries
        )
    }

    static func readAtari8bitCatalogFull(data: Data, filename: String) -> DiskCatalog? {
        let reader = Atari8bitDiskReader()
        guard reader.canRead(data: data) else { return nil }

        guard let diskEntries = reader.readDisk(data: data) else { return nil }

        // Parse ATR header to get geometry info
        let sectorSize = Int(data[4]) | (Int(data[5]) << 8)
        let paragraphsLow = Int(data[2]) | (Int(data[3]) << 8)
        let paragraphsHigh = Int(data[6]) | (Int(data[7]) << 8)
        let totalBytes = (paragraphsLow | (paragraphsHigh << 16)) * 16

        // Determine disk format string based on size and sector size
        let diskFormat: String
        if sectorSize == 128 {
            if totalBytes <= 92160 {
                diskFormat = "Atari 8-bit ATR (90KB SD)"
            } else {
                diskFormat = "Atari 8-bit ATR (130KB ED)"
            }
        } else if sectorSize == 256 {
            diskFormat = "Atari 8-bit ATR (180KB DD)"
        } else {
            diskFormat = "Atari 8-bit ATR"
        }

        // Extract disk name from filename
        let diskName = (filename as NSString).deletingPathExtension

        var entries: [DiskCatalogEntry] = []

        for diskEntry in diskEntries {
            var isImage = diskEntry.isImage
            var imageType = diskEntry.imageType

            let ext = (diskEntry.name as NSString).pathExtension.lowercased()

            // Try to decode as Atari 8-bit image format
            if ["gr8", "gr9", "gr15", "gr7", "gr11", "gr1", "gr2", "gr3", "gr4", "gr5", "gr6", "mic", "pic"].contains(ext) {
                let result = Atari8bitDecoder.decode(data: diskEntry.data, filename: diskEntry.name)
                if result.image != nil {
                    isImage = true
                    imageType = result.type
                }
            } else {
                // Try general decode for unknown extensions
                let result = SHRDecoder.decode(data: diskEntry.data, filename: diskEntry.name)
                if result.type != AppleIIImageType.Unknown && result.image != nil {
                    isImage = true
                    imageType = result.type
                }
            }

            let fileTypeString = diskEntry.fileTypeString

            let entry = DiskCatalogEntry(
                name: diskEntry.name,
                fileType: 0,
                fileTypeString: fileTypeString,
                size: diskEntry.size,
                blocks: diskEntry.blocks,
                loadAddress: nil,
                length: nil,
                data: diskEntry.data,
                isImage: isImage,
                imageType: imageType,
                isDirectory: false,
                children: nil
            )
            entries.append(entry)
        }

        // Sort entries by name
        entries.sort { $0.name.lowercased() < $1.name.lowercased() }

        return DiskCatalog(
            diskName: diskName,
            diskFormat: diskFormat,
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
            // Try reading ProDOS catalog from DOS-ordered disk with sequential sector reading FIRST
            if let catalog = readProDOSCatalogFromDOSOrderSequential(data: data, filename: filename) {
                return catalog
            }

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

    /// Reads ProDOS catalog from a DOS-ordered disk by reading sequential DOS sectors
    /// This handles disks where the volume directory is stored at DOS sectors 11, 10, 9 (track 0)
    static func readProDOSCatalogFromDOSOrderSequential(data: Data, filename: String) -> DiskCatalog? {
        guard data.count == 143360 else { return nil }

        // Check for volume header at DOS sector 11 (offset 11*256 = 2816)
        let sector11Offset = 11 * 256
        guard sector11Offset + 256 <= data.count else { return nil }

        // Check if there's a ProDOS volume header at sector 11
        let storageType = (data[sector11Offset + 4] & 0xF0) >> 4
        guard storageType == 0x0F else { return nil }

        let volumeNameLength = Int(data[sector11Offset + 4] & 0x0F)
        guard volumeNameLength > 0 && volumeNameLength <= 15 else { return nil }

        // Validate volume name contains only valid ProDOS characters (A-Z, 0-9, .)
        var volumeName = ""
        for i in 0..<volumeNameLength {
            let char = data[sector11Offset + 5 + i]
            // ProDOS names: uppercase letters A-Z (0x41-0x5A), digits 0-9 (0x30-0x39), period (0x2E)
            if (char >= 0x41 && char <= 0x5A) || (char >= 0x30 && char <= 0x39) || char == 0x2E {
                volumeName.append(Character(UnicodeScalar(char)))
            } else {
                return nil  // Invalid character in volume name - not a ProDOS disk
            }
        }

        // Read expected file count from volume header
        let expectedFileCount = Int(data[sector11Offset + 0x25]) | (Int(data[sector11Offset + 0x26]) << 8)
        guard expectedFileCount < 1000 else { return nil }  // Sanity check

        var entries: [DiskCatalogEntry] = []

        // Read directory entries from DOS sectors 11, 10, 9, 8... (descending)
        // First block: sectors 11 + 10 combined (512 bytes)
        // Continuation: sectors 9 + 8, etc.
        var currentDosSector = 11
        var isFirstBlock = true

        for _ in 0..<10 {
            guard currentDosSector >= 0 else { break }

            // Read two consecutive sectors as a 512-byte block
            // Use descending order: sector N, then sector N-1
            let sector1Offset = currentDosSector * 256
            let sector2Offset = (currentDosSector - 1) * 256
            guard sector1Offset + 256 <= data.count && sector2Offset + 256 <= data.count else { break }

            // Combine into a 512-byte block (sector N first, then N-1)
            var blockData = Data()
            blockData.append(contentsOf: data[sector1Offset..<(sector1Offset + 256)])
            blockData.append(contentsOf: data[sector2Offset..<(sector2Offset + 256)])

            // Get next block pointer
            let nextBlock = Int(blockData[2]) | (Int(blockData[3]) << 8)

            // Parse directory entries
            let entryStart = isFirstBlock ? (4 + 39) : 4  // Skip volume header in first block
            let maxEntries = isFirstBlock ? 12 : 13

            for entryIdx in 0..<maxEntries {
                let entryOffset = entryStart + (entryIdx * 39)
                guard entryOffset + 39 <= blockData.count else { break }

                let entryStorageType = (blockData[entryOffset] & 0xF0) >> 4
                if entryStorageType == 0 { continue }
                if entryStorageType == 0x0D { continue }  // Skip subdirectories for now

                let nameLength = Int(blockData[entryOffset] & 0x0F)
                guard nameLength > 0 && nameLength <= 15 else { continue }

                var fileName = ""
                for i in 0..<nameLength {
                    fileName.append(Character(UnicodeScalar(blockData[entryOffset + 1 + i])))
                }

                // Skip if already added
                if entries.contains(where: { $0.name == fileName }) { continue }

                let fileType = blockData[entryOffset + 16]
                let keyPointer = Int(blockData[entryOffset + 17]) | (Int(blockData[entryOffset + 18]) << 8)
                let blocksUsed = Int(blockData[entryOffset + 19]) | (Int(blockData[entryOffset + 20]) << 8)
                let eof = Int(blockData[entryOffset + 21]) | (Int(blockData[entryOffset + 22]) << 8) | (Int(blockData[entryOffset + 23]) << 16)
                let auxType = entryOffset + 33 <= blockData.count ? Int(blockData[entryOffset + 31]) | (Int(blockData[entryOffset + 32]) << 8) : 0

                // Extract file data using direct block addressing
                let fileData = extractProDOSFileFromDOSOrderDisk(data: data, keyBlock: keyPointer, blocksUsed: blocksUsed, eof: eof, storageType: Int(entryStorageType)) ?? Data()

                let isPNTorPIC = (fileType == 0xC0 || fileType == 0xC1)
                let hasGraphicsSize = (
                    eof == 8184 || eof == 8192 || eof == 8196 ||
                    (eof >= 8180 && eof <= 8200) ||  // HGR range
                    eof == 16384 || eof == 16388 ||
                    (eof >= 16380 && eof <= 16400) ||  // DHGR range
                    eof == 32768 || eof == 32772 || eof == 33024 ||
                    (eof >= 32760 && eof <= 33030)  // SHR range
                )
                let hasGraphicsAuxType = (auxType == 0x2000 || auxType == 0x4000)
                // Check for .3201 extension (Compressed 3200-Color Image)
                let has3201Extension = fileName.lowercased().contains(".3201")
                let couldBeGraphics = isPNTorPIC || ((fileType == 0x04 || fileType == 0x06) && (hasGraphicsSize || hasGraphicsAuxType || has3201Extension))

                var result: (image: CGImage?, type: AppleIIImageType) = (nil, .Unknown)
                if couldBeGraphics && !fileData.isEmpty {
                    // For BIN files ($06), check if there's a 4-byte header to strip
                    var dataToDecode = fileData
                    if fileType == 0x06 && fileData.count >= 4 {
                        let loadAddr = Int(fileData[0]) | (Int(fileData[1]) << 8)
                        let length = Int(fileData[2]) | (Int(fileData[3]) << 8)
                        // Check for typical HGR/DHGR load addresses
                        if (loadAddr == 0x2000 || loadAddr == 0x4000) && length > 0 && length <= fileData.count - 4 {
                            dataToDecode = fileData.subdata(in: 4..<fileData.count)
                        }
                    }
                    // Construct filename with ProDOS type info (e.g., "FILENAME#c00001")
                    let filenameWithType = String(format: "%@#%02x%04x", fileName, fileType, auxType)
                    result = SHRDecoder.decode(data: dataToDecode, filename: filenameWithType)
                }

                let isImage = result.image != nil && result.type != .Unknown

                let entry = DiskCatalogEntry(
                    name: fileName,
                    fileType: fileType,
                    fileTypeString: ProDOSFileTypeInfo.getFileTypeInfo(fileType: fileType, auxType: auxType).shortName,
                    size: eof,
                    blocks: blocksUsed,
                    loadAddress: auxType,
                    length: nil,
                    data: fileData,
                    isImage: isImage,
                    imageType: result.type,
                    isDirectory: false,
                    children: nil
                )
                entries.append(entry)
            }

            isFirstBlock = false

            // Follow the chain or continue sequentially
            if nextBlock == 0 {
                break
            } else if nextBlock == 3 {
                // Special case: next=3 means continue at DOS sector 9
                currentDosSector = 9
            } else {
                // Move to next pair of sectors (descending)
                currentDosSector -= 2
            }
        }

        if !entries.isEmpty {
            return DiskCatalog(
                diskName: volumeName.isEmpty ? filename : volumeName,
                diskFormat: "ProDOS (DOS order)",
                diskSize: data.count,
                entries: entries
            )
        }

        return nil
    }

    /// ProDOS to DOS sector interleave mapping (standard)
    private static let prodosToDOSSector: [Int] = [
        0, 13, 11, 9, 7, 5, 3, 1, 14, 12, 10, 8, 6, 4, 2, 15
    ]

    /// Reversed interleave mapping (for some non-standard disks)
    private static let prodosToDOSSectorReversed: [Int] = [
        0, 14, 13, 12, 11, 10, 9, 8, 7, 6, 5, 4, 3, 2, 1, 15
    ]

    /// Reads a ProDOS block from a DOS-ordered disk using interleave mapping
    /// ProDOS block N maps to two physical sectors based on interleave table
    static func readProDOSBlockFromDOSOrderDiskInterleaved(data: Data, block: Int) -> Data? {
        return readProDOSBlockWithInterleave(data: data, block: block, interleaveTable: prodosToDOSSector)
    }

    /// Reads a ProDOS block using reversed interleave (for non-standard disks)
    static func readProDOSBlockFromDOSOrderDiskReversedInterleave(data: Data, block: Int) -> Data? {
        return readProDOSBlockWithInterleave(data: data, block: block, interleaveTable: prodosToDOSSectorReversed)
    }

    /// Helper to read a block using any interleave table
    private static func readProDOSBlockWithInterleave(data: Data, block: Int, interleaveTable: [Int]) -> Data? {
        guard data.count == 143360 else { return nil }
        guard block < 280 else { return nil }  // Max blocks in 140KB disk

        let sectorsPerTrack = 16
        let sectorSize = 256

        // Calculate track and logical sectors for this block
        let sectorsTotal = block * 2
        let track = sectorsTotal / sectorsPerTrack
        let logicalSector1 = sectorsTotal % sectorsPerTrack
        let logicalSector2 = (sectorsTotal + 1) % sectorsPerTrack
        let track2 = (sectorsTotal + 1) / sectorsPerTrack

        // Apply interleave mapping
        let physSector1 = interleaveTable[logicalSector1]
        let physSector2 = interleaveTable[logicalSector2]

        let offset1 = (track * sectorsPerTrack + physSector1) * sectorSize
        let offset2 = (track2 * sectorsPerTrack + physSector2) * sectorSize

        guard offset1 + sectorSize <= data.count && offset2 + sectorSize <= data.count else { return nil }

        var blockData = Data()
        blockData.append(contentsOf: data[offset1..<(offset1 + sectorSize)])
        blockData.append(contentsOf: data[offset2..<(offset2 + sectorSize)])
        return blockData
    }

    /// Reads a ProDOS block directly from a DOS-ordered disk (no interleave)
    /// This is for disks where file data is stored at direct block offsets
    static func readProDOSBlockFromDOSOrderDiskDirect(data: Data, block: Int) -> Data? {
        guard data.count == 143360 else { return nil }
        guard block < 280 else { return nil }  // Max blocks in 140KB disk

        let blockSize = 512
        let offset = block * blockSize

        guard offset + blockSize <= data.count else { return nil }

        var blockData = Data()
        blockData.append(contentsOf: data[offset..<(offset + blockSize)])
        return blockData
    }

    /// Extracts a ProDOS file from a DOS-ordered disk
    /// Tries multiple methods: reversed interleave, standard interleave, direct, and contiguous
    static func extractProDOSFileFromDOSOrderDisk(data: Data, keyBlock: Int, blocksUsed: Int, eof: Int, storageType: Int) -> Data? {
        // Try reversed interleave first (works for some non-standard disks like hgrbyte)
        if let fileData = extractProDOSFileWithInterleaveMethod(data: data, keyBlock: keyBlock, eof: eof, storageType: storageType, interleaveTable: prodosToDOSSectorReversed) {
            return fileData
        }

        // Try standard interleaved reading (standard ProDOS on DOS-ordered disk)
        if let fileData = extractProDOSFileWithInterleaveMethod(data: data, keyBlock: keyBlock, eof: eof, storageType: storageType, interleaveTable: prodosToDOSSector) {
            return fileData
        }

        // Try direct block addressing
        if let fileData = extractProDOSFileWithMethod(data: data, keyBlock: keyBlock, eof: eof, storageType: storageType, useInterleave: false) {
            return fileData
        }

        // Fallback: Try contiguous storage (some disks store sapling files contiguously)
        if storageType == 2 || storageType == 3 {
            return extractContiguousFile(data: data, keyBlock: keyBlock, eof: eof)
        }

        return nil
    }

    /// Extract file using a specific interleave table
    private static func extractProDOSFileWithInterleaveMethod(data: Data, keyBlock: Int, eof: Int, storageType: Int, interleaveTable: [Int]) -> Data? {
        var fileData = Data()

        let readBlock: (Int) -> Data? = { block in
            return readProDOSBlockWithInterleave(data: data, block: block, interleaveTable: interleaveTable)
        }

        switch storageType {
        case 1: // Seedling - single block
            guard let blockData = readBlock(keyBlock) else { return nil }
            fileData.append(blockData)

        case 2: // Sapling - index block points to data blocks
            guard let indexBlock = readBlock(keyBlock) else { return nil }

            // Validate index block - check if high bytes are reasonable
            var hasValidIndexEntries = false
            for i in 0..<256 {
                let highByte = Int(indexBlock[i + 256])
                if highByte > 1 {
                    return nil  // Invalid index block for this method
                }
                let blockNum = Int(indexBlock[i]) | (highByte << 8)
                if blockNum > 0 && blockNum < 280 {
                    hasValidIndexEntries = true
                }
            }

            if !hasValidIndexEntries { return nil }

            // Read data blocks
            for i in 0..<256 {
                let blockNum = Int(indexBlock[i]) | (Int(indexBlock[i + 256]) << 8)
                if blockNum == 0 { continue }
                if blockNum >= 280 { continue }
                guard let blockData = readBlock(blockNum) else { continue }
                fileData.append(blockData)
                if fileData.count >= eof { break }
            }

        case 3: // Tree - master index block points to index blocks
            guard let masterIndex = readBlock(keyBlock) else { return nil }

            for i in 0..<128 {
                let indexBlockNum = Int(masterIndex[i]) | (Int(masterIndex[i + 256]) << 8)
                if indexBlockNum == 0 { continue }
                if indexBlockNum >= 280 { return nil }

                guard let indexBlock = readBlock(indexBlockNum) else { continue }

                for j in 0..<256 {
                    let blockNum = Int(indexBlock[j]) | (Int(indexBlock[j + 256]) << 8)
                    if blockNum == 0 { continue }
                    if blockNum >= 280 { continue }
                    guard let blockData = readBlock(blockNum) else { continue }
                    fileData.append(blockData)
                    if fileData.count >= eof { break }
                }

                if fileData.count >= eof { break }
            }

        default:
            return nil
        }

        // Trim to EOF
        if eof > 0 && eof < fileData.count {
            fileData = fileData.prefix(eof)
        }

        return fileData.isEmpty ? nil : fileData
    }

    /// Extracts a file stored contiguously starting at keyBlock
    private static func extractContiguousFile(data: Data, keyBlock: Int, eof: Int) -> Data? {
        var fileData = Data()
        let blocksNeeded = (eof + 511) / 512

        for i in 0..<blocksNeeded {
            let block = keyBlock + i
            if block >= 280 { break }

            if let blockData = readProDOSBlockFromDOSOrderDiskDirect(data: data, block: block) {
                fileData.append(blockData)
            } else {
                break
            }
        }

        if eof > 0 && eof < fileData.count {
            fileData = fileData.prefix(eof)
        }

        return fileData.isEmpty ? nil : fileData
    }

    /// Helper function to extract a file using either interleaved or direct block reading
    private static func extractProDOSFileWithMethod(data: Data, keyBlock: Int, eof: Int, storageType: Int, useInterleave: Bool) -> Data? {
        var fileData = Data()

        let readBlock: (Int) -> Data? = { block in
            if useInterleave {
                return readProDOSBlockFromDOSOrderDiskInterleaved(data: data, block: block)
            } else {
                return readProDOSBlockFromDOSOrderDiskDirect(data: data, block: block)
            }
        }

        switch storageType {
        case 1: // Seedling - single block
            guard let blockData = readBlock(keyBlock) else { return nil }
            fileData.append(blockData)

        case 2: // Sapling - index block points to data blocks
            guard let indexBlock = readBlock(keyBlock) else { return nil }

            // Validate index block - check if high bytes are reasonable (all zero or small values)
            var hasValidIndexEntries = false
            var validBlockCount = 0
            for i in 0..<256 {
                let lowByte = Int(indexBlock[i])
                let highByte = Int(indexBlock[i + 256])
                let blockNum = lowByte | (highByte << 8)

                // High bytes should be 0 or 1 for valid 140KB disk (max block 279)
                if highByte > 1 {
                    return nil  // Invalid index block for this method
                }

                if blockNum > 0 && blockNum < 280 {
                    hasValidIndexEntries = true
                    validBlockCount += 1
                }
            }

            if !hasValidIndexEntries { return nil }

            // Read data blocks
            for i in 0..<256 {
                let blockNum = Int(indexBlock[i]) | (Int(indexBlock[i + 256]) << 8)
                if blockNum == 0 { continue }
                if blockNum >= 280 { continue }  // Skip invalid block numbers
                guard let blockData = readBlock(blockNum) else { continue }
                fileData.append(blockData)

                // Stop if we've read enough
                if fileData.count >= eof { break }
            }

        case 3: // Tree - master index block points to index blocks
            guard let masterIndex = readBlock(keyBlock) else { return nil }

            for i in 0..<128 {
                let indexBlockNum = Int(masterIndex[i]) | (Int(masterIndex[i + 256]) << 8)
                if indexBlockNum == 0 { continue }
                if indexBlockNum >= 280 { return nil }  // Invalid for this method

                guard let indexBlock = readBlock(indexBlockNum) else { continue }

                for j in 0..<256 {
                    let blockNum = Int(indexBlock[j]) | (Int(indexBlock[j + 256]) << 8)
                    if blockNum == 0 { continue }
                    if blockNum >= 280 { continue }
                    guard let blockData = readBlock(blockNum) else { continue }
                    fileData.append(blockData)

                    if fileData.count >= eof { break }
                }

                if fileData.count >= eof { break }
            }

        default:
            return nil
        }

        // Trim to EOF
        if eof > 0 && eof < fileData.count {
            fileData = fileData.prefix(eof)
        }

        return fileData.isEmpty ? nil : fileData
    }
}
