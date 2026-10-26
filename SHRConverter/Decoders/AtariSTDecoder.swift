import Foundation
import CoreGraphics

// MARK: - Atari ST Image Decoder
// Supports Degas (.PI1, .PI2, .PI3), Degas Elite (.PC1, .PC2, .PC3), and NEOchrome (.NEO)

class AtariSTDecoder {

    // MARK: - General Decode

    static func decode(data: Data) -> (image: CGImage?, type: AppleIIImageType) {
        // Try Degas format first (most common)
        let degasResult = decodeDegas(data: data)
        if degasResult.image != nil {
            return degasResult
        }

        // Try NEOchrome
        let neoResult = decodeNEOchrome(data: data)
        if neoResult.image != nil {
            return neoResult
        }

        return (nil, .Unknown)
    }

    /// High resolution is black and white on the ST whatever the palette says; bit 0 of the
    /// first palette word only decides which of the two is the background.
    static func monochromeColors(firstPaletteWord: UInt16) -> [(r: UInt8, g: UInt8, b: UInt8)] {
        let white: (r: UInt8, g: UInt8, b: UInt8) = (255, 255, 255)
        let black: (r: UInt8, g: UInt8, b: UInt8) = (0, 0, 0)
        return (firstPaletteWord & 1) != 0 ? [white, black] : [black, white]
    }

    // MARK: - Degas Format

    static func decodeDegas(data: Data) -> (image: CGImage?, type: AppleIIImageType) {
        guard data.count >= 34 else {
            return (nil, .Unknown)
        }
        
        let resolutionMode = Int(ImageHelpers.readBigEndianUInt16(data: data, offset: 0))
        
        let width: Int
        let height: Int
        let numPlanes: Int
        let numColors: Int
        let resolutionName: String
        
        switch resolutionMode {
        case 0:
            width = 320
            height = 200
            numPlanes = 4
            numColors = 16
            resolutionName = "Low"
            
        case 1:
            width = 640
            height = 200
            numPlanes = 2
            numColors = 4
            resolutionName = "Medium"
            
        case 2:
            width = 640
            height = 400
            numPlanes = 1
            numColors = 2
            resolutionName = "High"
            
        default:
            return (nil, .Unknown)
        }
        
        // Read palette
        var palette: [(r: UInt8, g: UInt8, b: UInt8)] = []
        for i in 0..<16 {
            let colorWord = ImageHelpers.readBigEndianUInt16(data: data, offset: 2 + (i * 2))
            
            let r4 = (colorWord >> 8) & 0x07
            let g4 = (colorWord >> 4) & 0x07
            let b4 = colorWord & 0x07
            
            let r = UInt8((Int(r4) * 255) / 7)
            let g = UInt8((Int(g4) * 255) / 7)
            let b = UInt8((Int(b4) * 255) / 7)
            
            palette.append((r, g, b))
        }
        
        if numPlanes == 1 {
            let mono = monochromeColors(firstPaletteWord: ImageHelpers.readBigEndianUInt16(data: data, offset: 2))
            palette[0] = mono[0]
            palette[1] = mono[1]
        }

        let imageDataOffset = 34
        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)
        
        let wordsPerLine = width / 16
        let bytesPerLine = wordsPerLine * numPlanes * 2
        
        for y in 0..<height {
            let lineOffset = imageDataOffset + (y * bytesPerLine)
            
            for wordIdx in 0..<wordsPerLine {
                var planeWords: [UInt16] = []
                for plane in 0..<numPlanes {
                    let offset = lineOffset + (wordIdx * numPlanes * 2) + (plane * 2)
                    if offset + 1 < data.count {
                        planeWords.append(ImageHelpers.readBigEndianUInt16(data: data, offset: offset))
                    } else {
                        planeWords.append(0)
                    }
                }
                
                for bit in 0..<16 {
                    let x = wordIdx * 16 + bit
                    if x >= width { break }
                    
                    let bitPos = 15 - bit
                    var colorIndex = 0
                    
                    for plane in 0..<numPlanes {
                        let bitVal = (planeWords[plane] >> bitPos) & 1
                        colorIndex |= Int(bitVal) << plane
                    }
                    
                    let color = palette[colorIndex]
                    let bufferIdx = (y * width + x) * 4
                    
                    rgbaBuffer[bufferIdx] = color.r
                    rgbaBuffer[bufferIdx + 1] = color.g
                    rgbaBuffer[bufferIdx + 2] = color.b
                    rgbaBuffer[bufferIdx + 3] = 255
                }
            }
        }
        
