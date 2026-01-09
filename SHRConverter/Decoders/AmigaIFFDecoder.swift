import Foundation
import CoreGraphics
import AppKit

// MARK: - Amiga IFF/ILBM Decoder

class AmigaIFFDecoder {
    
    static func decode(data: Data) -> (image: CGImage?, type: AppleIIImageType) {
        guard data.count >= 12 else {
            return (nil, .Unknown)
        }
        
        guard let formHeader = String(data: data.subdata(in: 0..<4), encoding: .ascii),
              formHeader == "FORM" else {
            return (nil, .Unknown)
        }
        
        guard let ilbmType = String(data: data.subdata(in: 8..<12), encoding: .ascii),
              ilbmType == "ILBM" else {
            return (nil, .Unknown)
        }
        
        var offset = 12
        var width = 0
        var height = 0
        var numPlanes = 0
        var compression: UInt8 = 0
        var palette: [(r: UInt8, g: UInt8, b: UInt8)] = []
        var bodyOffset = 0
        var bodySize = 0
        var masking: UInt8 = 0
        
        while offset + 8 <= data.count {
            guard let chunkID = String(data: data.subdata(in: offset..<offset+4), encoding: .ascii) else {
                break
            }
            
            let chunkSize = Int(ImageHelpers.readBigEndianUInt32(data: data, offset: offset + 4))
            offset += 8
            
            if offset + chunkSize > data.count {
                break
            }
            
            switch chunkID {
            case "BMHD":
                if chunkSize >= 20 {
                    width = Int(ImageHelpers.readBigEndianUInt16(data: data, offset: offset))
                    height = Int(ImageHelpers.readBigEndianUInt16(data: data, offset: offset + 2))
                    numPlanes = Int(data[offset + 8])
                    masking = data[offset + 9]
                    compression = data[offset + 10]
                }
                
            case "CMAP":
                let numColors = chunkSize / 3
                for i in 0..<numColors {
                    let colorOffset = offset + (i * 3)
                    if colorOffset + 2 < data.count {
                        let r = data[colorOffset]
                        let g = data[colorOffset + 1]
                        let b = data[colorOffset + 2]
                        palette.append((r, g, b))
                    }
                }
                
            case "BODY":
                bodyOffset = offset
                bodySize = chunkSize
            
            default:
                break
            }
            
            offset += chunkSize
            if chunkSize % 2 == 1 {
                offset += 1
            }
        }
        
        guard width > 0, height > 0, numPlanes > 0, bodyOffset > 0 else {
            return (nil, .Unknown)
        }
        
        let is24Bit = (numPlanes == 24 || numPlanes == 25 || numPlanes == 32)
        
        let cgImage: CGImage?
        if is24Bit {
            cgImage = decodeILBM24Body(
                data: data,
                bodyOffset: bodyOffset,
                bodySize: bodySize,
                width: width,
                height: height,
                numPlanes: numPlanes,
                compression: compression,
                masking: masking
            )
        } else {
            cgImage = decodeILBMBody(
                data: data,
                bodyOffset: bodyOffset,
                bodySize: bodySize,
                width: width,
                height: height,
                numPlanes: numPlanes,
                compression: compression,
                palette: palette
            )
        }
        
        guard let finalImage = cgImage else {
            return (nil, .Unknown)
        }
        
        // Aspect ratio correction
        let aspectRatio = Double(height) / Double(width)
        var correctedImage = finalImage
        
        if aspectRatio > 1.2 {
            let correctedWidth = width * 2
            
            let nsImage = NSImage(cgImage: finalImage, size: NSSize(width: width, height: height))
            let newSize = NSSize(width: correctedWidth, height: height)
            
            if let scaledRep = NSBitmapImageRep(
                bitmapDataPlanes: nil,
                pixelsWide: Int(newSize.width),
                pixelsHigh: Int(newSize.height),
                bitsPerSample: 8,
                samplesPerPixel: 4,
                hasAlpha: true,
                isPlanar: false,
                colorSpaceName: .deviceRGB,
                bytesPerRow: Int(newSize.width) * 4,
                bitsPerPixel: 32
            ) {
                NSGraphicsContext.saveGraphicsState()
                NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: scaledRep)
                NSGraphicsContext.current?.imageInterpolation = .none
                nsImage.draw(in: NSRect(origin: .zero, size: newSize))
                NSGraphicsContext.restoreGraphicsState()
                
                if let scaled = scaledRep.cgImage {
                    correctedImage = scaled
                }
            }
        }
        
