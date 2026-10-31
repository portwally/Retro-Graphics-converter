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
        default: return nil
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
