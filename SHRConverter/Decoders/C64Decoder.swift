import Foundation
import CoreGraphics

// MARK: - Commodore 64 Decoder

class C64Decoder {
    
    // C64 Color Palette (16 colors)
    static let palette: [(r: UInt8, g: UInt8, b: UInt8)] = [
        (0x00, 0x00, 0x00),  // 0: Black
        (0xFF, 0xFF, 0xFF),  // 1: White
        (0x68, 0x37, 0x2B),  // 2: Red
        (0x70, 0xA4, 0xB2),  // 3: Cyan
        (0x6F, 0x3D, 0x86),  // 4: Purple
        (0x58, 0x8D, 0x43),  // 5: Green
        (0x35, 0x28, 0x79),  // 6: Blue
        (0xB8, 0xC7, 0x6F),  // 7: Yellow
        (0x6F, 0x4F, 0x25),  // 8: Orange
        (0x43, 0x39, 0x00),  // 9: Brown
        (0x9A, 0x67, 0x59),  // 10: Light Red
        (0x44, 0x44, 0x44),  // 11: Dark Grey
        (0x6C, 0x6C, 0x6C),  // 12: Grey
        (0x9A, 0xD2, 0x84),  // 13: Light Green
        (0x6C, 0x5E, 0xB5),  // 14: Light Blue
        (0x95, 0x95, 0x95)   // 15: Light Grey
    ]
    
    // MARK: - Koala Painter (.KOA, .KLA) - 10003 bytes
    
    static func decodeKoala(data: Data) -> (image: CGImage?, type: AppleIIImageType) {
        guard data.count >= 10003 && data.count <= 10010 else {
            return (nil, .Unknown)
        }
        
        let width = 320
        let height = 200
        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)
        
        let bitmapOffset = 2
        let screenRAMOffset = 8002
        let colorRAMOffset = 9002
        let backgroundOffset = 10002
        
        let backgroundColor = data[backgroundOffset] & 0x0F
        
        for cellY in 0..<25 {
            for cellX in 0..<40 {
                let cellIndex = cellY * 40 + cellX
                
                let screenByte = data[screenRAMOffset + cellIndex]
                let colorByte = data[colorRAMOffset + cellIndex]
                
                let color0 = backgroundColor
                let color1 = (screenByte >> 4) & 0x0F
                let color2 = screenByte & 0x0F
                let color3 = colorByte & 0x0F
                
                let colors = [color0, color1, color2, color3]
                
                for row in 0..<8 {
                    let bitmapByteOffset = bitmapOffset + (cellIndex * 8) + row
                    if bitmapByteOffset >= data.count { continue }
                    
                    let bitmapByte = data[bitmapByteOffset]
                    let y = cellY * 8 + row
                    
                    for pixelPair in 0..<4 {
                        let x = cellX * 8 + (pixelPair * 2)
                        let bitShift = 6 - (pixelPair * 2)
                        let colorIndex = Int((bitmapByte >> bitShift) & 0x03)
                        
                        let c64Color = Int(colors[colorIndex])
                        let rgb = palette[c64Color]
                        
                        for dx in 0..<2 {
                            let bufferIdx = (y * width + x + dx) * 4
                            if bufferIdx + 3 < rgbaBuffer.count {
                                rgbaBuffer[bufferIdx] = rgb.r
                                rgbaBuffer[bufferIdx + 1] = rgb.g
                                rgbaBuffer[bufferIdx + 2] = rgb.b
                                rgbaBuffer[bufferIdx + 3] = 255
                            }
                        }
                    }
                }
            }
        }
        
        guard let cgImage = ImageHelpers.createCGImage(from: rgbaBuffer, width: width, height: height) else {
            return (nil, .Unknown)
        }
        
