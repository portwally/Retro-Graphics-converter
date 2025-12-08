import SwiftUI
import UniformTypeIdentifiers
import CoreGraphics
import ImageIO
import AppKit

// MARK: - New Types and Enums (Unchanged)

enum ExportFormat: String, CaseIterable {
    case png = "PNG"
    case jpeg = "JPEG"
    case tiff = "TIFF"
    case gif = "GIF"
    case heic = "HEIC (HEIF)"
    
    var fileExtension: String {
        switch self {
        case .png: return "png"
        case .jpeg: return "jpg"
        case .tiff: return "tiff"
        case .gif: return "gif"
        case .heic: return "heic"
        }
    }
}

enum AppleIIImageType: Equatable {
    case SHR(mode: String)
    case DHGR
    case HGR
    case Unknown
    
    var resolution: (width: Int, height: Int) {
        switch self {
        case .SHR: return (320, 200)
        case .DHGR: return (560, 192)
        case .HGR: return (280, 192)
        case .Unknown: return (0, 0)
        }
    }
}

// MARK: - Main App Entry Point (Unchanged)
@main
struct SHRConverterApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 550, minHeight: 500)
        }
    }
}

// MARK: - UI View (Unchanged)

struct ContentView: View {
    @State private var filesToConvert: [URL] = []
    @State private var lastConvertedImage: NSImage?
    @State private var detectedType: AppleIIImageType = .Unknown
    @State private var selectedExportFormat: ExportFormat = .png
    @State private var statusMessage: String = "Drag files or open a single file."
    @State private var isProcessing = false
    @State private var progressString = ""
    
    var body: some View {
        VStack(spacing: 20) {
            // Drop Zone Area
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [10]))
                    .foregroundColor(isProcessing ? .blue : (filesToConvert.isEmpty ? .secondary : .green))
                    .background(Color(NSColor.controlBackgroundColor))
                
