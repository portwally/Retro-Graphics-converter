import Foundation
import CoreGraphics

// MARK: - PC Image Decoder (PCX, BMP)

class PCImageDecoder {
    
    // MARK: - BMP Decoder
    
    static func decodeBMP(data: Data) -> (image: CGImage?, type: AppleIIImageType) {
        guard data.count >= 54, data[0] == 0x42, data[1] == 0x4D else { return (nil, .Unknown) }
        
        let dibHeaderSize = Int(data[14]) | (Int(data[15]) << 8) | (Int(data[16]) << 16) | (Int(data[17]) << 24)
        let width = Int(data[18]) | (Int(data[19]) << 8) | (Int(data[20]) << 16) | (Int(data[21]) << 24)
        var height = Int(data[22]) | (Int(data[23]) << 8) | (Int(data[24]) << 16) | (Int(data[25]) << 24)
        let topDown = height < 0; if topDown { height = -height }
        let bitsPerPixel = Int(data[28]) | (Int(data[29]) << 8)
        let compression = Int(data[30]) | (Int(data[31]) << 8) | (Int(data[32]) << 16) | (Int(data[33]) << 24)
        
        guard compression == 0, width > 0, height > 0, width < 10000, height < 10000 else { return (nil, .Unknown) }
        
        let pixelDataOffset = Int(data[10]) | (Int(data[11]) << 8) | (Int(data[12]) << 16) | (Int(data[13]) << 24)
        
        var palette: [(r: UInt8, g: UInt8, b: UInt8)] = []
        if bitsPerPixel <= 8 {
            let numColors = 1 << bitsPerPixel
            let paletteOffset = 14 + dibHeaderSize
            for i in 0..<numColors {
                let offset = paletteOffset + (i * 4)
                if offset + 3 < data.count {
                    palette.append((data[offset + 2], data[offset + 1], data[offset]))
                }
            }
        }
        
        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)
        let rowSize = ((bitsPerPixel * width + 31) / 32) * 4
        
        for y in 0..<height {
            let actualY = topDown ? y : (height - 1 - y)
            let rowOffset = pixelDataOffset + (y * rowSize)
            
            for x in 0..<width {
                var r: UInt8 = 0, g: UInt8 = 0, b: UInt8 = 0
                
                switch bitsPerPixel {
                case 24:
                    let pixelOffset = rowOffset + (x * 3)
                    if pixelOffset + 2 < data.count { b = data[pixelOffset]; g = data[pixelOffset + 1]; r = data[pixelOffset + 2] }
                case 8:
                    let pixelOffset = rowOffset + x
                    if pixelOffset < data.count, Int(data[pixelOffset]) < palette.count {
                        let c = palette[Int(data[pixelOffset])]; r = c.r; g = c.g; b = c.b
                    }
                case 4:
                    let byteOffset = rowOffset + (x / 2)
                    if byteOffset < data.count {
                        let paletteIndex = (x % 2 == 0) ? Int(data[byteOffset] >> 4) : Int(data[byteOffset] & 0x0F)
                        if paletteIndex < palette.count { let c = palette[paletteIndex]; r = c.r; g = c.g; b = c.b }
                    }
                case 1:
                    let byteOffset = rowOffset + (x / 8)
                    if byteOffset < data.count {
                        let bit = (data[byteOffset] >> (7 - (x % 8))) & 1
                        if Int(bit) < palette.count { let c = palette[Int(bit)]; r = c.r; g = c.g; b = c.b }
                    }
                default: break
                }
                
                let bufferIdx = (actualY * width + x) * 4
                rgbaBuffer[bufferIdx] = r; rgbaBuffer[bufferIdx + 1] = g; rgbaBuffer[bufferIdx + 2] = b; rgbaBuffer[bufferIdx + 3] = 255
            }
        }
        