        return (cgImage, .C64(format: "Koala Painter"))
    }
    
    // MARK: - Advanced Art Studio (.OCP) - 10018 bytes
    
    static func decodeArtStudio(data: Data) -> (image: CGImage?, type: AppleIIImageType) {
        guard data.count == 10018 else {
            return (nil, .Unknown)
        }
        
        let width = 320
        let height = 200
        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)
        
        // Advanced Art Studio: load address (2), bitmap (8000), screen RAM (1000),
        // border (1), background (1), 14 unused bytes, color RAM (1000).
        // (Koala Painter, by contrast, has color RAM right after screen RAM and the background last.)
        let bitmapOffset = 2
        let screenRAMOffset = 8002
        let backgroundOffset = 9003
        let colorRAMOffset = 9018
        
        let backgroundColor = data[backgroundOffset] & 0x0F
        
        for cellY in 0..<25 {
            for cellX in 0..<40 {
                let cellIndex = cellY * 40 + cellX
                
                let screenByte = data[screenRAMOffset + cellIndex]
                let colorByte = data[colorRAMOffset + cellIndex]
                
                let color0 = backgroundColor
                let color1 = (screenByte >> 4) & 0x0F
                let color2 = screenByte & 0x0F
                let color3 = colorByte & 0x0F
                
                let colors = [color0, color1, color2, color3]
                
                for row in 0..<8 {
                    let bitmapByteOffset = bitmapOffset + (cellIndex * 8) + row
                    if bitmapByteOffset >= data.count { continue }
                    
                    let bitmapByte = data[bitmapByteOffset]
                    let y = cellY * 8 + row
                    
                    for pixelPair in 0..<4 {
                        let x = cellX * 8 + (pixelPair * 2)
                        let bitShift = 6 - (pixelPair * 2)
                        let colorIndex = Int((bitmapByte >> bitShift) & 0x03)
                        
                        let c64Color = Int(colors[colorIndex])
                        let rgb = palette[c64Color]
                        
                        for dx in 0..<2 {
                            let bufferIdx = (y * width + x + dx) * 4
                            if bufferIdx + 3 < rgbaBuffer.count {
                                rgbaBuffer[bufferIdx] = rgb.r
                                rgbaBuffer[bufferIdx + 1] = rgb.g
                                rgbaBuffer[bufferIdx + 2] = rgb.b
                                rgbaBuffer[bufferIdx + 3] = 255
                            }
                        }
                    }
                }
            }
        }
        
        guard let cgImage = ImageHelpers.createCGImage(from: rgbaBuffer, width: width, height: height) else {
            return (nil, .Unknown)
        }
        
        return (cgImage, .C64(format: "Advanced Art Studio Multicolor"))
    }
    
    // MARK: - Art Studio Hi-Res (.ART) - 9002 bytes

    static func decodeArtStudioHires(data: Data) -> (image: CGImage?, type: AppleIIImageType) {
        guard data.count == 9002 else {
            return (nil, .Unknown)
        }

        let width = 320
        let height = 200
        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)

        let bitmapOffset = 2      // After 2-byte load address
        let screenRAMOffset = 8002  // After bitmap (8000 bytes)

        for cellY in 0..<25 {
            for cellX in 0..<40 {
                let cellIndex = cellY * 40 + cellX

                let screenByte = data[screenRAMOffset + cellIndex]
                let fgColor = Int((screenByte >> 4) & 0x0F)
                let bgColor = Int(screenByte & 0x0F)

                for row in 0..<8 {
                    let bitmapByteOffset = bitmapOffset + (cellIndex * 8) + row
                    if bitmapByteOffset >= data.count { continue }

                    let bitmapByte = data[bitmapByteOffset]
                    let y = cellY * 8 + row

                    for bit in 0..<8 {
                        let x = cellX * 8 + bit
                        let bitVal = (bitmapByte >> (7 - bit)) & 1
                        let colorIndex = (bitVal == 1) ? fgColor : bgColor

                        let rgb = palette[colorIndex]
                        let bufferIdx = (y * width + x) * 4

                        if bufferIdx + 3 < rgbaBuffer.count {
                            rgbaBuffer[bufferIdx] = rgb.r
                            rgbaBuffer[bufferIdx + 1] = rgb.g
                            rgbaBuffer[bufferIdx + 2] = rgb.b
                            rgbaBuffer[bufferIdx + 3] = 255
                        }
                    }
                }
            }
        }

        guard let cgImage = ImageHelpers.createCGImage(from: rgbaBuffer, width: width, height: height) else {
            return (nil, .Unknown)
        }

        return (cgImage, .C64(format: "Art Studio Hi-Res"))
    }

    // MARK: - HIRES - 9009 bytes

    static func decodeHires(data: Data) -> (image: CGImage?, type: AppleIIImageType) {
        guard data.count == 9009 else {
            return (nil, .Unknown)
        }
        
        let width = 320
        let height = 200
        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)
        
        let bitmapOffset = 2
        let screenRAMOffset = 8002
        
        for cellY in 0..<25 {
            for cellX in 0..<40 {
                let cellIndex = cellY * 40 + cellX
                
                let screenByte = data[screenRAMOffset + cellIndex]
                let bgColor = Int((screenByte >> 4) & 0x0F)
                let fgColor = Int(screenByte & 0x0F)
                
                for row in 0..<8 {
                    let bitmapByteOffset = bitmapOffset + (cellIndex * 8) + row
                    if bitmapByteOffset >= data.count { continue }
                    
                    let bitmapByte = data[bitmapByteOffset]
                    let y = cellY * 8 + row
                    
                    for bit in 0..<8 {
                        let x = cellX * 8 + bit
                        let bitVal = (bitmapByte >> (7 - bit)) & 1
                        let colorIndex = (bitVal == 0) ? fgColor : bgColor
                        
                        let rgb = palette[colorIndex]
                        let bufferIdx = (y * width + x) * 4
                        
                        if bufferIdx + 3 < rgbaBuffer.count {
                            rgbaBuffer[bufferIdx] = rgb.r
                            rgbaBuffer[bufferIdx + 1] = rgb.g
                            rgbaBuffer[bufferIdx + 2] = rgb.b
                            rgbaBuffer[bufferIdx + 3] = 255
                        }
                    }
                }
            }
        }
        
        guard let cgImage = ImageHelpers.createCGImage(from: rgbaBuffer, width: width, height: height) else {
            return (nil, .Unknown)
        }
        
        return (cgImage, .C64(format: "C64 HIRES"))
    }
}

// MARK: - More bitmap formats (layouts from RECOIL)

extension C64Decoder {