                if let img = lastConvertedImage {
                    Image(nsImage: img)
                        .resizable()
                        .interpolation(.none)
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 350)
                        .padding()
                } else {
                    VStack(spacing: 15) {
                        Image(systemName: "square.stack.3d.down.right")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("Apple II Graphics Converter")
                            .font(.headline)
                        Text("Supports SHR, HGR, and DHGR formats.")
                            .multilineTextAlignment(.center)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                if isProcessing {
                    ProgressView()
                        .scaleEffect(1.5)
                }
            }
            .frame(height: 350)
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                loadDroppedFiles(providers)
                return true
            }
            
            // Controls Bar
            HStack {
                // Open File Button
                Button("Open Single File...") {
                    openSingleFile()
                }
                
                // Export Format Picker
                Picker("Export As:", selection: $selectedExportFormat) {
                    ForEach(ExportFormat.allCases, id: \.self) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                .frame(width: 180)
                
                Spacer()
                
                // Convert Button
                Button("Convert \(filesToConvert.count) File(s) to \(selectedExportFormat.rawValue)...") {
                    selectOutputFolderAndConvert()
                }
                .disabled(filesToConvert.isEmpty || isProcessing)
            }
            
            // Status Bar
            VStack(alignment: .leading) {
                Text(statusMessage)
                    .font(.headline)
                if !progressString.isEmpty {
                    Text(progressString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
    }
    
    // MARK: - File Handling and Conversion Logic (Unchanged)
    
    func clearState() {
        lastConvertedImage = nil
        filesToConvert = []
        statusMessage = "Ready for the next task."
        progressString = ""
        isProcessing = false
        detectedType = .Unknown
    }
    
    func openSingleFile() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.data]
        openPanel.allowsMultipleSelection = false
        openPanel.prompt = "Open Apple II/IIGS Graphics File"

        if openPanel.runModal() == .OK, let url = openPanel.url {
            clearState()
            self.filesToConvert = [url]
            self.statusMessage = "1 file loaded. Click 'Convert...' to proceed."
        }
    }
    
    func loadDroppedFiles(_ providers: [NSItemProvider]) {
        self.isProcessing = true
        self.statusMessage = "Collecting dropped files..."
        self.progressString = ""
        self.filesToConvert = []
        
        let group = DispatchGroup()
        var collectedURLs: [URL] = []
        
        for provider in providers {
            group.enter()
            provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { (item, error) in
                if let urlData = item as? Data, let url = URL(dataRepresentation: urlData, relativeTo: nil) {
                    collectedURLs.append(url)
                } else if let url = item as? URL {
                    collectedURLs.append(url)
                }
                group.leave()
            }
        }
        
        group.notify(queue: .main) {
            self.isProcessing = false
            self.filesToConvert = collectedURLs
            self.statusMessage = "Ready to convert \(collectedURLs.count) files."
        }
    }
    
    func selectOutputFolderAndConvert() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.prompt = "Select folder to save \(selectedExportFormat.rawValue) files"

        if openPanel.runModal() == .OK, let outputFolderURL = openPanel.url {
            self.isProcessing = true
            processBatch(inputURLs: self.filesToConvert, outputDir: outputFolderURL, format: selectedExportFormat)
        } else {
            self.statusMessage = "Output folder selection cancelled."
        }
    }
    
    func processBatch(inputURLs: [URL], outputDir: URL, format: ExportFormat) {
        var successCount = 0
        var failCount = 0
        
        DispatchQueue.global(qos: .userInitiated).async {
            for (index, url) in inputURLs.enumerated() {
                
                DispatchQueue.main.async {
                    self.statusMessage = "Processing \(index + 1) of \(inputURLs.count)"
                    self.progressString = "Converting: \(url.lastPathComponent) to \(format.rawValue)"
                }
                
                let result = SHRDecoder.decode(data: (try? Data(contentsOf: url)) ?? Data())
                
                if let cgImage = result.image, result.type != .Unknown {
                    // Use NSImage initializer that respects CGImage resolution
                    let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: result.type.resolution.width, height: result.type.resolution.height))
                    
                    if saveImage(image: nsImage, originalURL: url, outputDir: outputDir, format: format) {
                        successCount += 1
                        DispatchQueue.main.async {
                            self.lastConvertedImage = nsImage
                            self.detectedType = result.type
                        }
                    } else {
                        failCount += 1
                    }
                } else {
                    failCount += 1
                }
            }
            
            DispatchQueue.main.async {
                self.isProcessing = false
                self.filesToConvert = []
                self.statusMessage = "Batch Complete! \(format.rawValue) files saved."
                self.progressString = "Converted: \(successCount) | Failed/Ignored: \(failCount)."
            }
        }
    }
    
    func saveImage(image: NSImage, originalURL: URL, outputDir: URL, format: ExportFormat) -> Bool {
        let filenameWithoutExt = originalURL.deletingPathExtension().lastPathComponent
        let newFilename = "\(filenameWithoutExt).\(format.fileExtension)"
        let outputURL = outputDir.appendingPathComponent(newFilename)
        
        guard let tiffData = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiffData) else {
            return false
        }
        
        var outputData: Data? = nil
        
        switch format {
        case .png:
            outputData = bitmap.representation(using: .png, properties: [:])
        case .jpeg:
            outputData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.9])
        case .tiff:
            outputData = bitmap.representation(using: .tiff, properties: [:])
        case .gif:
            outputData = bitmap.representation(using: .gif, properties: [.ditherTransparency: true])
        case .heic:
            guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return false }
            outputData = HEICConverter.convert(cgImage: cgImage)
        }
        
        guard let finalData = outputData else { return false }
        
        do {
            try finalData.write(to: outputURL)
            return true
        } catch {
            print("Error saving to \(outputURL.path): \(error)")
            return false
        }
    }
}

// MARK: - HEIC Helper (Unchanged)

class HEICConverter {
    static func convert(cgImage: CGImage) -> Data? {
        let mutableData = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(mutableData, UTType.heic.identifier as CFString, 1, nil) else { return nil }
        
        let options: NSDictionary = [
            kCGImageDestinationLossyCompressionQuality: 0.9
        ]
        
        CGImageDestinationAddImage(destination, cgImage, options)
        
        guard CGImageDestinationFinalize(destination) else { return nil }
        
        return mutableData as Data
    }
}


// MARK: - SHRDecoder (FINAL DHGR MAP TWEAK & HGR COLOR POLARITY REVERSAL)

class SHRDecoder {
    
