import SwiftUI
import UniformTypeIdentifiers
import CoreGraphics
import ImageIO
import AppKit

// MARK: - New Types and Enums

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
    
    var displayName: String {
        switch self {
        case .SHR(let mode): return "SHR (\(mode))"
        case .DHGR: return "DHGR"
        case .HGR: return "HGR"
        case .Unknown: return "Unknown"
        }
    }
}

// MARK: - Image Item Model

struct ImageItem: Identifiable {
    let id = UUID()
    let url: URL
    let image: NSImage
    let type: AppleIIImageType
    
    var filename: String {
        url.lastPathComponent
    }
}

// MARK: - Main App Entry Point

@main
struct SHRConverterApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .frame(minWidth: 900, minHeight: 600)
        }
    }
}

// MARK: - UI View with Image Browser

struct ContentView: View {
    @State private var filesToConvert: [URL] = []
    @State private var imageItems: [ImageItem] = []
    @State private var selectedImage: ImageItem?
    @State private var selectedExportFormat: ExportFormat = .png
    @State private var statusMessage: String = "Drag files/folders or open files to start."
    @State private var isProcessing = false
    @State private var progressString = ""
    @State private var showBrowser = false
    
    var body: some View {
        HSplitView {
            // Left Panel: Browser
            if showBrowser && !imageItems.isEmpty {
                browserPanel
                    .frame(minWidth: 250, idealWidth: 300)
            }
            
            // Right Panel: Main View
            mainPanel
                .frame(minWidth: 500)
        }
        .padding()
    }
    
    // MARK: - Browser Panel
    