    /// Name of one of the formats below for this file, or nil. Uses the extension first; files from
    /// C64 disks have none, so exact sizes with their usual load address are recognized too.
    static func extraFormatName(data: Data, fileExtension ext: String, filename: String?) -> String? {
        let size = data.count
        guard size >= 2 else { return nil }
        let load = Int(data[data.startIndex]) | Int(data[data.startIndex + 1]) << 8
        let doodleSizes = [9026, 9217, 9218, 9346]
        if let fli = fliFormatName(data: data, fileExtension: ext, filename: filename) { return fli }

        switch ext {
        case "dd", "ddp": return doodleSizes.contains(size) ? "Doodle" : "Doodle (compressed)"
        case "jj": return "Doodle (compressed)"
        case "het": return doodleSizes.contains(size) ? "Hires-Editor" : nil
        case "rph": return doodleSizes.contains(size) ? "Run Paint" : nil
        case "hed": return size == 9218 ? "Hi-Eddi" : nil
        case "hpc": return size == 9003 ? "Hi-Pic Creator" : nil
        case "hbm", "hir", "hpi", "fgs": if size == 8002 { return "Hires Bitmap" }
        case "rpo", "gih": return size == 8002 ? "Run Paint Hires" : nil
        case "vid": return size == 10050 ? "Vidcom 64" : nil
        case "p64": return size == 10050 ? "Picasso 64" : nil
        case "dol": return size == 10242 ? "Dolphin Ed" : nil
        case "bpl", "pi": if size == 10242 { return "Blazing Paddles" }
        case "a64", "wig": return size == 10242 ? "Wigmore Artist 64" : nil
        case "ism": return size == 10218 ? "Image System" : nil
        case "sar": return size == 10219 ? "Saracen Paint" : nil
        case "cdu": return size == 10277 ? "CDU-Paint" : nil
        case "mil": return size == 10022 && data[data.startIndex + 7] == 0 ? "Micro Illustrator" : nil
        case "drz", "drp": return size == 10051 || hasDrazpaintSignature(data) ? "Drazpaint" : nil
        case "gr":
            if size >= 10, size == 2 + Int(data[data.startIndex]) * Int(data[data.startIndex + 1]) * 8 {
                return "Star Painter"
            }
        case "gg": return "Koala Painter (compressed)"
        case "koa", "kla": if !(10001...10010).contains(size) { return "Koala Painter (compressed)" }
        case "ami": return "Amica Paint"
        default: break
        }

        // Size and load address only (C64 disk files). Files with a ProDOS type tag are Apple II files;
        // Plus/4 .p4i pictures share the Picasso 64 size and load address.
        if let filename, filename.contains("#") { return nil }
        if ext == "p4i" { return nil }
        switch (size, load) {
        case (8002, let a) where a & 0xFF == 0 && [0x20, 0x40, 0x60, 0xA0, 0xE0].contains(a >> 8): return "Hires Bitmap"
        case (9003, 0x6000): return "Hi-Pic Creator"
        case (9218, 0x2000): return "Hi-Eddi"
        case (9026, 0x5C00), (9217, 0x5C00), (9218, 0x5C00), (9218, 0x1C00), (9346, 0x5C00): return "Doodle"
        case (10050, 0x5800): return "Vidcom 64"
        case (10050, 0x1800): return "Picasso 64"
        case (10051, 0x5800): return "Drazpaint"
        case (10218, 0x3C00): return "Image System"
        case (10219, 0x7800): return "Saracen Paint"
        case (10242, 0x5800): return "Dolphin Ed"
        case (10242, 0xA000): return "Blazing Paddles"
        case (10242, 0x4000): return "Wigmore Artist 64"
        case (10277, 0x7EEF): return "CDU-Paint"
        case (10022, 0x18DC): return "Micro Illustrator"
        default: break
        }

        // Packed pictures on C64 disks are named GG... (Koala) and JJ... (Doodle)
        let base = ((filename ?? "") as NSString).lastPathComponent.uppercased()
        if base.hasPrefix("GG") && load == 0x6000 { return "Koala Painter (compressed)" }
        if base.hasPrefix("JJ") && load == 0x5C00 { return "Doodle (compressed)" }
        return nil
    }

    /// Draw a picture in one of the formats named by `extraFormatName` (also the plain hires formats,
    /// for the palette editor). Returns nil if the data does not fit the layout.
    static func decodeExtraFormat(_ name: String, data: Data,
                                  palette colors: [(r: UInt8, g: UInt8, b: UInt8)] = palette) -> CGImage? {
        let d = [UInt8](data)
        let colors = colors.count >= 16 ? colors : palette
        switch name {
        case "Doodle", "Hires-Editor", "Run Paint": return hires(d, bitmap: 0x402, screen: 2, colors: colors)
        case "Doodle (compressed)":
            guard let u = unpackKoalaStream(d, from: 2, count: 9024) else { return nil }
            return hires(u, bitmap: 0x400, screen: 0, colors: colors)
        case "Hi-Eddi": return hires(d, bitmap: 2, screen: 0x2002, colors: colors)
        case "Hi-Pic Creator", "C64 HIRES", "Art Studio Hi-Res": return hires(d, bitmap: 2, screen: 0x1F42, colors: colors)
        case "Hires Bitmap": return hires(d, bitmap: 2, fixedColors: 0x10, colors: colors)
        case "Run Paint Hires": return hires(d, bitmap: 2, fixedColors: 0x01, colors: colors)
        case "Star Painter":
            guard d.count >= 2 else { return nil }
            return hires(d, bitmap: 2, fixedColors: 0x01, columns: Int(d[0]), rows: Int(d[1]), colors: colors)
        case "Vidcom 64", "Dolphin Ed": return multicolor(d, bitmap: 0x802, screen: 0x402, color: 2, background: 0x7EA, colors: colors)
        case "Picasso 64": return multicolor(d, bitmap: 0x802, screen: 0x402, color: 2, background: 0x801, colors: colors)
        case "Blazing Paddles": return multicolor(d, bitmap: 2, screen: 0x2002, color: 0x2402, background: 0x1F82, colors: colors)
        case "Wigmore Artist 64": return multicolor(d, bitmap: 2, screen: 0x2002, color: 0x2402, background: 0x2801, colors: colors)
        case "Image System": return multicolor(d, bitmap: 0x402, screen: 0x2402, color: 2, background: 0x2401, colors: colors)
        case "Saracen Paint": return multicolor(d, bitmap: 0x402, screen: 2, color: 0x2402, background: 0x3F2, colors: colors)
        case "CDU-Paint": return multicolor(d, bitmap: 0x113, screen: 0x2053, color: 0x243B, background: 0x2823, colors: colors)
        case "Micro Illustrator": return multicolor(d, bitmap: 0x7E6, screen: 0x16, color: 0x3FE, background: 8, colors: colors)
        case "Drazpaint":
            var u = d
            if hasDrazpaintSignature(data) {
                // "DRAZPAINT 1.4" at 2, escape byte at 15, packed data from 16
                guard let packed = unpackEscapeStream(d, from: 16, escape: d[15], count: 10051 - 2) else { return nil }
                u = [0, 0] + packed
            }
            return multicolor(u, bitmap: 0x802, screen: 0x402, color: 2, background: 0x2742, colors: colors)
        case "Koala Painter (compressed)":
            guard let u = unpackKoalaStream(d, from: 2, count: 10001) else { return nil }
            return multicolor(u, bitmap: 0, screen: 0x1F40, color: 0x2328, background: 0x2710, colors: colors)
        case "Amica Paint":
            guard let u = unpackEscapeStream(d, from: 2, escape: 0xC2, count: 10001) else { return nil }
            return multicolor(u, bitmap: 0, screen: 0x1F40, color: 0x2328, background: 0x2710, colors: colors)
        default: return decodeFliFormat(name, data: data, colors: colors)
        }
    }