        let colorDescription = is24Bit ? "24-bit RGB" : "\(1 << numPlanes) colors"
        return (correctedImage, .IFF(width: width, height: height, colors: colorDescription))
    }
    
    private static func decodeILBM24Body(data: Data, bodyOffset: Int, bodySize: Int, width: Int, height: Int, numPlanes: Int, compression: UInt8, masking: UInt8) -> CGImage? {
        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)
        var srcOffset = bodyOffset
        
        let bytesPerRow = ((width + 15) / 16) * 2
        let planesPerChannel = 8
        
        for y in 0..<height {
            var planeBits: [[UInt8]] = Array(repeating: [], count: numPlanes)
            
            for plane in 0..<numPlanes {
                var rowData: [UInt8] = []
                
                if compression == 1 {
                    var bytesRead = 0
                    while bytesRead < bytesPerRow && srcOffset < bodyOffset + bodySize && srcOffset < data.count {
                        let cmd = Int8(bitPattern: data[srcOffset])
                        srcOffset += 1
                        
                        if cmd >= 0 {
                            let count = Int(cmd) + 1
                            for _ in 0..<count {
                                if srcOffset < bodyOffset + bodySize && srcOffset < data.count && bytesRead < bytesPerRow {
                                    rowData.append(data[srcOffset])
                                    srcOffset += 1
                                    bytesRead += 1
                                }
                            }
                        } else if cmd != -128 {
                            let count = Int(-cmd) + 1
                            if srcOffset < bodyOffset + bodySize && srcOffset < data.count {
                                let repeatByte = data[srcOffset]
                                srcOffset += 1
                                for _ in 0..<count {
                                    if bytesRead < bytesPerRow {
                                        rowData.append(repeatByte)
                                        bytesRead += 1
                                    }
                                }
                            }
                        }
                    }
                } else {
                    for _ in 0..<bytesPerRow {
                        if srcOffset < bodyOffset + bodySize && srcOffset < data.count {
                            rowData.append(data[srcOffset])
                            srcOffset += 1
                        }
                    }
                }
                
                planeBits[plane] = rowData
            }
            
            for x in 0..<width {
                let byteIndex = x / 8
                let bitIndex = 7 - (x % 8)
                
                var r: UInt8 = 0
                var g: UInt8 = 0
                var b: UInt8 = 0
                
                for bit in 0..<planesPerChannel {
                    let plane = bit
                    if plane < planeBits.count && byteIndex < planeBits[plane].count {
                        let bitVal = (planeBits[plane][byteIndex] >> bitIndex) & 1
                        r |= bitVal << bit
                    }
                }
                
                for bit in 0..<planesPerChannel {
                    let plane = planesPerChannel + bit
                    if plane < planeBits.count && byteIndex < planeBits[plane].count {
                        let bitVal = (planeBits[plane][byteIndex] >> bitIndex) & 1
                        g |= bitVal << bit
                    }
                }
                
                for bit in 0..<planesPerChannel {
                    let plane = 2 * planesPerChannel + bit
                    if plane < planeBits.count && byteIndex < planeBits[plane].count {
                        let bitVal = (planeBits[plane][byteIndex] >> bitIndex) & 1
                        b |= bitVal << bit
                    }
                }
                
                let bufferIdx = (y * width + x) * 4
                rgbaBuffer[bufferIdx] = r
                rgbaBuffer[bufferIdx + 1] = g
                rgbaBuffer[bufferIdx + 2] = b
                rgbaBuffer[bufferIdx + 3] = 255
            }
        }
        
        return ImageHelpers.createCGImage(from: rgbaBuffer, width: width, height: height)
    }
    
    private static func decodeILBMBody(data: Data, bodyOffset: Int, bodySize: Int, width: Int, height: Int, numPlanes: Int, compression: UInt8, palette: [(r: UInt8, g: UInt8, b: UInt8)]) -> CGImage? {
        let bytesPerRow = ((width + 15) / 16) * 2
        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)
        
        var finalPalette = palette
        let numColors = 1 << numPlanes
        
        if finalPalette.isEmpty || finalPalette.count < numColors {
            finalPalette = []
            for i in 0..<numColors {
                let gray = UInt8((i * 255) / (numColors - 1))
                finalPalette.append((gray, gray, gray))
            }
        }
        
        var srcOffset = bodyOffset
        
        for y in 0..<height {
            var planeBits: [[UInt8]] = Array(repeating: [], count: numPlanes)
            
            for plane in 0..<numPlanes {
                var rowData: [UInt8] = []
                
                if compression == 1 {
                    var bytesRead = 0
                    while bytesRead < bytesPerRow && srcOffset < bodyOffset + bodySize {
                        let cmd = Int8(bitPattern: data[srcOffset])
                        srcOffset += 1
                        
                        if cmd >= 0 {
                            let count = Int(cmd) + 1
                            for _ in 0..<count {
                                if srcOffset < bodyOffset + bodySize && bytesRead < bytesPerRow {
                                    rowData.append(data[srcOffset])
                                    srcOffset += 1
                                    bytesRead += 1
                                }
                            }
                        } else if cmd != -128 {
                            let count = Int(-cmd) + 1
                            if srcOffset < bodyOffset + bodySize {
                                let repeatByte = data[srcOffset]
                                srcOffset += 1
                                for _ in 0..<count {
                                    if bytesRead < bytesPerRow {
                                        rowData.append(repeatByte)
                                        bytesRead += 1
                                    }
                                }
                            }
                        }
                    }
                } else {
                    for _ in 0..<bytesPerRow {
                        if srcOffset < bodyOffset + bodySize {
                            rowData.append(data[srcOffset])
                            srcOffset += 1
                        }
                    }
                }
                
                planeBits[plane] = rowData
            }
            
            for x in 0..<width {
                let byteIndex = x / 8
                let bitIndex = 7 - (x % 8)
                
                var colorIndex = 0
                for plane in 0..<numPlanes {
                    if byteIndex < planeBits[plane].count {
                        let bit = (planeBits[plane][byteIndex] >> bitIndex) & 1
                        colorIndex |= Int(bit) << plane
                    }
                }
                
                let color = finalPalette[min(colorIndex, finalPalette.count - 1)]
                let bufferIdx = (y * width + x) * 4
                
                rgbaBuffer[bufferIdx] = color.r
                rgbaBuffer[bufferIdx + 1] = color.g
                rgbaBuffer[bufferIdx + 2] = color.b
                rgbaBuffer[bufferIdx + 3] = 255
            }
        }
        
        return ImageHelpers.createCGImage(from: rgbaBuffer, width: width, height: height)
    }
}
