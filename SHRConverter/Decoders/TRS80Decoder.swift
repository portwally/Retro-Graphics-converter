import Foundation
import CoreGraphics

// MARK: - TRS-80 Graphics Decoder

class TRS80Decoder {

    // MARK: - TRS-80 Model I/III Block Graphics
    // The original TRS-80 used "semigraphics" - each character cell could display
    // a 2x3 grid of blocks, giving effective resolution of 128x48

    static func decodeBlockGraphics(data: Data) -> (image: CGImage?, type: AppleIIImageType) {
        // Screen memory: 1024 bytes (64 columns x 16 rows)
        // Each byte with high bit set is a graphics character
        // Bits 0-5 represent the 2x3 block pattern

        let charWidth = 64
        let charHeight = 16
        let blockWidth = 2
        let blockHeight = 3
        let width = charWidth * blockWidth   // 128
        let height = charHeight * blockHeight // 48

        guard data.count >= 1024 else {
            return (nil, .Unknown)
        }

        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)

        // TRS-80 phosphor green color
        let greenOn: (r: UInt8, g: UInt8, b: UInt8) = (0x33, 0xFF, 0x33)
        let greenOff: (r: UInt8, g: UInt8, b: UInt8) = (0x00, 0x20, 0x00)

        for charRow in 0..<charHeight {
            for charCol in 0..<charWidth {
                let offset = charRow * charWidth + charCol
                let byte = data[offset]

                // Check if this is a graphics character (bit 7 set, bits 6 = 1 for graphics)
                // Graphics characters are 0x80-0xBF (128-191)
                let isGraphics = (byte & 0x80) != 0

                if isGraphics {
                    // Extract the 6 block bits (arranged as 2 columns x 3 rows)
                    // Bit 0: top-left, Bit 1: top-right
                    // Bit 2: mid-left, Bit 3: mid-right
                    // Bit 4: bot-left, Bit 5: bot-right
                    let blocks = byte & 0x3F

                    for blockRow in 0..<3 {
                        for blockCol in 0..<2 {
                            let bitIndex = blockRow * 2 + blockCol
                            let isOn = (blocks >> bitIndex) & 1 == 1

                            let x = charCol * blockWidth + blockCol
                            let y = charRow * blockHeight + blockRow
                            let bufferIdx = (y * width + x) * 4

                            let rgb = isOn ? greenOn : greenOff
                            rgbaBuffer[bufferIdx] = rgb.r
                            rgbaBuffer[bufferIdx + 1] = rgb.g
                            rgbaBuffer[bufferIdx + 2] = rgb.b
                            rgbaBuffer[bufferIdx + 3] = 255
                        }
                    }
                } else {
                    // Non-graphics character - render as off
                    for blockRow in 0..<3 {
                        for blockCol in 0..<2 {
                            let x = charCol * blockWidth + blockCol
                            let y = charRow * blockHeight + blockRow
                            let bufferIdx = (y * width + x) * 4

                            rgbaBuffer[bufferIdx] = greenOff.r
                            rgbaBuffer[bufferIdx + 1] = greenOff.g
                            rgbaBuffer[bufferIdx + 2] = greenOff.b
                            rgbaBuffer[bufferIdx + 3] = 255
                        }
                    }
                }
            }
        }

        guard let cgImage = ImageHelpers.createCGImage(from: rgbaBuffer, width: width, height: height) else {
            return (nil, .Unknown)
        }