    private static func hasDrazpaintSignature(_ data: Data) -> Bool {
        let signature = Array("DRAZPAINT 1.4".utf8)
        return data.count > 16 && Array(data.dropFirst(2).prefix(signature.count)) == signature
    }

    // MARK: Layouts

    /// Hires: 1 bit per pixel; the screen byte of each 8x8 cell gives the colors (low nibble for 0 bits,
    /// high nibble for 1 bits), or `fixedColors` for the whole picture.
    private static func hires(_ d: [UInt8], bitmap: Int, screen: Int = -1, fixedColors: Int = 0,
                              columns: Int = 40, rows: Int = 25,
                              colors: [(r: UInt8, g: UInt8, b: UInt8)]) -> CGImage? {
        guard columns > 0, rows > 0, bitmap + columns * rows * 8 <= d.count,
              screen < 0 || screen + columns * rows <= d.count else { return nil }
        let width = columns * 8, height = rows * 8
        var rgba = [UInt8](repeating: 255, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let offset = (y & ~7) * columns + (x & ~7) + (y & 7)
                let bit = d[bitmap + offset] >> (7 - (x & 7)) & 1
                let v = screen >= 0 ? Int(d[screen + (offset >> 3)]) : fixedColors
                let c = colors[bit == 0 ? v & 0x0F : v >> 4 & 0x0F]
                let p = (y * width + x) * 4
                rgba[p] = c.r; rgba[p + 1] = c.g; rgba[p + 2] = c.b
            }
        }
        return ImageHelpers.createCGImage(from: rgba, width: width, height: height)
    }

    /// Multicolor: 2 bits per double-wide pixel; 0 = background, 1 = screen high nibble,
    /// 2 = screen low nibble, 3 = color RAM.
    private static func multicolor(_ d: [UInt8], bitmap: Int, screen: Int, color: Int, background: Int,
                                   colors: [(r: UInt8, g: UInt8, b: UInt8)]) -> CGImage? {
        guard bitmap + 8000 <= d.count, screen + 1000 <= d.count, color + 1000 <= d.count,
              background < d.count else { return nil }
        let width = 320, height = 200
        let bg = Int(d[background] & 0x0F)
        var rgba = [UInt8](repeating: 255, count: width * height * 4)
        for y in 0..<height {
            for x in 0..<width {
                let cell = (y >> 3) * 40 + (x >> 3)
                let index: Int
                switch d[bitmap + cell * 8 + (y & 7)] >> (6 - (x & 6)) & 3 {
                case 1: index = Int(d[screen + cell] >> 4)
                case 2: index = Int(d[screen + cell] & 0x0F)
                case 3: index = Int(d[color + cell] & 0x0F)
                default: index = bg
                }
                let c = colors[index]
                let p = (y * width + x) * 4
                rgba[p] = c.r; rgba[p + 1] = c.g; rgba[p + 2] = c.b
            }
        }
        return ImageHelpers.createCGImage(from: rgba, width: width, height: height)
    }

    // MARK: Packers

    /// Koala/Doodle packer (GG, JJ): $FE value count = repeat, any other byte is a literal
    private static func unpackKoalaStream(_ d: [UInt8], from start: Int, count: Int) -> [UInt8]? {
        var out: [UInt8] = []; out.reserveCapacity(count)
        var i = start
        while out.count < count {
            guard i < d.count else { return nil }
            let b = d[i]; i += 1
            if b == 0xFE {
                guard i + 1 < d.count else { return nil }
                out.append(contentsOf: repeatElement(d[i], count: min(Int(d[i + 1]), count - out.count)))
                i += 2
            } else {
                out.append(b)
            }
        }
        return out
    }

    /// Escape-byte packer (Drazpaint, Amica Paint): escape count value = repeat, others literal
    private static func unpackEscapeStream(_ d: [UInt8], from start: Int, escape: UInt8, count: Int) -> [UInt8]? {
        var out: [UInt8] = []; out.reserveCapacity(count)
        var i = start
        while out.count < count {
            guard i < d.count else { return nil }
            let b = d[i]; i += 1
            if b == escape {
                guard i + 1 < d.count else { return nil }
                out.append(contentsOf: repeatElement(d[i + 1], count: min(Int(d[i]), count - out.count)))
                i += 2
            } else {
                out.append(b)
            }
        }
        return out
    }
}

// MARK: - FLI, interlace and other advanced formats (ported from RECOIL)

extension C64Decoder {

    /// FLI pictures lose their 3 leftmost characters to the "FLI bug", so they are 296 pixels wide
    private static let fliBug = 3
    private static let fliWidth = 320 - 3 * 8