    var browserPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Image Browser")
                    .font(.headline)
                Spacer()
                Button(action: { clearAllImages() }) {
                    Image(systemName: "trash")
                }
                .help("Clear all images")
            }
            
            Divider()
            
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 10)], spacing: 10) {
                    ForEach(imageItems) { item in
                        ImageThumbnailView(item: item, isSelected: selectedImage?.id == item.id)
                            .onTapGesture {
                                selectedImage = item
                            }
                    }
                }
                .padding(.horizontal, 5)
            }
            
            Divider()
            
            Text("\(imageItems.count) image(s) loaded")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    // MARK: - Main Panel
    
    var mainPanel: some View {
        VStack(spacing: 20) {
            // Image Display Area
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [10]))
                    .foregroundColor(isProcessing ? .blue : (!imageItems.isEmpty ? .green : .secondary))
                    .background(Color(NSColor.controlBackgroundColor))
                
                if let selectedImg = selectedImage {
                    VStack(spacing: 10) {
                        Image(nsImage: selectedImg.image)
                            .resizable()
                            .interpolation(.none)
                            .aspectRatio(contentMode: .fit)
                            .frame(maxHeight: 400)
                        
                        HStack {
                            Text(selectedImg.filename)
                                .font(.headline)
                            Spacer()
                            Text(selectedImg.type.displayName)
                                .font(.caption)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.blue.opacity(0.2))
                                .cornerRadius(4)
                        }
                        .padding(.horizontal)
                    }
                    .padding()
                } else if imageItems.isEmpty {
                    VStack(spacing: 15) {
                        Image(systemName: "photo.stack")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("Apple II Graphics Converter")
                            .font(.headline)
                        Text("Supports SHR, HGR, and DHGR formats.")
                            .multilineTextAlignment(.center)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Drag & drop files/folders or click 'Open Files...'")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    VStack(spacing: 15) {
                        Image(systemName: "hand.tap")
                            .font(.system(size: 50))
                            .foregroundColor(.secondary)
                        Text("Select an image from the browser")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                }
                
                if isProcessing {
                    VStack(spacing: 10) {
                        ProgressView()
                            .scaleEffect(1.5)
                        Text(progressString)
                            .font(.caption)
                            .padding(.top, 10)
                    }
                    .padding()
                    .background(Color(NSColor.windowBackgroundColor).opacity(0.9))
                    .cornerRadius(10)
                }
            }
            .frame(height: 450)
            .onDrop(of: [.fileURL], isTargeted: nil) { providers in
                loadDroppedFiles(providers)
                return true
            }
            
            // Controls Bar
            VStack(spacing: 10) {
                HStack {
                    Button("Open Files...") {
                        openFiles()
                    }
                    
                    Button(showBrowser ? "Hide Browser" : "Show Browser") {
                        withAnimation {
                            showBrowser.toggle()
                        }
                    }
                    .disabled(imageItems.isEmpty)
                    
                    Spacer()
                    
                    Picker("Export As:", selection: $selectedExportFormat) {
                        ForEach(ExportFormat.allCases, id: \.self) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .frame(width: 180)
                    
                    Button("Export All to \(selectedExportFormat.rawValue)...") {
                        exportAllImages()
                    }
                    .disabled(imageItems.isEmpty || isProcessing)
                }
                
                if let selected = selectedImage {
                    HStack {
                        Spacer()
                        Button("Export Selected Image...") {
                            exportSingleImage(selected)
                        }
                        .disabled(isProcessing)
                    }
                }
            }
            
            // Status Bar
            VStack(alignment: .leading, spacing: 5) {
                Text(statusMessage)
                    .font(.headline)
                if !progressString.isEmpty && !isProcessing {
                    Text(progressString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding()
    }
    
    // MARK: - File Handling
    
    func clearAllImages() {
        imageItems = []
        selectedImage = nil
        filesToConvert = []
        statusMessage = "All images cleared."
        progressString = ""
        showBrowser = false
    }
    
    func openFiles() {
        let openPanel = NSOpenPanel()
        openPanel.allowedContentTypes = [.data]
        openPanel.allowsMultipleSelection = true
        openPanel.canChooseDirectories = true
        openPanel.canChooseFiles = true
        openPanel.prompt = "Open Apple II/IIGS Graphics Files or Folders"

        if openPanel.runModal() == .OK {
            processFilesAndFolders(urls: openPanel.urls)
        }
    }
    
    func loadDroppedFiles(_ providers: [NSItemProvider]) {
        self.isProcessing = true
        self.statusMessage = "Loading dropped files..."
        
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
            self.processFilesAndFolders(urls: collectedURLs)
        }
    }
    
    func processFilesAndFolders(urls: [URL]) {
        guard !urls.isEmpty else {
            isProcessing = false
            return
        }
        
        isProcessing = true
        statusMessage = "Scanning files and folders..."
        
        DispatchQueue.global(qos: .userInitiated).async {
            var allFileURLs: [URL] = []
            
            // Recursively collect all files from folders
            for url in urls {
                var isDirectory: ObjCBool = false
                if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
                    if isDirectory.boolValue {
                        // It's a folder - scan it
                        if let files = self.scanFolder(url: url) {
                            allFileURLs.append(contentsOf: files)
                        }
                    } else {
                        // It's a file - add directly
                        allFileURLs.append(url)
                    }
                }
            }
            
            DispatchQueue.main.async {
                if allFileURLs.isEmpty {
                    self.isProcessing = false
                    self.statusMessage = "No files found"
                    self.progressString = ""
                } else {
                    self.processFiles(urls: allFileURLs)
                }
            }
        }
    }
    
    func scanFolder(url: URL) -> [URL]? {
        let fileManager = FileManager.default
        var fileURLs: [URL] = []
        
        guard let enumerator = fileManager.enumerator(at: url,
                                                       includingPropertiesForKeys: [.isRegularFileKey],
                                                       options: [.skipsHiddenFiles]) else {
            return nil
        }
        
        for case let fileURL as URL in enumerator {
            do {
                let fileAttributes = try fileURL.resourceValues(forKeys: [.isRegularFileKey])
                if fileAttributes.isRegularFile == true {
                    // Optional: Filter by file size (Apple II images are typically 8KB, 16KB, or 32KB+)
                    let fileSize = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int) ?? 0
                    if fileSize > 0 {
                        fileURLs.append(fileURL)
                    }
                }
            } catch {
                continue
            }
        }
        
        return fileURLs
    }
    
    func processFiles(urls: [URL]) {
        guard !urls.isEmpty else {
            isProcessing = false
            return
        }
        
        isProcessing = true
        statusMessage = "Processing \(urls.count) file(s)..."
        
        DispatchQueue.global(qos: .userInitiated).async {
            var newItems: [ImageItem] = []
            var successCount = 0
            
            for (index, url) in urls.enumerated() {
                DispatchQueue.main.async {
                    self.progressString = "Processing \(index + 1) of \(urls.count): \(url.lastPathComponent)"
                }
                
                guard let data = try? Data(contentsOf: url) else { continue }
                let result = SHRDecoder.decode(data: data)
                
                if let cgImage = result.image, result.type != .Unknown {
                    let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: result.type.resolution.width, height: result.type.resolution.height))
                    let item = ImageItem(url: url, image: nsImage, type: result.type)
                    newItems.append(item)
                    successCount += 1
                }
            }
            
            DispatchQueue.main.async {
                self.imageItems.append(contentsOf: newItems)
                self.isProcessing = false
                self.statusMessage = "Loaded \(successCount) of \(urls.count) file(s)"
                self.progressString = ""
                
                if !newItems.isEmpty {
                    self.showBrowser = true
                    if self.selectedImage == nil {
                        self.selectedImage = newItems.first
                    }
                }
            }
        }
    }
    
    // MARK: - Export Functions
    
    func exportSingleImage(_ item: ImageItem) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [UTType(filenameExtension: selectedExportFormat.fileExtension)!]
        savePanel.nameFieldStringValue = "\(item.url.deletingPathExtension().lastPathComponent).\(selectedExportFormat.fileExtension)"
        savePanel.prompt = "Export"
        savePanel.canCreateDirectories = true
        savePanel.showsHiddenFiles = false
        
        if savePanel.runModal() == .OK, let outputURL = savePanel.url {
            isProcessing = true
            DispatchQueue.global(qos: .userInitiated).async {
                let success = self.saveImage(image: item.image, to: outputURL, format: self.selectedExportFormat)
                
                DispatchQueue.main.async {
                    self.isProcessing = false
                    if success {
                        self.statusMessage = "Exported: \(outputURL.lastPathComponent)"
                        self.progressString = ""
                    } else {
                        self.statusMessage = "Export failed!"
                    }
                }
            }
        }
    }
    
    func exportAllImages() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.canCreateDirectories = true
        openPanel.showsHiddenFiles = false
        openPanel.prompt = "Select Export Folder"

        if openPanel.runModal() == .OK, let outputFolderURL = openPanel.url {
            isProcessing = true
            
            DispatchQueue.global(qos: .userInitiated).async {
                var successCount = 0
                
                for (index, item) in self.imageItems.enumerated() {
                    DispatchQueue.main.async {
                        self.progressString = "Exporting \(index + 1) of \(self.imageItems.count)"
                    }
                    
                    let filename = "\(item.url.deletingPathExtension().lastPathComponent).\(self.selectedExportFormat.fileExtension)"
                    let outputURL = outputFolderURL.appendingPathComponent(filename)
                    
                    if self.saveImage(image: item.image, to: outputURL, format: self.selectedExportFormat) {
                        successCount += 1
                    }
                }
                
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.statusMessage = "Exported \(successCount) of \(self.imageItems.count) image(s)"
                    self.progressString = ""
                }
            }
        }
    }
    
    func saveImage(image: NSImage, to outputURL: URL, format: ExportFormat) -> Bool {
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

// MARK: - Thumbnail View

struct ImageThumbnailView: View {
    let item: ImageItem
    let isSelected: Bool
    
    var body: some View {
        VStack(spacing: 4) {
            Image(nsImage: item.image)
                .resizable()
                .interpolation(.none)
                .aspectRatio(contentMode: .fit)
                .frame(width: 120, height: 90)
                .background(Color.black.opacity(0.1))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(isSelected ? Color.blue : Color.clear, lineWidth: 3)
                )
            
            Text(item.filename)
                .font(.caption2)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .frame(width: 120)
            
            Text(item.type.displayName)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
        .padding(4)
        .background(isSelected ? Color.blue.opacity(0.1) : Color.clear)
        .cornerRadius(8)
    }
}

// MARK: - HEIC Helper

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

// MARK: - SHRDecoder

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
    
    // --- DHGR Decoder (560x192, 16KB) ---
    static func decodeDHGR(data: Data) -> CGImage? {
        let width = 560
        let height = 192
        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)
        
        guard data.count >= 16384 else { return nil }
        
        let mainData = data.subdata(in: 0..<8192)
        let auxData = data.subdata(in: 8192..<16384)
        
        let dhgrPalette: [(r: UInt8, g: UInt8, b: UInt8)] = [
            (0, 0, 0),           // 0: Black
            (134, 18, 192),      // 1: Lila/Violett
            (0, 101, 43),        // 2: Dunkelgrün
            (48, 48, 255),       // 3: Blau
            (165, 95, 0),        // 4: Braun
            (172, 172, 172),     // 5: Hellgrau
            (0, 226, 0),         // 6: Hellgrün
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
        
        guard let fullImage = createCGImage(from: rgbaBuffer, width: width, height: height) else {
            return nil
        }
        
        return scaleCGImage(fullImage, to: CGSize(width: 280, height: 192))
    }
    
    // --- HGR Decoder (280x192, 8KB) ---
    static func decodeHGR(data: Data) -> CGImage? {
        let width = 280
        let height = 192
        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)
        
        let hgrColors: [(r: UInt8, g: UInt8, b: UInt8)] = [
            (0, 0, 0),       // 0: Schwarz
            (255, 255, 255), // 1: Weiß
            (32, 192, 32),   // 2: Grün
            (160, 32, 240),  // 3: Violett
            (255, 100, 0),   // 4: Orange
            (60, 60, 255)    // 5: Blau
        ]
        
        guard data.count >= 8192 else { return nil }

        for y in 0..<height {
            let i = y % 8
            let j = (y / 8) % 8
            let k = y / 64
            
            let fileOffset = (i * 1024) + (j * 128) + (k * 40)
            
            guard fileOffset + 40 <= data.count else { continue }
            
            for xByte in 0..<40 {
                let currentByte = data[fileOffset + xByte]
                let nextByte: UInt8 = (xByte + 1 < 40) ? data[fileOffset + xByte + 1] : 0
                
                let highBit = (currentByte >> 7) & 0x1
                
                for bitIndex in 0..<7 {
                    let pixelIndex = (xByte * 7) + bitIndex
                    let bufferIdx = (y * width + pixelIndex) * 4
                    
                    let bitA = (currentByte >> bitIndex) & 0x1
                    
                    let bitB: UInt8
                    if bitIndex == 6 {
                        bitB = (nextByte >> 0) & 0x1
                    } else {
                        bitB = (currentByte >> (bitIndex + 1)) & 0x1
                    }
                    
                    var colorIndex = 0
                    
                    if bitA == 0 && bitB == 0 {
                        colorIndex = 0
                    } else if bitA == 1 && bitB == 1 {
                        colorIndex = 1
                    } else {
                        let isEvenColumn = (pixelIndex % 2) == 0
                        
                        if highBit == 1 {
                            if isEvenColumn {
                                colorIndex = (bitA == 1) ? 5 : 4
                            } else {
                                colorIndex = (bitA == 1) ? 4 : 5
                            }
                        } else {
                            if isEvenColumn {
                                colorIndex = (bitA == 1) ? 3 : 2
                            } else {
                                colorIndex = (bitA == 1) ? 2 : 3
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
    
    // --- SHR Decoder ---
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

        ctx.interpolationQuality = .none

        ctx.draw(image, in: CGRect(origin: .zero, size: newSize))
        return ctx.makeImage()
    }
    
    // --- Decoder Helpers ---
    
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
        
        // Use .noneSkipLast to ignore the alpha channel for opaque images
        let bitmapInfo = CGBitmapInfo(rawValue:
            CGImageAlphaInfo.noneSkipLast.rawValue |
            CGBitmapInfo.byteOrder32Big.rawValue)
        
        guard let provider = CGDataProvider(data: Data(buffer) as CFData) else { return nil }
        
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: bitsPerComponent,
            bitsPerPixel: bytesPerPixel * bitsPerComponent,
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
