import Foundation
import CoreGraphics
import ImageIO
import AppKit

// MARK: - SHRDecoder - Main Entry Point

class SHRDecoder {
    
    static func decode(data: Data, filename: String? = nil) -> (image: CGImage?, type: AppleIIImageType) {
        let size = data.count
        let fileExtension = filename?.split(separator: ".").last?.lowercased() ?? ""
        
        // Modern image formats (PNG, JPEG, GIF, etc.)
        let modernFormats = ["png", "jpg", "jpeg", "gif", "tiff", "tif", "heic", "heif", "webp"]
        if modernFormats.contains(fileExtension) {
            return ModernImageDecoder.decode(data: data, format: fileExtension)
        }

        // MSX formats by extension
        let msxExtensions = ["sc1", "sc2", "sr2", "sc5", "sr5", "sc8", "sr8"]
        if msxExtensions.contains(fileExtension) {
            return MSXDecoder.decode(data: data, filename: filename)
        }

        // BBC Micro formats by extension
        let bbcExtensions = ["bbm0", "bbm1", "bbm2", "bbm4", "bbm5", "mode0", "mode1", "mode2", "mode4", "mode5"]
        if bbcExtensions.contains(fileExtension) {
            return BBCMicroDecoder.decode(data: data, filename: filename)
        }

        // TRS-80/CoCo formats by extension
        let trs80Extensions = ["max", "cm3", "pi3"]
        if trs80Extensions.contains(fileExtension) {
            return TRS80Decoder.decode(data: data, filename: filename)
        }
        
        // Magic byte detection
        if size >= 8 {
            if data[0] == 0x89 && data[1] == 0x50 && data[2] == 0x4E && data[3] == 0x47 {
                return ModernImageDecoder.decode(data: data, format: "png")
            }
            if data[0] == 0xFF && data[1] == 0xD8 {
                return ModernImageDecoder.decode(data: data, format: "jpeg")
            }
            if data[0] == 0x47 && data[1] == 0x49 && data[2] == 0x46 {
                return ModernImageDecoder.decode(data: data, format: "gif")
            }
        }
        
        // BMP format
        if size >= 14 && data[0] == 0x42 && data[1] == 0x4D {
            return PCImageDecoder.decodeBMP(data: data)
        }
        
        // PCX format
        if size >= 128 && data[0] == 0x0A {
            return PCImageDecoder.decodePCX(data: data)
        }
        
        // Apple IIgs PNT detection - check ProDOS file type first
        if let filename = filename?.lowercased() {
            // ProDOS type $C0 (PNT) with different auxtypes
            if filename.contains("#c00000") {
                // Paintworks Packed Picture - uses PackBits, not PackBytes
                return PackedSHRDecoder.decodePNT0000(data: data)
            }
            if filename.contains("#c00001") {
                // Packed Super Hi-Res - uses PackBytes
                return PackedSHRDecoder.decodePNT0001(data: data)
            }
            if filename.contains("#c00002") {
                // Apple Preferred Format (APF)
                return PackedSHRDecoder.decodePNT0002(data: data)
            }
            if filename.contains("#c00003") {
                // Packed QuickDraw II PICT
                return PackedSHRDecoder.decodePNT0002(data: data)  // Try APF decoder
            }
            
            // ProDOS type $C0 (PNT) auxtype $8005 - DreamGrafix LZW compressed
            if filename.contains("#c08005") {
                return DreamGrafixDecoder.decodeDreamGrafixPacked(data: data)
            }

            // ProDOS type $C1 (PIC) with different auxtypes
            if filename.contains("#c10000") {
                // Unpacked Super Hi-Res Screen
                if data.count >= 32000 {
                    return (AppleIIDecoder.decodeSHR(data: data, is3200Color: false), .SHR(mode: "Standard", width: 320, height: 200))
                }
            }
            if filename.contains("#c10002") {
                // SHR 3200 Color
                if data.count >= 38400 {
                    return (AppleIIDecoder.decodeSHR(data: data, is3200Color: true), .SHR(mode: "3200", width: 320, height: 200))
                }
            }
            // ProDOS type $C1 (PIC) auxtype $8003 - DreamGrafix unpacked
            if filename.contains("#c18003") {
                return DreamGrafixDecoder.decodeDreamGrafixUnpacked(data: data)
            }
            
            // Fallback for .pnt extension without type info
            if filename.hasSuffix(".pnt") {
                if let result = PackedSHRDecoder.detectAndDecodePNT(data: data) {
                    return result
                }
            }
        }

        // .3201 extension: Compressed 3200-Color Image
        // Layout: +$00/4: "APP\0", +$04/6400: palettes (200×16×2), +$1904/xx: PackBytes pixel data
        if let name = filename?.lowercased(), name.contains(".3201") {
            if let image = decode3201Format(data: data) {
                return (image, .SHR(mode: "3200 Packed", width: 320, height: 200))
            }
        }

        // APF by signature
        if let result = PackedSHRDecoder.tryDecodeAPF(data: data) {
            return result
        }

        // DreamGrafix by signature (DreamWorld footer)
        if DreamGrafixDecoder.isDreamGrafixFormat(data) {
            // Try packed first (more common), then unpacked
            let packedResult = DreamGrafixDecoder.decodeDreamGrafixPacked(data: data)
            if packedResult.image != nil {
                return packedResult
            }
            let unpackedResult = DreamGrafixDecoder.decodeDreamGrafixUnpacked(data: data)
            if unpackedResult.image != nil {
                return unpackedResult
            }
        }

        // IFF format (Amiga)
        if size >= 12 {
            if let headerString = String(data: data.subdata(in: 0..<4), encoding: .ascii), headerString == "FORM" {
                return AmigaIFFDecoder.decode(data: data)
            }
        }
        
        // C64 formats
        if size >= 10003 && size <= 10010 {
            return C64Decoder.decodeKoala(data: data)
        }
        
        switch size {
        case 10018:
            return C64Decoder.decodeArtStudio(data: data)
        case 9009:
            return C64Decoder.decodeHires(data: data)
        case 6912:
            return RetroDecoder.decodeZXSpectrum(data: data)
        case 16384:
            return handleSize16384(data: data, fileExtension: fileExtension)
        case 54272...54279:
            // MSX Screen 8 (256x212, 8bpp) - may have BSAVE header
            return MSXDecoder.decodeScreen8(data: data)
        case 27136...27143:
            // MSX Screen 5 (256x212, 4bpp) - may have BSAVE header
            return MSXDecoder.decodeScreen5(data: data)
        case 14336...14343:
            // MSX Screen 2 (256x192) - may have BSAVE header
            return MSXDecoder.decodeScreen2(data: data)
        case 20480, 20736:
            // BBC Micro MODE 0/1/2 (20KB)
            return BBCMicroDecoder.decode(data: data, filename: filename)
        case 10240, 10496:
            // BBC Micro MODE 4/5 (10KB)
            return BBCMicroDecoder.decode(data: data, filename: filename)
        case 1024:
            // TRS-80 Model I/III block graphics
            return TRS80Decoder.decodeBlockGraphics(data: data)
        case 6144:
            // CoCo PMODE 3/4 (128x192 or 256x192)
            return TRS80Decoder.decodePMode4(data: data)
        case 32000:
            // CoCo 3 320x200 16-color mode
            return TRS80Decoder.decodeCoCo3_320(data: data)
        default:
            break
        }
        
        // MacPaint
        if fileExtension == "mac" || fileExtension == "pntg" {
            if size >= 512 {
                return RetroDecoder.decodeMacPaint(data: data)
            }
        }
        
        // Degas (Atari ST)
        if size >= 34 {
            let resolutionWord = ImageHelpers.readBigEndianUInt16(data: data, offset: 0)
            let isDegas = (resolutionWord <= 2) && (size == 32034 || size == 32066)
            if isDegas {
                return AtariSTDecoder.decodeDegas(data: data)
            }
        }
        
        // Apple II formats by size
        return decodeAppleIIBySize(data: data, size: size)
    }
    