    /// Name of an FLI/interlace format for this file, or nil (see `extraFormatName`)
    static func fliFormatName(data: Data, fileExtension ext: String, filename: String?) -> String? {
        let c = [UInt8](data)
        let n = c.count
        guard n >= 6 else { return nil }
        let load = Int(c[0]) | Int(c[1]) << 8
        let funpaint = hasSignature(c, at: 2, "FUNPAINT (MT) ")
        let drazlace = hasSignature(c, at: 2, "DRAZLACE! 1.0")
        let packedPixelPerfect = c[2] == 0x10 && c[3] == 0x10 && c[4] == 0x10
        let packedHiresManager = c[0] == 0 && c[1] == 0x40 && c[3] != 0xFF && n >= 18
            && Int(c[2]) + Int(c[3]) << 8 == 0x4000 - 3 + n && c[4] == 0xF2 && c[5] == 0x7F

        switch ext {
        case "cfli": return n == 8170 ? "CFLI Designer" : nil
        case "fli": return n == 17409 ? "FLI" : nil
        case "fd2": return n == 17218 ? "FLI Designer" : nil
        case "bml", "flg": return "FLI Graph"
        case "fed": return n == 17665 ? "FLI Editor" : nil
        case "afl": return n == 16385 ? "AFLI-editor" : nil
        case "hfc", "hfd": return n == 16386 ? "Hires FLI Designer" : nil
        case "fpr": return n == 18370 ? "FLI Profi" : nil
        case "ffl", "ffli": return n == 26115 && c[2] == 0x66 ? "Flash FLI" : nil
        case "bfl", "bfli": return n == 33795 && c[2] == 0x62 ? "Big FLI" : nil
        case "gun", "ifl": return n == 33602 || n == 33603 ? "Gunpaint" : nil
        case "pp", "ppp": return packedPixelPerfect || n == 33602 ? "Pixel Perfect" : nil
        case "fun", "fp2": return funpaint ? "Funpaint" : nil
        case "dlp", "drl": return drazlace || n == 18242 ? "Drazlace" : nil
        case "eci", "ecp": return "ECI Graphic Editor"
        case "ihe": return n == 16194 ? "Interlace Hires Editor" : nil
        case "hlf", "hie": return n == 24578 ? "Hires Interlace" : nil
        case "hle": return n == 32770 ? "Hireslace Editor" : nil
        case "mci": return n == 19434 ? "True Paint" : nil
        case "ish": return n == 9194 ? "Image System Hires" : nil
        case "che": return n == 20482 ? "Cheese" : nil
        case "him": return (n == 16385 && c[0] == 0 && c[1] == 0x40 && c[3] == 0xFF) || packedHiresManager ? "Hires Manager" : nil
        case "fbi": return "Flip"
        case "cle": return n == 8194 ? "Centauri Logo" : nil
        default: break
        }

        // Size, load address or signature only (files from C64 disks)
        if let filename, filename.contains("#") { return nil }
        if ext == "p4i" { return nil }
        if funpaint { return "Funpaint" }
        if drazlace { return "Drazlace" }
        if packedHiresManager { return "Hires Manager" }
        switch (n, load) {
        case (8170, 0x4000): return "CFLI Designer"
        case (17409, 0x3C00): return "FLI"
        case (17474, 0x3B00): return "FLI Graph"
        case (16385, 0x4000): return c[3] == 0xFF ? "Hires Manager" : "AFLI-editor"
        case (16386, 0x4000): return "Hires FLI Designer"
        case (18370, 0x3780): return "FLI Profi"
        case (26115, 0x3AFF) where c[2] == 0x66: return "Flash FLI"
        case (33795, 0x3BFF) where c[2] == 0x62: return "Big FLI"
        case (33603, 0x4000): return "Gunpaint"
        case (33602, 0x3C00): return "Pixel Perfect"
        case (32770, 0x4000): return "ECI Graphic Editor"
        case (16194, 0x2000): return "Interlace Hires Editor"
        case (24578, 0x2000): return "Hires Interlace"
        case (19434, 0x9C00): return "True Paint"
        case (20482, 0x8000): return "Cheese"
        default: return nil
        }
    }