        return (cgImage, .TRS80(model: "Model I/III", resolution: "128x48"))
    }

    // MARK: - CoCo Color Palette

    static let cocoPalette: [(r: UInt8, g: UInt8, b: UInt8)] = [
        (0x00, 0xFF, 0x00),  // 0: Green
        (0xFF, 0xFF, 0x00),  // 1: Yellow
        (0x00, 0x00, 0xFF),  // 2: Blue
        (0xFF, 0x00, 0x00),  // 3: Red
        (0xFF, 0xFF, 0xFF),  // 4: Buff (White)
        (0x00, 0xFF, 0xFF),  // 5: Cyan
        (0xFF, 0x00, 0xFF),  // 6: Magenta
        (0xFF, 0x80, 0x00),  // 7: Orange
        (0x00, 0x00, 0x00),  // 8: Black
        (0x00, 0x80, 0x00),  // 9: Dark Green
        (0x00, 0x00, 0x80),  // 10: Dark Blue
        (0x80, 0x00, 0x00),  // 11: Dark Red
        (0x80, 0x80, 0x80),  // 12: Gray
        (0x00, 0x80, 0x80),  // 13: Dark Cyan
        (0x80, 0x00, 0x80),  // 14: Dark Magenta
        (0x80, 0x40, 0x00)   // 15: Brown
    ]

    // CoCo artifact colors (for PMODE 4)
    static let cocoArtifactColors: [(r: UInt8, g: UInt8, b: UInt8)] = [
        (0x00, 0x00, 0x00),  // Black
        (0x00, 0x80, 0xFF),  // Blue artifact
        (0xFF, 0x80, 0x00),  // Orange artifact
        (0xFF, 0xFF, 0xFF)   // White
    ]

    // MARK: - CoCo PMODE 3 Decoder (128x192, 4 colors)
    // Common format: 6144 bytes

    static func decodePMode3(data: Data) -> (image: CGImage?, type: AppleIIImageType) {
        let width = 128
        let height = 192
        let bytesPerLine = 32  // 128 pixels * 2 bits / 8 = 32 bytes
        let expectedSize = bytesPerLine * height  // 6144 bytes

        guard data.count >= expectedSize else {
            return (nil, .Unknown)
        }

        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)

        // Color set 0: Green, Yellow, Blue, Red
        let colorSet = [0, 1, 2, 3]

        for y in 0..<height {
            for byteX in 0..<bytesPerLine {
                let offset = y * bytesPerLine + byteX
                guard offset < data.count else { continue }

                let byte = data[offset]

                // 4 pixels per byte, 2 bits each
                for pixel in 0..<4 {
                    let shift = (3 - pixel) * 2
                    let colorIndex = Int((byte >> shift) & 0x03)
                    let color = colorSet[colorIndex]

                    let x = byteX * 4 + pixel
                    let bufferIdx = (y * width + x) * 4

                    let rgb = cocoPalette[color]
                    rgbaBuffer[bufferIdx] = rgb.r
                    rgbaBuffer[bufferIdx + 1] = rgb.g
                    rgbaBuffer[bufferIdx + 2] = rgb.b
                    rgbaBuffer[bufferIdx + 3] = 255
                }
            }
        }

        guard let cgImage = ImageHelpers.createCGImage(from: rgbaBuffer, width: width, height: height) else {
            return (nil, .Unknown)
        }

        return (cgImage, .TRS80(model: "CoCo", resolution: "128x192, 4 colors"))
    }

    // MARK: - CoCo PMODE 4 Decoder (256x192, 2 colors with artifacts)
    // Common format: 6144 bytes

    static func decodePMode4(data: Data) -> (image: CGImage?, type: AppleIIImageType) {
        let width = 256
        let height = 192
        let bytesPerLine = 32  // 256 pixels / 8 = 32 bytes
        let expectedSize = bytesPerLine * height  // 6144 bytes

        guard data.count >= expectedSize else {
            return (nil, .Unknown)
        }

        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)

        // Simple 2-color mode (green on black or white on black)
        let colorOn: (r: UInt8, g: UInt8, b: UInt8) = (0x00, 0xFF, 0x00)
        let colorOff: (r: UInt8, g: UInt8, b: UInt8) = (0x00, 0x00, 0x00)

        for y in 0..<height {
            for byteX in 0..<bytesPerLine {
                let offset = y * bytesPerLine + byteX
                guard offset < data.count else { continue }

                let byte = data[offset]

                // 8 pixels per byte
                for bit in 0..<8 {
                    let pixel = (byte >> (7 - bit)) & 1
                    let x = byteX * 8 + bit
                    let bufferIdx = (y * width + x) * 4

                    let rgb = pixel == 1 ? colorOn : colorOff
                    rgbaBuffer[bufferIdx] = rgb.r
                    rgbaBuffer[bufferIdx + 1] = rgb.g
                    rgbaBuffer[bufferIdx + 2] = rgb.b
                    rgbaBuffer[bufferIdx + 3] = 255
                }
            }
        }

        guard let cgImage = ImageHelpers.createCGImage(from: rgbaBuffer, width: width, height: height) else {
            return (nil, .Unknown)
        }

        return (cgImage, .TRS80(model: "CoCo", resolution: "256x192, 2 colors"))
    }

    // MARK: - CoCo PMODE 4 with Artifact Colors
    // Simulates the NTSC artifact coloring

    static func decodePMode4Artifact(data: Data) -> (image: CGImage?, type: AppleIIImageType) {
        let width = 256
        let height = 192
        let bytesPerLine = 32
        let expectedSize = bytesPerLine * height

        guard data.count >= expectedSize else {
            return (nil, .Unknown)
        }

        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)

        for y in 0..<height {
            for byteX in 0..<bytesPerLine {
                let offset = y * bytesPerLine + byteX
                guard offset < data.count else { continue }

                let byte = data[offset]

                // Process pairs of bits for artifact colors
                for bitPair in 0..<4 {
                    let shift = (3 - bitPair) * 2
                    let bits = (byte >> shift) & 0x03

                    let x = byteX * 8 + bitPair * 2

                    // Artifact color mapping
                    let rgb = cocoArtifactColors[Int(bits)]

                    // Two pixels per artifact color
                    for px in 0..<2 {
                        let bufferIdx = (y * width + x + px) * 4
                        rgbaBuffer[bufferIdx] = rgb.r
                        rgbaBuffer[bufferIdx + 1] = rgb.g
                        rgbaBuffer[bufferIdx + 2] = rgb.b
                        rgbaBuffer[bufferIdx + 3] = 255
                    }
                }
            }
        }

        guard let cgImage = ImageHelpers.createCGImage(from: rgbaBuffer, width: width, height: height) else {
            return (nil, .Unknown)
        }

        return (cgImage, .TRS80(model: "CoCo", resolution: "256x192, Artifact"))
    }

    // MARK: - CoCo 3 320x200 16-color mode
    // Screen memory: 32000 bytes (4 bits per pixel)

    static func decodeCoCo3_320(data: Data) -> (image: CGImage?, type: AppleIIImageType) {
        let width = 320
        let height = 200
        let bytesPerLine = 160  // 320 pixels * 4 bits / 8 = 160 bytes
        let expectedSize = bytesPerLine * height  // 32000 bytes

        guard data.count >= expectedSize else {
            return (nil, .Unknown)
        }

        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)

        for y in 0..<height {
            for byteX in 0..<bytesPerLine {
                let offset = y * bytesPerLine + byteX
                guard offset < data.count else { continue }

                let byte = data[offset]

                // 2 pixels per byte, 4 bits each
                let pixel1 = Int((byte >> 4) & 0x0F)
                let pixel2 = Int(byte & 0x0F)

                let x = byteX * 2

                // First pixel
                let bufferIdx1 = (y * width + x) * 4
                let rgb1 = cocoPalette[pixel1]
                rgbaBuffer[bufferIdx1] = rgb1.r
                rgbaBuffer[bufferIdx1 + 1] = rgb1.g
                rgbaBuffer[bufferIdx1 + 2] = rgb1.b
                rgbaBuffer[bufferIdx1 + 3] = 255

                // Second pixel
                if x + 1 < width {
                    let bufferIdx2 = (y * width + x + 1) * 4
                    let rgb2 = cocoPalette[pixel2]
                    rgbaBuffer[bufferIdx2] = rgb2.r
                    rgbaBuffer[bufferIdx2 + 1] = rgb2.g
                    rgbaBuffer[bufferIdx2 + 2] = rgb2.b
                    rgbaBuffer[bufferIdx2 + 3] = 255
                }
            }
        }

        guard let cgImage = ImageHelpers.createCGImage(from: rgbaBuffer, width: width, height: height) else {
            return (nil, .Unknown)
        }

        return (cgImage, .TRS80(model: "CoCo 3", resolution: "320x200, 16 colors"))
    }

    // MARK: - CoCo 3 640x200 4-color mode
    // Screen memory: 32000 bytes (2 bits per pixel)

    static func decodeCoCo3_640(data: Data) -> (image: CGImage?, type: AppleIIImageType) {
        let width = 640
        let height = 200
        let bytesPerLine = 160  // 640 pixels * 2 bits / 8 = 160 bytes
        let expectedSize = bytesPerLine * height  // 32000 bytes

        guard data.count >= expectedSize else {
            return (nil, .Unknown)
        }

        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)

        // 4-color palette subset
        let colorSet = [0, 4, 2, 8]  // Green, Buff, Blue, Black

        for y in 0..<height {
            for byteX in 0..<bytesPerLine {
                let offset = y * bytesPerLine + byteX
                guard offset < data.count else { continue }

                let byte = data[offset]

                // 4 pixels per byte, 2 bits each
                for pixel in 0..<4 {
                    let shift = (3 - pixel) * 2
                    let colorIndex = Int((byte >> shift) & 0x03)
                    let color = colorSet[colorIndex]

                    let x = byteX * 4 + pixel
                    let bufferIdx = (y * width + x) * 4

                    let rgb = cocoPalette[color]
                    rgbaBuffer[bufferIdx] = rgb.r
                    rgbaBuffer[bufferIdx + 1] = rgb.g
                    rgbaBuffer[bufferIdx + 2] = rgb.b
                    rgbaBuffer[bufferIdx + 3] = 255
                }
            }
        }

        guard let cgImage = ImageHelpers.createCGImage(from: rgbaBuffer, width: width, height: height) else {
            return (nil, .Unknown)
        }

        return (cgImage, .TRS80(model: "CoCo 3", resolution: "640x200, 4 colors"))
    }

    // MARK: - Auto-detect TRS-80 format

    static func decode(data: Data, filename: String? = nil) -> (image: CGImage?, type: AppleIIImageType) {
        let dataSize = data.count

        // Try to determine format by file extension
        let ext = filename?.split(separator: ".").last?.lowercased() ?? ""

        switch ext {
        case "bin", "cas" where dataSize == 1024:
            return decodeBlockGraphics(data: data)
        case "max", "pic" where dataSize == 6144:
            return decodePMode4(data: data)
        case "cm3", "pi3":
            if dataSize >= 32000 {
                return decodeCoCo3_320(data: data)
            }
        default:
            break
        }

        // Auto-detect by size
        if dataSize == 1024 {
            // TRS-80 Model I/III block graphics
            return decodeBlockGraphics(data: data)
        } else if dataSize == 6144 {
            // CoCo PMODE 3 or PMODE 4
            // Try to detect by analyzing data patterns
            // Default to PMODE 4 (most common)
            return decodePMode4(data: data)
        } else if dataSize == 3072 {
            // CoCo PMODE 0/1/2 (128x96 or 128x192, less memory)
            return decodePMode3(data: data)
        } else if dataSize >= 32000 {
            // CoCo 3 modes
            return decodeCoCo3_320(data: data)
        }

        return (nil, .Unknown)
    }
}