        guard let cgImage = ImageHelpers.createCGImage(from: rgbaBuffer, width: width, height: height) else { return (nil, .Unknown) }
        return (cgImage, .BMP(width: width, height: height, bitsPerPixel: bitsPerPixel))
    }
    
    // MARK: - PCX Decoder

    static func decodePCX(data: Data) -> (image: CGImage?, type: AppleIIImageType) {
        guard data.count >= 128, data[0] == 0x0A else { return (nil, .Unknown) }

        let bitsPerPixel = Int(data[3])
        let xMin = Int(data[4]) | (Int(data[5]) << 8), yMin = Int(data[6]) | (Int(data[7]) << 8)
        let xMax = Int(data[8]) | (Int(data[9]) << 8), yMax = Int(data[10]) | (Int(data[11]) << 8)
        let width = xMax - xMin + 1, height = yMax - yMin + 1
        let numPlanes = Int(data[65]), bytesPerLine = Int(data[66]) | (Int(data[67]) << 8)

        guard width > 0, height > 0, width < 10000, height < 10000 else { return (nil, .Unknown) }

        // Calculate actual bits per pixel from bytesPerLine
        // Some PCX files have incorrect bitsPerPixel in header but correct bytesPerLine
        let calculatedBitsPerPixel = (bytesPerLine * 8) / width
        let effectiveBitsPerPixel: Int
        let effectiveNumPlanes: Int

        // Detect CGA 4-color mode: header says 1bpp but bytesPerLine indicates 2bpp
        if bitsPerPixel == 1 && numPlanes == 1 && calculatedBitsPerPixel == 2 {
            effectiveBitsPerPixel = 2
            effectiveNumPlanes = 1
        } else {
            effectiveBitsPerPixel = bitsPerPixel
            effectiveNumPlanes = numPlanes
        }

        let totalBitsPerPixel = effectiveBitsPerPixel * effectiveNumPlanes

        // Decompress RLE data
        var decompressedData: [UInt8] = []
        var offset = 128
        let scanlineSize = bytesPerLine * numPlanes
        let expectedSize = scanlineSize * height

        while offset < data.count && decompressedData.count < expectedSize {
            let byte = data[offset]
            offset += 1
            if (byte & 0xC0) == 0xC0 {
                let count = Int(byte & 0x3F)
                if offset < data.count {
                    let value = data[offset]
                    offset += 1
                    for _ in 0..<count {
                        decompressedData.append(value)
                    }
                }
            } else {
                decompressedData.append(byte)
            }
        }

        // Read palette from header (16 colors at offset 16-63)
        var headerPalette: [(r: UInt8, g: UInt8, b: UInt8)] = []
        for i in 0..<16 {
            let paletteOffset = 16 + i * 3
            if paletteOffset + 2 < data.count {
                headerPalette.append((data[paletteOffset], data[paletteOffset + 1], data[paletteOffset + 2]))
            }
        }

        // Read VGA palette from end of file (256 colors) if present
        var vgaPalette: [(r: UInt8, g: UInt8, b: UInt8)] = []
        if data.count >= 769 {
            let paletteMarkerOffset = data.count - 769
            if data[paletteMarkerOffset] == 0x0C {
                for i in 0..<256 {
                    let pOffset = paletteMarkerOffset + 1 + i * 3
                    if pOffset + 2 < data.count {
                        vgaPalette.append((data[pOffset], data[pOffset + 1], data[pOffset + 2]))
                    }
                }
            }
        }

        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)

        // 8-bit VGA (256 colors) - single plane, 8 bits per pixel
        if bitsPerPixel == 8 && numPlanes == 1 {
            let palette = vgaPalette.isEmpty ? createGrayscalePalette(256) : vgaPalette
            for y in 0..<height {
                for x in 0..<width {
                    let dataIndex = y * bytesPerLine + x
                    let paletteIndex = dataIndex < decompressedData.count ? min(Int(decompressedData[dataIndex]), palette.count - 1) : 0
                    let color = palette[paletteIndex]
                    let bufferIdx = (y * width + x) * 4
                    rgbaBuffer[bufferIdx] = color.r
                    rgbaBuffer[bufferIdx + 1] = color.g
                    rgbaBuffer[bufferIdx + 2] = color.b
                    rgbaBuffer[bufferIdx + 3] = 255
                }
            }
        }
        // 24-bit RGB - 3 planes, 8 bits per pixel per plane
        else if bitsPerPixel == 8 && numPlanes == 3 {
            for y in 0..<height {
                let rowOffset = y * scanlineSize
                for x in 0..<width {
                    let rOffset = rowOffset + x
                    let gOffset = rowOffset + bytesPerLine + x
                    let bOffset = rowOffset + bytesPerLine * 2 + x
                    let r = rOffset < decompressedData.count ? decompressedData[rOffset] : 0
                    let g = gOffset < decompressedData.count ? decompressedData[gOffset] : 0
                    let b = bOffset < decompressedData.count ? decompressedData[bOffset] : 0
                    let bufferIdx = (y * width + x) * 4
                    rgbaBuffer[bufferIdx] = r
                    rgbaBuffer[bufferIdx + 1] = g
                    rgbaBuffer[bufferIdx + 2] = b
                    rgbaBuffer[bufferIdx + 3] = 255
                }
            }
        }
        // EGA 16-color planar (1 bit per pixel, 4 planes)
        else if bitsPerPixel == 1 && numPlanes == 4 {
            let palette = headerPalette.isEmpty ? createEGAPalette() : headerPalette
            for y in 0..<height {
                let rowOffset = y * scanlineSize
                for x in 0..<width {
                    let byteIndex = x / 8
                    let bitIndex = 7 - (x % 8)

                    var colorIndex = 0
                    for plane in 0..<4 {
                        let planeOffset = rowOffset + plane * bytesPerLine + byteIndex
                        if planeOffset < decompressedData.count {
                            let bit = (decompressedData[planeOffset] >> bitIndex) & 1
                            colorIndex |= Int(bit) << plane
                        }
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
        // EGA 64-color planar (2 bits per pixel, 4 planes) - used by some EGA modes
        else if bitsPerPixel == 2 && numPlanes == 4 {
            // Create EGA 64-color palette (6-bit RGB)
            let palette = createEGA64Palette()
            for y in 0..<height {
                let rowOffset = y * scanlineSize
                for x in 0..<width {
                    let byteIndex = x / 4
                    let pixelInByte = 3 - (x % 4)
                    let shift = pixelInByte * 2

                    var colorIndex = 0
                    for plane in 0..<4 {
                        let planeOffset = rowOffset + plane * bytesPerLine + byteIndex
                        if planeOffset < decompressedData.count {
                            let bits = (decompressedData[planeOffset] >> shift) & 0x03
                            colorIndex |= Int(bits) << (plane * 2)
                        }
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
        // CGA 4-color (2 bits per pixel, 1 plane)
        else if effectiveBitsPerPixel == 2 && effectiveNumPlanes == 1 {
            // Use header palette if available, otherwise use default CGA palette
            let palette: [(r: UInt8, g: UInt8, b: UInt8)]
            if !headerPalette.isEmpty && headerPalette.count >= 4 {
                palette = Array(headerPalette.prefix(4))
            } else {
                // Default CGA palette 1 (cyan, magenta, white)
                palette = [(0, 0, 0), (0, 170, 170), (170, 0, 170), (170, 170, 170)]
            }
            for y in 0..<height {
                for x in 0..<width {
                    let byteIndex = y * bytesPerLine + (x / 4)
                    let pixelInByte = 3 - (x % 4)
                    if byteIndex < decompressedData.count {
                        let colorIndex = Int((decompressedData[byteIndex] >> (pixelInByte * 2)) & 0x03)
                        let color = palette[min(colorIndex, palette.count - 1)]
                        let bufferIdx = (y * width + x) * 4
                        rgbaBuffer[bufferIdx] = color.r
                        rgbaBuffer[bufferIdx + 1] = color.g
                        rgbaBuffer[bufferIdx + 2] = color.b
                        rgbaBuffer[bufferIdx + 3] = 255
                    }
                }
            }
        }
        // Monochrome (1 bit per pixel, 1 plane)
        else if bitsPerPixel == 1 && numPlanes == 1 {
            let palette = headerPalette.count >= 2 ? Array(headerPalette.prefix(2)) : [(UInt8(0), UInt8(0), UInt8(0)), (UInt8(255), UInt8(255), UInt8(255))]
            for y in 0..<height {
                for x in 0..<width {
                    let byteIndex = y * bytesPerLine + (x / 8)
                    let bitIndex = 7 - (x % 8)
                    if byteIndex < decompressedData.count {
                        let bit = Int((decompressedData[byteIndex] >> bitIndex) & 1)
                        let color = palette[min(bit, palette.count - 1)]
                        let bufferIdx = (y * width + x) * 4
                        rgbaBuffer[bufferIdx] = color.r
                        rgbaBuffer[bufferIdx + 1] = color.g
                        rgbaBuffer[bufferIdx + 2] = color.b
                        rgbaBuffer[bufferIdx + 3] = 255
                    }
                }
            }
        }
        // 4-bit single plane (16 colors packed, 2 pixels per byte)
        else if bitsPerPixel == 4 && numPlanes == 1 {
            let palette = headerPalette.isEmpty ? createEGAPalette() : headerPalette
            for y in 0..<height {
                for x in 0..<width {
                    let byteIndex = y * bytesPerLine + (x / 2)
                    if byteIndex < decompressedData.count {
                        let colorIndex: Int
                        if x % 2 == 0 {
                            colorIndex = Int(decompressedData[byteIndex] >> 4)
                        } else {
                            colorIndex = Int(decompressedData[byteIndex] & 0x0F)
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
        }
        // Fallback for other formats
        else {
            // Try to decode as indexed color
            let palette = headerPalette.isEmpty ? createGrayscalePalette(256) : headerPalette
            for y in 0..<height {
                for x in 0..<width {
                    let dataIndex = y * bytesPerLine + x
                    if dataIndex < decompressedData.count {
                        let colorIndex = min(Int(decompressedData[dataIndex]), palette.count - 1)
                        let color = palette[colorIndex]
                        let bufferIdx = (y * width + x) * 4
                        rgbaBuffer[bufferIdx] = color.r
                        rgbaBuffer[bufferIdx + 1] = color.g
                        rgbaBuffer[bufferIdx + 2] = color.b
                        rgbaBuffer[bufferIdx + 3] = 255
                    }
                }
            }
        }

        guard let cgImage = ImageHelpers.createCGImage(from: rgbaBuffer, width: width, height: height) else { return (nil, .Unknown) }
        return (cgImage, .PCX(width: width, height: height, bitsPerPixel: totalBitsPerPixel))
    }

    // MARK: - PCX Palette Helpers

    private static func createEGAPalette() -> [(r: UInt8, g: UInt8, b: UInt8)] {
        // Standard EGA 16-color palette
        return [
            (0, 0, 0),       // 0: Black
            (0, 0, 170),     // 1: Blue
            (0, 170, 0),     // 2: Green
            (0, 170, 170),   // 3: Cyan
            (170, 0, 0),     // 4: Red
            (170, 0, 170),   // 5: Magenta
            (170, 85, 0),    // 6: Brown
            (170, 170, 170), // 7: Light Gray
            (85, 85, 85),    // 8: Dark Gray
            (85, 85, 255),   // 9: Light Blue
            (85, 255, 85),   // 10: Light Green
            (85, 255, 255),  // 11: Light Cyan
            (255, 85, 85),   // 12: Light Red
            (255, 85, 255),  // 13: Light Magenta
            (255, 255, 85),  // 14: Yellow
            (255, 255, 255)  // 15: White
        ]
    }

    private static func createEGA64Palette() -> [(r: UInt8, g: UInt8, b: UInt8)] {
        // EGA 64-color palette (2 bits per RGB component)
        var palette: [(r: UInt8, g: UInt8, b: UInt8)] = []
        for i in 0..<64 {
            // EGA 64-color: RrGgBb format (2 bits each)
            let r = ((i >> 5) & 1) * 170 + ((i >> 2) & 1) * 85
            let g = ((i >> 4) & 1) * 170 + ((i >> 1) & 1) * 85
            let b = ((i >> 3) & 1) * 170 + (i & 1) * 85
            palette.append((UInt8(r), UInt8(g), UInt8(b)))
        }
        return palette
    }

    private static func createGrayscalePalette(_ count: Int) -> [(r: UInt8, g: UInt8, b: UInt8)] {
        var palette: [(r: UInt8, g: UInt8, b: UInt8)] = []
        for i in 0..<count {
            let gray = UInt8((i * 255) / max(count - 1, 1))
            palette.append((gray, gray, gray))
        }
        return palette
    }
}