    /// Draw a picture in one of the formats named by `fliFormatName`
    static func decodeFliFormat(_ name: String, data: Data, colors: [(r: UInt8, g: UInt8, b: UInt8)]) -> CGImage? {
        let c = [UInt8](data)
        let n = c.count
        let w = fliWidth
        switch name {
        case "CFLI Designer":
            guard n == 8170 else { return nil }
            var s = Screen(width: w, height: 200)
            for y in 0..<200 {
                for x in 0..<w {
                    s.px[y * w + x] = c[2 + 3 + ((y & 7) << 10) + (y & ~7) * 5 + (x >> 3)] >> (x & 1 == 0 ? 4 : 0) & 0x0F
                }
            }
            return s.image(colors)
        case "FLI", "FLI Designer":
            return multicolorFli(c, bitmap: 0x2402, screen: 0x402, color: 2, background: 0, colors: colors)
        case "FLI Graph":
            if n == 17474 { return multicolorFliBars(c, bitmap: 0x2502, screen: 0x502, color: 0x102, backgrounds: 2, colors: colors) }
            var r = Rle(c, kind: .uif(Int(c[2])), offset: n)
            guard let u = r.unpackBackwards(count: 17472) else { return nil }
            return multicolorFliBars(u, bitmap: 0x2500, screen: 0x500, color: 0x100, backgrounds: 0, colors: colors)
        case "FLI Editor":
            return multicolorFliBars(c, bitmap: 0x2502, screen: 0x502, color: 0x102, backgrounds: 8, colors: colors)
        case "AFLI-editor":
            var s = Screen(width: w, height: 200)
            s.hires(c, bitmap: 0x2002 + fliBug * 8, screen: 2 + fliBug, afli: true)
            return s.image(colors)
        case "Hires FLI Designer":
            var s = Screen(width: w, height: 112)
            s.hires(c, bitmap: 2 + fliBug * 8, screen: 0x2002 + fliBug, afli: true)
            return s.image(colors)
        case "Hires Manager":
            var u = c
            if !(n == 16385 && c[3] == 0xFF) {
                var r = Rle(c, kind: .him, offset: n - 1)
                guard let tail = r.unpackBackwards(count: 16372 - (2 + 320)) else { return nil }
                u = [UInt8](repeating: 0, count: 2 + 320) + tail
            }
            var s = Screen(width: w, height: 192)
            s.hires(u, bitmap: 2 + 40 * 8 + fliBug * 8, screen: 0x2002 + 40 + fliBug, afli: true)
            return s.image(colors)
        case "FLI Profi":
            return fliProfi(c, colors: colors)
        case "Flash FLI":
            var s = Screen(width: w, height: 200, frames: 2)
            s.fliBars(c, frame: 0, bitmap: 0x2503 + fliBug * 8, screen: 0x503 + fliBug, color: 0x103 + fliBug, backgrounds: 3)
            s.fliBars(c, frame: 1, bitmap: 0x2503 + fliBug * 8, screen: 0x4503 + fliBug, color: 0x103 + fliBug, backgrounds: 0x6503)
            return s.image(colors)
        case "Big FLI":
            var s = Screen(width: w, height: 400)
            s.fli(c, frame: 0, bitmap: 0x2403 + fliBug * 8, screen: 0x403 + fliBug, color: 3 + fliBug, background: 0)
            s.fli(c, frame: 0, bitmap: 0x6403, screen: 0x4403, color: 3, background: 0, bottomBfli: true, firstRow: 200)
            return s.image(colors)
        case "Gunpaint":
            var s = Screen(width: w, height: 200, frames: 2)
            for (frame, bitmap, screen) in [(0, 0x2002, 2), (1, 0x6402, 0x4402)] {
                s.leftSkip = -frame
                for y in 0..<200 {
                    let background = Int(c[y < 177 ? 0x3F51 + y : y < 197 ? 0x47EA - 177 + y : 0x47FD])
                    s.multicolorLine(c, frame: frame, bitmap: bitmap + fliBug * 8, screen: screen + fliBug + ((y & 7) << 10),
                                     color: 0x4002 + fliBug, background: background, y: y)
                }
            }
            return s.image(colors)
        case "Pixel Perfect":
            var u = c
            if c[2] == 0x10 && c[3] == 0x10 && c[4] == 0x10 {
                var r = Rle(c, kind: .cmp(Int(c[5])), offset: 6)
                guard let body = r.unpack(count: 33602 - 2), r.readRle() < 0 else { return nil }
                u = [0, 0] + body
            }
            guard u.count == 33602 else { return nil }
            return ifli(u, bitmap1: 0x2402, bitmap2: 0x6402, screen1: 0x402, screen2: 0x4402, color: 2,
                        background: Int(u[0x4381]), colors: colors)
        case "Funpaint":
            var u = c
            if c[16] != 0 {
                var r = Rle(c, kind: .drp(Int(c[17])), offset: 18)
                guard let body = r.unpack(count: 33694 - 18), r.readRle() < 0 else { return nil }
                u = [UInt8](repeating: 0, count: 18) + body
            }
            guard u.count == 33694 else { return nil }
            return ifli(u, bitmap1: 0x2012, bitmap2: 0x63FA, screen1: 0x12, screen2: 0x43FA, color: 0x4012,
                        background: 0, colors: colors)
        case "Drazlace":
            var u = c
            if hasSignature(c, at: 2, "DRAZLACE! 1.0") {
                var r = Rle(c, kind: .drp(Int(c[15])), offset: 16)
                guard let body = r.unpack(count: 18242 - 2) else { return nil }
                u = [0, 0] + body
            }
            guard u.count == 18242, u[0x2744] <= 1 else { return nil }
            return interlaceMulticolor(u, bitmap1: 0x802, screen1: 0x402, bitmap2: 0x2802, screen2: 0x402,
                                       color: 2, background: 0x2742, shift: Int(u[0x2744]), colors: colors)
        case "True Paint":
            guard n == 19434 else { return nil }
            return interlaceMulticolor(c, bitmap1: 0x402, screen1: 2, bitmap2: 0x2402, screen2: 0x4402,
                                       color: 0x4802, background: 0x3EA, shift: 1, colors: colors)
        case "ECI Graphic Editor":
            var u = c
            if n != 32770 {
                var r = Rle(c, kind: .drp(Int(c[2])), offset: 3)
                guard let body = r.unpack(count: 32770 - 2) else { return nil }
                u = [0, 0] + body
            }
            var s = Screen(width: w, height: 200, frames: 2)
            s.hires(u, bitmap: 2 + fliBug * 8, screen: 0x2002 + fliBug, afli: true)
            s.hires(u, frame: 1, bitmap: 0x4002 + fliBug * 8, screen: 0x6002 + fliBug, afli: true)
            return s.image(colors)
        case "Interlace Hires Editor":
            return interlaceHires(c, bitmap1: 2, screen1: -0x0C, bitmap2: 0x2002, screen2: -0x0C, colors: colors)
        case "Hires Interlace":
            return interlaceHires(c, bitmap1: 2, screen1: 0x2802, bitmap2: 0x4002, screen2: 0x2402, colors: colors)
        case "Hireslace Editor":
            return interlaceHires(c, bitmap1: 2, screen1: 0x2002, bitmap2: 0x6002, screen2: 0x4002, colors: colors)
        case "Image System Hires":
            var s = Screen(width: 320, height: 200)
            s.hires(c, bitmap: 2, screen: 0x2002)
            return s.image(colors)
        case "Cheese":
            var s = Screen(width: 320, height: 200)
            s.multicolor(c, bitmap: 2, screen: 0x4202, color: 0x4802, background: 0x4FFF)
            return s.image(colors)
        case "Flip":
            guard n >= 19 else { return nil }
            var r = Rle(c, kind: .uif(Int(c[2])), offset: n)
            guard let u = r.unpackBackwards(count: 17216) else { return nil }
            return multicolorFli(u, bitmap: 0x2400, screen: 0x400, color: 0, background: 0, colors: colors)
        case "Centauri Logo":
            // Four colors for the whole picture (Centauri Logo Editor)
            guard n == 8194 else { return nil }
            let four = [c[8004] & 0x0F, c[8002] >> 4, c[8002] & 0x0F, c[8003] & 0x0F]
            var s = Screen(width: 320, height: 200)
            for y in 0..<200 {
                for x in 0..<320 {
                    s.px[y * 320 + x] = four[Int(c[2 + (y & ~7) * 40 + (x & ~7) + (y & 7)] >> (6 - (x & 6)) & 3)]
                }
            }
            return s.image(colors)
        default:
            return nil
        }
    }