    private static func handleSize16384(data: Data, fileExtension: String) -> (image: CGImage?, type: AppleIIImageType) {
        if fileExtension == "scr" {
            return RetroDecoder.decodeAmstradCPC(data: data)
        } else if fileExtension == "2mg" || fileExtension == "po" || fileExtension == "dsk" {
            return (AppleIIDecoder.decodeDHGR(data: data), .DHGR)
        }
        
        // Heuristics
        var cpcScore = 0
        var dhgrScore = 0
        
        for blockIdx in 0..<8 {
            let blockStart = blockIdx * 2048
            if blockStart + 100 < data.count {
                let blockData = data[blockStart..<(blockStart + 100)]
                if Set(blockData).count > 50 {
                    cpcScore += 1
                } else {
                    dhgrScore += 1
                }
            }
        }
        
        let firstKB = data.prefix(1024)
        if firstKB.filter({ $0 == 0 }).count > 512 {
            dhgrScore += 3
        }
        
        if cpcScore > dhgrScore + 2 {
            return RetroDecoder.decodeAmstradCPC(data: data)
        } else {
            return (AppleIIDecoder.decodeDHGR(data: data), .DHGR)
        }
    }
    
    private static func decodeAppleIIBySize(data: Data, size: Int) -> (image: CGImage?, type: AppleIIImageType) {
        switch size {
        case 32767...32768:
            // Standard SHR: 32KB file (some files are 1 byte short)
            return (AppleIIDecoder.decodeSHR(data: data, is3200Color: false), .SHR(mode: "Standard", width: 320, height: 200))
        case 38400...:
            // 3200 color SHR: needs full palette data
            return (AppleIIDecoder.decodeSHR(data: data, is3200Color: true), .SHR(mode: "3200", width: 320, height: 200))
        case 8184...8200:
            return (AppleIIDecoder.decodeHGR(data: data), .HGR)
        case 16384:
            return (AppleIIDecoder.decodeDHGR(data: data), .DHGR)
        default:
            // Check for Paintworks signature before trying MacPaint
            // Paintworks files have a palette at offset 0 and patterns at offset 0x22
            if size >= 546 && PackedSHRDecoder.isPaintworksFormat(data) {
                return PackedSHRDecoder.decodePNT0000(data: data)
            }
            
            // Last resort: MacPaint
            if size >= 20000 && size <= 100000 && size >= 512 {
                let result = RetroDecoder.decodeMacPaint(data: data)
                if result.image != nil {
                    return result
                }
            }
            return (nil, .Unknown)
        }
    }
    