    static func decode(data: Data) -> (image: CGImage?, type: AppleIIImageType) {
        let size = data.count
        
        let type: AppleIIImageType
        let image: CGImage?
        
        switch size {
        case 32768:
            type = .SHR(mode: "Standard")
            image = decodeSHR(data: data, is3200Color: false)
        case 38400...:
            type = .SHR(mode: "3200 Color")
            image = decodeSHR(data: data, is3200Color: true)
        case 8192:
            type = .HGR
            image = decodeHGR(data: data)
        case 16384:
            type = .DHGR
            image = decodeDHGR(data: data)
        default:
            type = .Unknown
            image = nil
        }
        
        return (image, type)
    }
    
    // --- DHGR Decoder (560x192, 16KB) - FINAL DHGR MAP TWEAK ---
    static func decodeDHGR(data: Data) -> CGImage? {
           let width = 560  // Volle Breite zurück
           let height = 192
           var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)
           
           guard data.count >= 16384 else { return nil }
           
           let mainData = data.subdata(in: 0..<8192)
           let auxData = data.subdata(in: 8192..<16384)
           
           // Apple IIgs DHGR Palette
        let dhgrPalette: [(r: UInt8, g: UInt8, b: UInt8)] = [
            (0, 0, 0),           // 0: Black
            (134, 18, 192),      // 1: Lila/Violett
            (0, 101, 43),        // 2: Dunkelgrün
            (48, 48, 255),       // 3: Blau
            (165, 95, 0),        // 4: Braun
            (172, 172, 172),     // 5: Hellgrau
            (0, 226, 0),         // 6: Hellgrün (war: 34, 34, 255 Medium Blue)
            (0, 255, 146),       // 7: Cyan
            (224, 0, 39),        // 8: Rot
            (223, 17, 212),      // 9: Magenta
            (81, 81, 81),        // 10: Dunkelgrau
            (78, 158, 255),      // 11: Hellblau
            (255, 39, 0),        // 12: Orange
            (255, 150, 153),     // 13: Rosa
            (255, 253, 0),       // 14: Gelb
            (255, 255, 255)      // 15: White
        ]
           
           for y in 0..<height {
               let base = (y & 0x07) << 10
               let row = (y >> 3) & 0x07
               let block = (y >> 6) & 0x03
               let offset = base | (row << 7) | (block * 40)
               
               guard offset + 40 <= 8192 else { continue }
               
               var bits: [UInt8] = []
               for xByte in 0..<40 {
                   let mainByte = mainData[offset + xByte]
                   let auxByte = auxData[offset + xByte]
                   
                   for bitPos in 0..<7 {
                       bits.append((mainByte >> bitPos) & 0x1)
                   }
                   for bitPos in 0..<7 {
                       bits.append((auxByte >> bitPos) & 0x1)
                   }
               }
               
               var pixelX = 0
               var bitIndex = 0
               
               while bitIndex + 3 < bits.count && pixelX < width {
                   let bit0 = bits[bitIndex]
                   let bit1 = bits[bitIndex + 1]
                   let bit2 = bits[bitIndex + 2]
                   let bit3 = bits[bitIndex + 3]
                   
                   let colorIndex = Int(bit0 | (bit1 << 1) | (bit2 << 2) | (bit3 << 3))
                   let color = dhgrPalette[colorIndex]
                   
                   for _ in 0..<4 {
                       let bufferIdx = (y * width + pixelX) * 4
                       if bufferIdx + 3 < rgbaBuffer.count && pixelX < width {
                           rgbaBuffer[bufferIdx] = color.r
                           rgbaBuffer[bufferIdx + 1] = color.g
                           rgbaBuffer[bufferIdx + 2] = color.b
                           rgbaBuffer[bufferIdx + 3] = 255
                       }
                       pixelX += 1
                   }
                   
                   bitIndex += 4
               }
           }
        // Neu Originalbild erzeugen
            guard let fullImage = createCGImage(from: rgbaBuffer, width: width, height: height) else {
                return nil
            }

        // 🔥 NEU: auf halbe Breite skalieren
            return scaleCGImage(fullImage, to: CGSize(width: 280, height: 192))
        