    // MARK: Layout helpers

    private static func multicolorFli(_ c: [UInt8], bitmap: Int, screen: Int, color: Int, background: Int,
                                      colors: [(r: UInt8, g: UInt8, b: UInt8)]) -> CGImage? {
        var s = Screen(width: fliWidth, height: 200)
        s.fli(c, frame: 0, bitmap: bitmap + fliBug * 8, screen: screen + fliBug, color: color + fliBug, background: background)
        return s.image(colors)
    }

    /// FLI with a background color per line
    private static func multicolorFliBars(_ c: [UInt8], bitmap: Int, screen: Int, color: Int, backgrounds: Int,
                                          colors: [(r: UInt8, g: UInt8, b: UInt8)]) -> CGImage? {
        var s = Screen(width: fliWidth, height: 200)
        s.fliBars(c, frame: 0, bitmap: bitmap + fliBug * 8, screen: screen + fliBug, color: color + fliBug, backgrounds: backgrounds)
        return s.image(colors)
    }

    /// Interlaced FLI: two FLI frames, the second one shifted right by one pixel, shown blended
    private static func ifli(_ c: [UInt8], bitmap1: Int, bitmap2: Int, screen1: Int, screen2: Int, color: Int, background: Int,
                             colors: [(r: UInt8, g: UInt8, b: UInt8)]) -> CGImage? {
        var s = Screen(width: fliWidth, height: 200, frames: 2)
        s.fli(c, frame: 0, bitmap: bitmap1 + fliBug * 8, screen: screen1 + fliBug, color: color + fliBug, background: background)
        s.leftSkip = -1
        s.fli(c, frame: 1, bitmap: bitmap2 + fliBug * 8, screen: screen2 + fliBug, color: color + fliBug, background: background)
        return s.image(colors)
    }

    private static func interlaceHires(_ c: [UInt8], bitmap1: Int, screen1: Int, bitmap2: Int, screen2: Int,
                                       colors: [(r: UInt8, g: UInt8, b: UInt8)]) -> CGImage? {
        var s = Screen(width: 320, height: 200, frames: 2)
        s.hires(c, bitmap: bitmap1, screen: screen1)
        s.hires(c, frame: 1, bitmap: bitmap2, screen: screen2)
        return s.image(colors)
    }

    private static func interlaceMulticolor(_ c: [UInt8], bitmap1: Int, screen1: Int, bitmap2: Int, screen2: Int,
                                            color: Int, background: Int, shift: Int,
                                            colors: [(r: UInt8, g: UInt8, b: UInt8)]) -> CGImage? {
        var s = Screen(width: 320, height: 200, frames: 2)
        s.multicolor(c, bitmap: bitmap1, screen: screen1, color: color, background: background)
        s.leftSkip = -shift
        s.multicolor(c, frame: 1, bitmap: bitmap2, screen: screen2, color: color, background: background)
        return s.image(colors)
    }

    /// FLI Profi: FLI with a sprite layer covering the 24 pixels the FLI bug hides
    private static func fliProfi(_ c: [UInt8], colors: [(r: UInt8, g: UInt8, b: UInt8)]) -> CGImage? {
        guard c.count == 18370 else { return nil }
        var s = Screen(width: 320, height: 200)
        for y in 0..<200 {
            for x in 0..<320 {
                let offset = (y >> 3) * 40 + (x >> 3)
                var v = x < 24 ? 0xFF : Int(c[0x882 + offset + ((y & 7) << 10)])
                switch c[0x2882 + (offset << 3) + (y & 7)] >> (6 - (x & 6)) & 3 {
                case 0: v = 0
                case 1: v >>= 4
                case 3: v = x < 24 ? Int(c[0x382 + y] >> 4) : Int(c[0x482 + offset])
                default: break
                }
                if x < 24 {
                    let sprite = 2 + ((((y + 1) & 2 != 0 ? 5 : 0) + y / 42) << 6) + (y >> 1) % 21 * 3 + (x >> 3)
                    switch c[sprite] >> (6 - (x & 6)) & 3 {
                    case 1: v = Int(c[0x282 + y])
                    case 2: v = Int(c[0x44A])
                    case 3: v = Int(c[0x44B])
                    default: break
                    }
                }
                s.px[y * 320 + x] = UInt8(v & 0x0F)
            }
        }
        return s.image(colors)
    }

    private static func hasSignature(_ c: [UInt8], at offset: Int, _ text: String) -> Bool {
        let bytes = Array(text.utf8)
        return c.count > offset + bytes.count && Array(c[offset..<(offset + bytes.count)]) == bytes
    }

    // MARK: Screen (color indices of one or two frames; two frames are shown blended)

    private struct Screen {
        let width: Int
        let height: Int
        let frames: Int
        var px: [UInt8]
        var leftSkip = 0

        init(width: Int, height: Int, frames: Int = 1) {
            self.width = width; self.height = height; self.frames = frames
            px = [UInt8](repeating: 0, count: width * height * frames)
        }

        private func at(_ c: [UInt8], _ i: Int) -> Int { i >= 0 && i < c.count ? Int(c[i]) : 0 }

        /// Hires frame. A negative `screen` gives fixed colors (-screen).
        mutating func hires(_ c: [UInt8], frame: Int = 0, bitmap: Int, screen: Int, afli: Bool = false) {
            for y in 0..<height {
                for x in 0..<width {
                    let offset = (y & ~7) * 40 + (x & ~7) + (y & 7)
                    let bit = at(c, bitmap + offset) >> (7 - (x & 7)) & 1
                    var v = -screen
                    if screen >= 0 { v = at(c, screen + (offset >> 3) + (afli ? (y & 7) << 10 : 0)) }
                    px[(frame * height + y) * width + x] = UInt8(bit == 0 ? v & 0x0F : v >> 4 & 0x0F)
                }
            }
        }