    // MARK: - .3201 Format Decoder (Compressed 3200-Color)
    // Layout: +$00/4: High-ASCII "APP" + $00, +$04/6400: palettes (200×16×2), +$1904/xx: PackBytes pixels

    private static func decode3201Format(data: Data) -> CGImage? {
        // Check minimum size: 4 (header) + 6400 (palettes) + some compressed data
        guard data.count > 6404 else { return nil }

        // Verify "APP\0" header (high-ASCII: 0xC1, 0xD0, 0xD0, 0x00)
        let hasAppHeader = (data[0] == 0xC1 && data[1] == 0xD0 && data[2] == 0xD0 && data[3] == 0x00)
        if !hasAppHeader {
            // Some files may not have the header, try anyway
        }

        let paletteOffset = hasAppHeader ? 4 : 0
        let pixelDataOffset = paletteOffset + 6400

        guard data.count > pixelDataOffset else { return nil }

        // Parse 200 palettes (one per scanline, 16 colors each, 2 bytes per color)
        // Note: Colors are stored in reverse order (color 0 in file = color 15 in use)
        var palettes: [[(r: UInt8, g: UInt8, b: UInt8)]] = []
        for line in 0..<200 {
            var linePalette = [(r: UInt8, g: UInt8, b: UInt8)](repeating: (0, 0, 0), count: 16)
            for color in 0..<16 {
                let offset = paletteOffset + (line * 32) + (color * 2)
                guard offset + 1 < data.count else { break }
                let low = data[offset]
                let high = data[offset + 1]
                // SHR palette format: low byte = GB, high byte = 0R
                let r = UInt8((high & 0x0F) * 17)
                let g = UInt8(((low >> 4) & 0x0F) * 17)
                let b = UInt8((low & 0x0F) * 17)
                // Store in reverse order: file color 0 -> slot 15, file color 1 -> slot 14, etc.
                linePalette[15 - color] = (r: r, g: g, b: b)
            }
            palettes.append(linePalette)
        }

        // Decompress pixel data
        let compressedData = data.subdata(in: pixelDataOffset..<data.count)
        let pixelData = PackedSHRDecoder.unpackBytes(data: compressedData, maxOutputSize: 32000)

        guard pixelData.count >= 32000 else { return nil }

        // Render 320x200 image
        let width = 320
        let height = 200
        let bytesPerLine = 160

        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)

        for y in 0..<height {
            let palette = palettes[y]
            for xByte in 0..<bytesPerLine {
                let dataIndex = y * bytesPerLine + xByte
                guard dataIndex < pixelData.count else { continue }
                let byte = pixelData[dataIndex]

                let x = xByte * 2

                // First pixel (high nibble)
                let colorIdx1 = Int((byte >> 4) & 0x0F)
                if colorIdx1 < palette.count {
                    let color1 = palette[colorIdx1]
                    let bufIdx1 = (y * width + x) * 4
                    rgbaBuffer[bufIdx1] = color1.r
                    rgbaBuffer[bufIdx1 + 1] = color1.g
                    rgbaBuffer[bufIdx1 + 2] = color1.b
                    rgbaBuffer[bufIdx1 + 3] = 255
                }

                // Second pixel (low nibble)
                let colorIdx2 = Int(byte & 0x0F)
                if colorIdx2 < palette.count {
                    let color2 = palette[colorIdx2]
                    let bufIdx2 = (y * width + x + 1) * 4
                    rgbaBuffer[bufIdx2] = color2.r
                    rgbaBuffer[bufIdx2 + 1] = color2.g
                    rgbaBuffer[bufIdx2 + 2] = color2.b
                    rgbaBuffer[bufIdx2 + 3] = 255
                }
            }
        }

        return ImageHelpers.createCGImage(from: rgbaBuffer, width: width, height: height)
    }

    // MARK: - Image Scaling

    static func upscaleCGImage(_ image: CGImage, factor: Int) -> CGImage? {
        guard factor > 1 else { return image }
        let newWidth = image.width * factor
        let newHeight = image.height * factor
        return scaleCGImage(image, to: CGSize(width: newWidth, height: newHeight))
    }
    
    static func scaleCGImage(_ image: CGImage, to newSize: CGSize) -> CGImage? {
        guard let colorSpace = image.colorSpace else { return nil }

        guard let ctx = CGContext(
            data: nil,
            width: Int(newSize.width),
            height: Int(newSize.height),
            bitsPerComponent: image.bitsPerComponent,
            bytesPerRow: 0,
            space: colorSpace,
            bitmapInfo: image.bitmapInfo.rawValue
        ) else { return nil }

        ctx.interpolationQuality = .none
        ctx.draw(image, in: CGRect(origin: .zero, size: newSize))
        return ctx.makeImage()
    }
}