        //Originalfunktion zur Augabe
        //   return createCGImage(from: rgbaBuffer, width: width, height: height)
       }
    
    // --- HGR Decoder (280x192, 8KB) - FINAL COLOR POLARITY REVERSAL ---
    static func decodeHGR(data: Data) -> CGImage? {
        let width = 280
        let height = 192
        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)
        
        // Apple II HGR Farben (Standard Palette)
        // 0:Schwarz, 1:Weiß (Kein Artefakt), 2:Grün, 3:Violett, 4:Orange, 5:Blau
        let hgrColors: [(r: UInt8, g: UInt8, b: UInt8)] = [
            (0, 0, 0),       // 0: Schwarz
            (255, 255, 255), // 1: Weiß
            (32, 192, 32),   // 2: Grün (etwas dunkler für Retro-Look)
            (160, 32, 240),  // 3: Violett
            (255, 100, 0),   // 4: Orange
            (60, 60, 255)    // 5: Blau (Mittelblau)
        ]
        
        guard data.count >= 8192 else { return nil }

        for y in 0..<height {
            // --- 1. KORREKTE ADRESSBERECHNUNG ---
            let i = y % 8           // Innerhalb des 8er Blocks (Bit 0-2)
            let j = (y / 8) % 8     // Welcher 8er Block (Bit 3-5)
            let k = y / 64          // Welches Drittel (Bit 6-7)
            
            // Die "Magie": i springt riesig (1024), j springt klein (128)
            let fileOffset = (i * 1024) + (j * 128) + (k * 40)
            
            guard fileOffset + 40 <= data.count else { continue }
            
            // Zeile lesen
            for xByte in 0..<40 {
                let currentByte = data[fileOffset + xByte]
                
                // Für das Artefakt-Handling brauchen wir das nächste Byte (für Bit 6 -> Bit 0 Übergang)
                let nextByte: UInt8 = (xByte + 1 < 40) ? data[fileOffset + xByte + 1] : 0
                
                let highBit = (currentByte >> 7) & 0x1 // Palette Switch (0=Violett/Grün, 1=Blau/Orange)
                
                for bitIndex in 0..<7 {
                    let pixelIndex = (xByte * 7) + bitIndex
                    let bufferIdx = (y * width + pixelIndex) * 4
                    
                    // --- 2. BIT EXTRAKTION ---
                    // Apple II stellt Bit 0 links dar -> Bit 6 rechts.
                    let bitA = (currentByte >> bitIndex) & 0x1
                    
                    // Nachbar-Bit (für Farbe)
                    let bitB: UInt8
                    if bitIndex == 6 {
                        bitB = (nextByte >> 0) & 0x1
                    } else {
                        bitB = (currentByte >> (bitIndex + 1)) & 0x1
                    }
                    
                    // --- 3. FARBESTIMMUNG ---
                    var colorIndex = 0
                    
                    if bitA == 0 && bitB == 0 {
                        colorIndex = 0 // Schwarz
                    } else if bitA == 1 && bitB == 1 {
                        colorIndex = 1 // Weiß
                    } else {
                        // Artefakt-Farbe (Bit-Wechsel)
                        let isEvenColumn = (pixelIndex % 2) == 0
                        
                        if highBit == 1 { // Palette "High" (Blau/Orange)
                            if isEvenColumn {
                                colorIndex = (bitA == 1) ? 5 : 4 // Blau : Orange
                            } else {
                                colorIndex = (bitA == 1) ? 4 : 5 // Orange : Blau
                            }
                        } else { // Palette "Low" (Violett/Grün) -> Standard für Text/Boot
                            if isEvenColumn {
                                colorIndex = (bitA == 1) ? 3 : 2 // Violett : Grün
                            } else {
                                colorIndex = (bitA == 1) ? 2 : 3 // Grün : Violett
                            }
                        }
                    }
                    
                    let c = hgrColors[colorIndex]
                    rgbaBuffer[bufferIdx] = c.r
                    rgbaBuffer[bufferIdx + 1] = c.g
                    rgbaBuffer[bufferIdx + 2] = c.b
                    rgbaBuffer[bufferIdx + 3] = 255
                }
            }
        }
        
        return createCGImage(from: rgbaBuffer, width: width, height: height)
    }
    
    // --- SHR Decoder (Unchanged) ---
    static func decodeSHR(data: Data, is3200Color: Bool) -> CGImage? {
        let width = 320
        let height = 200
        var rgbaBuffer = [UInt8](repeating: 255, count: width * height * 4)
        
        let pixelDataStart = 0
        let scbOffset = 32000
        let standardPaletteOffset = 32256
        let brooksPaletteOffset = 32000
        
        if !is3200Color {
            var palettes = [[(r: UInt8, g: UInt8, b: UInt8)]]()
            for i in 0..<16 {
                let pOffset = standardPaletteOffset + (i * 32)
                palettes.append(readPalette(from: data, offset: pOffset, reverseOrder: false))
            }
            
            for y in 0..<height {
                let scb = data[scbOffset + y]
                let paletteIndex = Int(scb & 0x0F)
                let currentPalette = palettes[paletteIndex]
                renderLine(y: y, data: data, pixelStart: pixelDataStart, palette: currentPalette, to: &rgbaBuffer, width: width)
            }
            
        } else {
            for y in 0..<height {
                let pOffset = brooksPaletteOffset + (y * 32)
                let currentPalette = readPalette(from: data, offset: pOffset, reverseOrder: true)
                renderLine(y: y, data: data, pixelStart: pixelDataStart, palette: currentPalette, to: &rgbaBuffer, width: width)
            }
        }
        
        return createCGImage(from: rgbaBuffer, width: width, height: height)
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

        // Kein Interpolieren = scharfe Pixel!
        ctx.interpolationQuality = .none

        ctx.draw(image, in: CGRect(origin: .zero, size: newSize))
        return ctx.makeImage()
    }
    // --- Decoder Helpers (Unchanged) ---
    
    static func readPalette(from data: Data, offset: Int, reverseOrder: Bool) -> [(r: UInt8, g: UInt8, b: UInt8)] {
        var colors = [(r: UInt8, g: UInt8, b: UInt8)](repeating: (0,0,0), count: 16)
        
        for i in 0..<16 {
            let colorIdx = reverseOrder ? (15 - i) : i
            let byte1 = data[offset + (i * 2)]
            let byte2 = data[offset + (i * 2) + 1]
            
            let red4   = (byte2 & 0x0F)
            let green4 = (byte1 & 0xF0) >> 4
            let blue4  = (byte1 & 0x0F)
            
            let r = red4 * 17
            let g = green4 * 17
            let b = blue4 * 17
            
            colors[colorIdx] = (r, g, b)
        }
        return colors
    }
    
    static func renderLine(y: Int, data: Data, pixelStart: Int, palette: [(r: UInt8, g: UInt8, b: UInt8)], to buffer: inout [UInt8], width: Int) {
        let bytesPerLine = 160
        let lineStart = pixelStart + (y * bytesPerLine)
        
        for xByte in 0..<bytesPerLine {
            let byte = data[lineStart + xByte]
            
            let idx1 = (byte & 0xF0) >> 4
            let idx2 = (byte & 0x0F)
            
            let c1 = palette[Int(idx1)]
            let bufferIdx1 = (y * width + (xByte * 2)) * 4
            buffer[bufferIdx1]     = c1.r
            buffer[bufferIdx1 + 1] = c1.g
            buffer[bufferIdx1 + 2] = c1.b
            buffer[bufferIdx1 + 3] = 255
            
            let c2 = palette[Int(idx2)]
            let bufferIdx2 = (y * width + (xByte * 2) + 1) * 4
            buffer[bufferIdx2]     = c2.r
            buffer[bufferIdx2 + 1] = c2.g
            buffer[bufferIdx2 + 2] = c2.b
            buffer[bufferIdx2 + 3] = 255
        }
    }
    
    static func createCGImage(from buffer: [UInt8], width: Int, height: Int) -> CGImage? {
        let bytesPerPixel = 4
        let bitsPerComponent = 8
        let bytesPerRow = width * bytesPerPixel
        let expectedSize = bytesPerRow * height
        
        guard buffer.count == expectedSize else {
            return nil
        }

        let colorSpace = CGColorSpaceCreateDeviceRGB()
        
        let bitmapInfo = CGBitmapInfo(rawValue:
            CGImageAlphaInfo.premultipliedLast.rawValue |
            CGBitmapInfo.byteOrder32Big.rawValue)
        
        guard let provider = CGDataProvider(data: Data(buffer) as CFData) else { return nil }
        
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bitsPerPixel: bytesPerPixel * bitsPerComponent, // 32
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: bitmapInfo,
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )
    }
}