        guard let cgImage = ImageHelpers.createCGImage(from: rgbaBuffer, width: width, height: height) else {
            return (nil, .Unknown)
        }
        
        return (cgImage, .DEGAS(resolution: resolutionName, colors: numColors))
    }

    // MARK: - NEOchrome Format

    static func decodeNEOchrome(data: Data) -> (image: CGImage?, type: AppleIIImageType) {
        // NEOchrome format: 128 bytes header + 32000 bytes image data = 32128 bytes
        guard data.count == 32128 else {
            return (nil, .Unknown)
        }

        // Header structure:
        // Bytes 0-1: Flag (0 = normal)
        // Bytes 2-3: Resolution (0=Low, 1=Medium, 2=High)
        // Bytes 4-35: Palette (16 colors, 2 bytes each)
        // Bytes 36-47: Filename (12 chars)
        // Bytes 48-49: Color animation limits
        // Bytes 50-51: Color animation speed
        // Bytes 52-53: Number of color animation steps
        // Bytes 54-127: Reserved

        let resolution = Int(ImageHelpers.readBigEndianUInt16(data: data, offset: 2))

        let width: Int
        let height: Int
        let numPlanes: Int
        let numColors: Int

        switch resolution {
        case 0:
            width = 320
            height = 200
            numPlanes = 4
            numColors = 16

        case 1:
            width = 640
            height = 200
            numPlanes = 2
            numColors = 4

        case 2:
            width = 640
            height = 400
            numPlanes = 1
            numColors = 2

        default:
            return (nil, .Unknown)
        }

        // Read palette (16 colors starting at offset 4)
        var palette: [(r: UInt8, g: UInt8, b: UInt8)] = []
        for i in 0..<16 {
            let colorWord = ImageHelpers.readBigEndianUInt16(data: data, offset: 4 + (i * 2))

            // ST palette format: 0x0RGB (3 bits each)
            let r3 = (colorWord >> 8) & 0x07
            let g3 = (colorWord >> 4) & 0x07
            let b3 = colorWord & 0x07

            let r = UInt8((Int(r3) * 255) / 7)
            let g = UInt8((Int(g3) * 255) / 7)
            let b = UInt8((Int(b3) * 255) / 7)

            palette.append((r, g, b))
        }

        if numPlanes == 1 {
            let mono = monochromeColors(firstPaletteWord: ImageHelpers.readBigEndianUInt16(data: data, offset: 4))
            palette[0] = mono[0]
            palette[1] = mono[1]
        }

        // Image data starts at offset 128
        let imageDataOffset = 128
        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)

        let wordsPerLine = width / 16
        let bytesPerLine = wordsPerLine * numPlanes * 2

        for y in 0..<height {
            let lineOffset = imageDataOffset + (y * bytesPerLine)

            for wordIdx in 0..<wordsPerLine {
                var planeWords: [UInt16] = []
                for plane in 0..<numPlanes {
                    let offset = lineOffset + (wordIdx * numPlanes * 2) + (plane * 2)
                    if offset + 1 < data.count {
                        planeWords.append(ImageHelpers.readBigEndianUInt16(data: data, offset: offset))
                    } else {
                        planeWords.append(0)
                    }
                }

                for bit in 0..<16 {
                    let x = wordIdx * 16 + bit
                    if x >= width { break }

                    let bitPos = 15 - bit
                    var colorIndex = 0

                    for plane in 0..<numPlanes {
                        let bitVal = (planeWords[plane] >> bitPos) & 1
                        colorIndex |= Int(bitVal) << plane
                    }

                    let color = palette[min(colorIndex, palette.count - 1)]
                    let bufferIdx = (y * width + x) * 4

                    rgbaBuffer[bufferIdx] = color.r
                    rgbaBuffer[bufferIdx + 1] = color.g
                    rgbaBuffer[bufferIdx + 2] = color.b
                    rgbaBuffer[bufferIdx + 3] = 255
                }
            }
        }

        guard let cgImage = ImageHelpers.createCGImage(from: rgbaBuffer, width: width, height: height) else {
            return (nil, .Unknown)
        }

        return (cgImage, .NEOchrome(colors: numColors))
    }

    // MARK: - Art Director, GFA Artist, Doodle and Palette Master

    typealias RGB = (r: UInt8, g: UInt8, b: UInt8)

    /// Converts an ST palette word (0x0RGB, 3 bits per channel) to 8-bit RGB
    static func stColor(_ word: UInt16) -> RGB {
        let scale = { (v: UInt16) in UInt8(Int(v & 0x07) * 255 / 7) }
        return (scale(word >> 8), scale(word >> 4), scale(word))
    }

    private static func stPalette(_ data: Data, offset: Int) -> [RGB] {
        (0..<16).map { stColor(ImageHelpers.readBigEndianUInt16(data: data, offset: offset + $0 * 2)) }
    }

    /// True when the 16 words at `offset` are all valid ST colors (only the low 12 bits used)
    private static func isSTPalette(_ data: Data, offset: Int) -> Bool {
        guard offset + 32 <= data.count else { return false }
        return (0..<16).allSatisfy { ImageHelpers.readBigEndianUInt16(data: data, offset: offset + $0 * 2) <= 0x0FFF }
    }

    /// Art Director: 32000-byte screen, then 8 palettes; the byte at $7E1F picks the one in use
    private static func artDirectorPaletteOffset(_ data: Data) -> Int? {
        guard data.count == 32512, data[0x7E1F] < 8 else { return nil }
        let offset = 32000 + Int(data[0x7E1F]) * 32
        return isSTPalette(data, offset: offset) ? offset : nil
    }

    /// The picture formats this section knows, identified by layout (and extension where the
    /// layout alone is too common to be sure)
    private enum ExtraFormat {
        case artDirector(paletteOffset: Int)
        case gfaArtist      // 16-color palette, then a 32000-byte screen (32032 bytes)
        case doodle         // 640x400 mono screen (32000 bytes), only taken by extension
        case paletteMaster  // screen plus palette changes down the picture (36864 bytes)
    }

    private static func extraFormat(_ data: Data, fileExtension: String) -> ExtraFormat? {
        switch data.count {
        case 32512:
            return artDirectorPaletteOffset(data).map { .artDirector(paletteOffset: $0) }
        case 32032 where ["art", "bil"].contains(fileExtension) && isSTPalette(data, offset: 0):
            return .gfaArtist
        case 32000 where ["art", "doo"].contains(fileExtension):
            return .doodle
        case 36864 where data[0x8C80] == 0xFF && data[0x8C81] == 0xFF && isSTPalette(data, offset: 0x8000):
            return .paletteMaster
        default:
            return nil
        }
    }

    /// Format name for disk catalogs, or nil when the data is none of these formats
    static func extraFormatName(data: Data, fileExtension: String) -> String? {
        switch extraFormat(data, fileExtension: fileExtension) {
        case .artDirector: return "Art Director"
        case .gfaArtist: return "GFA Artist"
        case .doodle: return "Doodle"
        case .paletteMaster: return "Palette Master"
        case nil: return nil
        }
    }

    /// The palette the palette editor shows; nil for Palette Master, whose colors change down the picture
    static func extraFormatPalette(data: Data, fileExtension: String) -> [RGB]? {
        switch extraFormat(data, fileExtension: fileExtension) {
        case .artDirector(let offset): return stPalette(data, offset: offset)
        case .gfaArtist: return stPalette(data, offset: 0)
        case .doodle: return [(255, 255, 255), (0, 0, 0)]
        case .paletteMaster, nil: return nil
        }
    }

    static func decodeExtraFormats(data: Data, fileExtension: String) -> (image: CGImage?, type: AppleIIImageType) {
        switch extraFormat(data, fileExtension: fileExtension) {
        case .artDirector(let offset):
            let palette = stPalette(data, offset: offset)
            return (renderLowRes(data, bitmapOffset: 0) { _ in palette },
                    .AtariSTPicture(format: "Art Director", width: 320, height: 200, colors: 16))
        case .gfaArtist:
            let palette = stPalette(data, offset: 0)
            return (renderLowRes(data, bitmapOffset: 32) { _ in palette },
                    .AtariSTPicture(format: "GFA Artist", width: 320, height: 200, colors: 16))
        case .doodle:
            return (renderMono640x400(data), .AtariSTPicture(format: "Doodle", width: 640, height: 400, colors: 2))
        case .paletteMaster:
            return (renderLowRes(data, bitmapOffset: 0, palettes: paletteMasterPalettes(data)),
                    .AtariSTPicture(format: "Palette Master", width: 320, height: 200, colors: 512))
        case nil:
            return (nil, .Unknown)
        }
    }

    /// Palette Master: line 0 uses the palette at $8000. From $8020 come 32-byte records
    /// (line number word, then colors 1-15) that change the palette from that line on.
    private static func paletteMasterPalettes(_ data: Data) -> (Int) -> [RGB] {
        var palettes: [[RGB]] = []
        var palette = stPalette(data, offset: 0x8000)
        var record = 0x8020
        for y in 0..<200 {
            if y > 0, record < 0x9000, data[record] == 0, Int(data[record + 1]) == y {
                for c in 1..<16 {
                    palette[c] = stColor(ImageHelpers.readBigEndianUInt16(data: data, offset: record + c * 2))
                }
                record += 32
            }
            palettes.append(palette)
        }
        return { palettes[$0] }
    }

    /// Low resolution 320x200: groups of four interleaved bitplane words, 16 pixels per group
    private static func renderLowRes(_ data: Data, bitmapOffset: Int, palettes: (Int) -> [RGB]) -> CGImage? {
        let width = 320, height = 200
        guard bitmapOffset + 32000 <= data.count else { return nil }
        var rgba = [UInt8](repeating: 0, count: width * height * 4)
        for y in 0..<height {
            let palette = palettes(y)
            for group in 0..<(width / 16) {
                let offset = bitmapOffset + y * 160 + group * 8
                let planes = (0..<4).map { ImageHelpers.readBigEndianUInt16(data: data, offset: offset + $0 * 2) }
                for bit in 0..<16 {
                    var colorIndex = 0
                    for plane in 0..<4 {
                        colorIndex |= Int((planes[plane] >> (15 - bit)) & 1) << plane
                    }
                    let color = palette[colorIndex]
                    let index = (y * width + group * 16 + bit) * 4
                    rgba[index] = color.r
                    rgba[index + 1] = color.g
                    rgba[index + 2] = color.b
                    rgba[index + 3] = 255
                }
            }
        }
        return ImageHelpers.createCGImage(from: rgba, width: width, height: height)
    }

    /// 640x400 mono: a set bit is black on a white background
    private static func renderMono640x400(_ data: Data) -> CGImage? {
        let width = 640, height = 400
        guard data.count >= 32000 else { return nil }
        var rgba = [UInt8](repeating: 255, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width where (data[y * 80 + x / 8] >> (7 - x % 8)) & 1 == 1 {
                let index = (y * width + x) * 4
                rgba[index] = 0
                rgba[index + 1] = 0
                rgba[index + 2] = 0
            }
        }
        return ImageHelpers.createCGImage(from: rgba, width: width, height: height)
    }
}