        mutating func multicolorLine(_ c: [UInt8], frame: Int, bitmap: Int, screen: Int, color: Int, background: Int,
                                     y: Int, row: Int? = nil, bottomBfli: Bool = false) {
            let out = (frame * height + (row ?? y)) * width
            for x in 0..<width {
                let sx = x + leftSkip
                var v = background
                if sx >= 0 {
                    var cell = (y >> 3) * 40 + (sx >> 3)
                    if bottomBfli { cell = (cell - (24 - 3)) & 0x3FF }
                    switch at(c, bitmap + (cell << 3) + (y & 7)) >> (6 - (sx & 6)) & 3 {
                    case 1: v = at(c, screen + cell) >> 4
                    case 2: v = at(c, screen + cell)
                    case 3: v = at(c, color + cell)
                    default: break
                    }
                }
                px[out + x] = UInt8(v & 0x0F)
            }
        }

        mutating func multicolor(_ c: [UInt8], frame: Int = 0, bitmap: Int, screen: Int, color: Int, background: Int) {
            let bg = at(c, background)
            for y in 0..<200 { multicolorLine(c, frame: frame, bitmap: bitmap, screen: screen, color: color, background: bg, y: y) }
        }

        mutating func fli(_ c: [UInt8], frame: Int, bitmap: Int, screen: Int, color: Int, background: Int,
                          bottomBfli: Bool = false, firstRow: Int = 0) {
            for y in 0..<200 {
                multicolorLine(c, frame: frame, bitmap: bitmap, screen: screen + ((y & 7) << 10), color: color,
                               background: background, y: y, row: firstRow + y, bottomBfli: bottomBfli)
            }
        }

        mutating func fliBars(_ c: [UInt8], frame: Int, bitmap: Int, screen: Int, color: Int, backgrounds: Int) {
            for y in 0..<200 {
                multicolorLine(c, frame: frame, bitmap: bitmap, screen: screen + ((y & 7) << 10), color: color,
                               background: at(c, backgrounds + y), y: y)
            }
        }

        /// RGB image; two frames are averaged, as the eye sees an interlaced picture
        func image(_ colors: [(r: UInt8, g: UInt8, b: UInt8)]) -> CGImage? {
            let count = width * height
            var rgba = [UInt8](repeating: 255, count: count * 4)
            for i in 0..<count {
                let a = colors[Int(px[i])]
                var r = Int(a.r), g = Int(a.g), b = Int(a.b)
                if frames == 2 {
                    let bb = colors[Int(px[count + i])]
                    r = (r + Int(bb.r)) / 2; g = (g + Int(bb.g)) / 2; b = (b + Int(bb.b)) / 2
                }
                rgba[i * 4] = UInt8(r); rgba[i * 4 + 1] = UInt8(g); rgba[i * 4 + 2] = UInt8(b)
            }
            return ImageHelpers.createCGImage(from: rgba, width: width, height: height)
        }
    }

    // MARK: RLE streams (RECOIL's CmpStream, DrpStream, UifStream and HimStream)

    private struct Rle {
        enum Kind { case cmp(Int), drp(Int), uif(Int), him }
        let c: [UInt8]
        let kind: Kind
        var offset: Int
        var count = 0
        var value = 0

        init(_ c: [UInt8], kind: Kind, offset: Int) { self.c = c; self.kind = kind; self.offset = offset }

        private mutating func readByte() -> Int {
            guard offset >= 0, offset < c.count else { return -1 }
            offset += 1
            return Int(c[offset - 1])
        }

        /// Literal bytes; the UIF and HIM packers read the file backwards
        private mutating func readValue() -> Int {
            switch kind {
            case .uif:
                guard offset > 2 else { return -1 }
                offset -= 1
                return Int(c[offset])
            case .him:
                guard offset >= 18, offset < c.count else { return -1 }
                offset -= 1
                return Int(c[offset + 1])
            default:
                return readByte()
            }
        }

        private mutating func readCommand() -> Bool {
            switch kind {
            case .cmp(let escape):
                var b = readByte()
                if b == escape { count = readByte() + 1; b = readByte() } else { count = 1 }
                value = b
                return b >= 0
            case .drp(let escape):
                var b = readByte()
                if b == escape { count = readByte(); b = readByte() } else { count = 1 }
                value = b
                return b >= 0
            case .uif(let escape):
                var b = readValue()
                if b == escape {
                    count = readValue()
                    if count == 0 { count = 256 }
                    b = readValue()
                } else {
                    count = 1
                }
                value = b
                return b >= 0
            case .him:
                let b = readValue()
                if b < 0 { return false }
                if b == 0 {
                    count = readValue()
                    if count <= 0 { return false }
                    value = readValue()
                    return value >= 0
                }
                count = b - 1
                value = -1
                return true
            }
        }

        /// Next unpacked byte, or -1 at the end or on an error
        mutating func readRle() -> Int {
            while count == 0 {
                if !readCommand() { return -1 }
            }
            guard count > 0 else { return -1 }
            count -= 1
            return value >= 0 ? value : readValue()
        }

        mutating func unpack(count total: Int) -> [UInt8]? {
            var out = [UInt8](); out.reserveCapacity(total)
            while out.count < total {
                let b = readRle()
                if b < 0 { return nil }
                out.append(UInt8(b))
            }
            return out
        }

        /// Unpacked bytes are stored from the last one to the first
        mutating func unpackBackwards(count total: Int) -> [UInt8]? {
            var out = [UInt8](repeating: 0, count: total)
            var i = total - 1
            while i >= 0 {
                let b = readRle()
                if b < 0 { return nil }
                out[i] = UInt8(b)
                i -= 1
            }
            return out
        }
    }
}
