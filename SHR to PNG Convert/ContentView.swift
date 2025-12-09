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
    case IFF(width: Int, height: Int, colors: String)
    case DEGAS(resolution: String, colors: Int)
    case C64(format: String)
    case ZXSpectrum
    case AmstradCPC(mode: Int, colors: Int)
    case PCX(width: Int, height: Int, bitsPerPixel: Int)
    case Unknown
    
    var resolution: (width: Int, height: Int) {
        switch self {
        case .SHR: return (320, 200)
        case .DHGR: return (560, 192)
        case .HGR: return (280, 192)
        case .IFF(let width, let height, _): return (width, height)
        case .DEGAS(let res, _):
            switch res {
            case "Low": return (320, 200)
            case "Medium": return (640, 200)
            case "High": return (640, 400)
            default: return (0, 0)
            }
        case .C64: return (320, 200)
        case .ZXSpectrum: return (256, 192)
        case .AmstradCPC(let mode, _):
            switch mode {
            case 0: return (160, 200)  // Mode 0: 160x200, 16 colors
            case 1: return (320, 200)  // Mode 1: 320x200, 4 colors
            case 2: return (640, 200)  // Mode 2: 640x200, 2 colors
            default: return (0, 0)
            }
        case .PCX(let width, let height, _): return (width, height)
        case .Unknown: return (0, 0)
        }
    }
    
    var displayName: String {
        switch self {
        case .SHR(let mode): return "SHR (\(mode))"
        case .DHGR: return "DHGR"
        case .HGR: return "HGR"
        case .IFF(_, _, let colors): return "IFF (\(colors))"
        case .DEGAS(let res, let colors): return "Degas (\(res), \(colors) colors)"
        case .C64(let format): return "C64 (\(format))"
        case .ZXSpectrum: return "ZX Spectrum"
        case .AmstradCPC(let mode, let colors): return "Amstrad CPC (Mode \(mode), \(colors) colors)"
        case .PCX(let width, let height, let bpp): return "PCX (\(width)x\(height), \(bpp)-bit)"
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
                        Text("Retro Graphics Converter")
                            .font(.headline)
                        Text("Supports Apple II, Amiga IFF, Atari ST, C64, ZX Spectrum, Amstrad CPC, and PCX.")
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
        
        // Check for PCX format first (has magic byte 0x0A)
        if size >= 128 && data[0] == 0x0A {
            return decodePCX(data: data)
        }
        
        // Check for IFF format (has FORM header)
        if size >= 12 {
            let header = data.subdata(in: 0..<4)
            if let headerString = String(data: header, encoding: .ascii), headerString == "FORM" {
                return decodeIFF(data: data)
            }
        }
        
        // Check for C64 formats (by exact file size)
        switch size {
        case 10003: // Koala Painter
            return decodeC64Koala(data: data)
        case 10018: // Art Studio variant
            return decodeC64ArtStudio(data: data)
        case 9009: // Art Studio HIRES or similar
            return decodeC64Hires(data: data)
        case 6912: // ZX Spectrum SCR
            return decodeZXSpectrum(data: data)
        case 16384: // Could be Amstrad CPC or Apple II DHGR
            // Try to detect which format by checking for CPC screen mode byte
            // CPC files often have a mode indicator or specific patterns
            return decodeAmstradCPC(data: data)
        default:
            break
        }
        
        // Check for Degas format (.PI1, .PI2, .PI3)
        if size >= 34 {
            let resolutionWord = readBigEndianUInt16(data: data, offset: 0)
            
            let isDegas = (resolutionWord <= 2) && (
                size == 32034 ||  // PI1: Low res
                size == 32066     // PI2/PI3: Medium/High res
            )
            
            if isDegas {
                return decodeDegas(data: data)
            }
        }
        
        // Then check Apple II formats by size
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
            // If we reach here, it wasn't CPC, try DHGR
            type = .DHGR
            image = decodeDHGR(data: data)
        default:
            type = .Unknown
            image = nil
        }
        
        return (image, type)
    }
    
    // --- Risk EGA Format Decoder (32KB, 320x200, chunky 4-bit) ---
    
    // --- PCX Decoder (ZSoft PC Paintbrush format) ---
    
    static func decodePCX(data: Data) -> (image: CGImage?, type: AppleIIImageType) {
        guard data.count >= 128 else {
            return (nil, .Unknown)
        }
        
        // PCX Header (128 bytes)
        let manufacturer = data[0]  // Should be 0x0A
        let version = data[1]       // 0=v2.5, 2=v2.8 with palette, 3=v2.8 w/o palette, 5=v3.0
        let encoding = data[2]      // 1 = RLE encoding
        let bitsPerPixel = data[3]
        
        guard manufacturer == 0x0A else {
            return (nil, .Unknown)
        }
        
        // Read image dimensions (little-endian)
        let xMin = Int(data[4]) | (Int(data[5]) << 8)
        let yMin = Int(data[6]) | (Int(data[7]) << 8)
        let xMax = Int(data[8]) | (Int(data[9]) << 8)
        let yMax = Int(data[10]) | (Int(data[11]) << 8)
        
        let width = xMax - xMin + 1
        let height = yMax - yMin + 1
        
        let numPlanes = data[65]
        let bytesPerLine = Int(data[66]) | (Int(data[67]) << 8)
        
        guard width > 0 && height > 0 && width < 10000 && height < 10000 else {
            return (nil, .Unknown)
        }
        
        // Calculate total bits per pixel
        // Note: Some old PCX files have numPlanes=0, so we handle that specially
        var totalBitsPerPixel = Int(bitsPerPixel) * Int(numPlanes)
        if totalBitsPerPixel == 0 && bitsPerPixel > 0 {
            // Handle the case where numPlanes is 0 (old format)
            totalBitsPerPixel = Int(bitsPerPixel)
        }
        
        // Decompress image data (starts at byte 128)
        var decompressedData: [UInt8] = []
        var offset = 128
        
        // Calculate expected decompressed size
        // For numPlanes=0 (old format), use bytesPerLine * height
        let expectedSize: Int
        if numPlanes == 0 {
            expectedSize = bytesPerLine * height
        } else {
            expectedSize = bytesPerLine * Int(numPlanes) * height
        }
        
        // RLE decompression
        while offset < data.count && decompressedData.count < expectedSize {
            let byte = data[offset]
            offset += 1
            
            if (byte & 0xC0) == 0xC0 {
                // RLE run
                let count = Int(byte & 0x3F)
                if offset < data.count {
                    let value = data[offset]
                    offset += 1
                    for _ in 0..<count {
                        decompressedData.append(value)
                    }
                }
            } else {
                // Literal byte
                decompressedData.append(byte)
            }
        }
        
        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)
        
        // Check if there's a 256-color palette at the end
        var palette: [(r: UInt8, g: UInt8, b: UInt8)] = []
        if totalBitsPerPixel == 8 && data.count >= 769 {
            // Check for palette marker (0x0C) 769 bytes from end
            let paletteMarkerOffset = data.count - 769
            if paletteMarkerOffset >= 0 && data[paletteMarkerOffset] == 0x0C {
                // Read 256-color palette (768 bytes: 256 * 3)
                for i in 0..<256 {
                    let r = data[paletteMarkerOffset + 1 + (i * 3)]
                    let g = data[paletteMarkerOffset + 1 + (i * 3) + 1]
                    let b = data[paletteMarkerOffset + 1 + (i * 3) + 2]
                    palette.append((r, g, b))
                }
            }
        }
        
        // If no palette found, use grayscale or header palette
        if palette.isEmpty {
            if totalBitsPerPixel <= 4 {
                // Use 16-color palette from header (bytes 16-63)
                for i in 0..<16 {
                    let offset = 16 + (i * 3)
                    let r = data[offset]
                    let g = data[offset + 1]
                    let b = data[offset + 2]
                    palette.append((r, g, b))
                }
            } else {
                // Generate grayscale palette
                for i in 0..<256 {
                    let gray = UInt8(i)
                    palette.append((gray, gray, gray))
                }
            }
        }
        
        // Decode image based on bit depth
        if totalBitsPerPixel == 8 && numPlanes == 1 {
            // 8-bit indexed color
            for y in 0..<height {
                let lineOffset = y * bytesPerLine
                for x in 0..<width {
                    if lineOffset + x < decompressedData.count {
                        let paletteIndex = Int(decompressedData[lineOffset + x])
                        let color = palette[min(paletteIndex, palette.count - 1)]
                        
                        let bufferIdx = (y * width + x) * 4
                        rgbaBuffer[bufferIdx] = color.r
                        rgbaBuffer[bufferIdx + 1] = color.g
                        rgbaBuffer[bufferIdx + 2] = color.b
                        rgbaBuffer[bufferIdx + 3] = 255
                    }
                }
            }
        } else if totalBitsPerPixel == 24 && numPlanes == 3 {
            // 24-bit RGB (3 planes)
            for y in 0..<height {
                for x in 0..<width {
                    let rOffset = (y * bytesPerLine * 3) + x
                    let gOffset = (y * bytesPerLine * 3) + bytesPerLine + x
                    let bOffset = (y * bytesPerLine * 3) + (bytesPerLine * 2) + x
                    
                    var r: UInt8 = 0, g: UInt8 = 0, b: UInt8 = 0
                    if rOffset < decompressedData.count { r = decompressedData[rOffset] }
                    if gOffset < decompressedData.count { g = decompressedData[gOffset] }
                    if bOffset < decompressedData.count { b = decompressedData[bOffset] }
                    
                    let bufferIdx = (y * width + x) * 4
                    rgbaBuffer[bufferIdx] = r
                    rgbaBuffer[bufferIdx + 1] = g
                    rgbaBuffer[bufferIdx + 2] = b
                    rgbaBuffer[bufferIdx + 3] = 255
                }
            }
        } else if totalBitsPerPixel == 2 || (Int(bitsPerPixel) == 2 && Int(numPlanes) <= 1) {
            // 2-bit (4 colors) - CGA mode
            // Use default CGA palette if header palette is invalid (all same color)
            var cgaPalette: [(r: UInt8, g: UInt8, b: UInt8)] = []
            
            // Check if we need default CGA palette
            if palette.count >= 4 {
                let firstFour = Array(palette.prefix(4))
                
                // Check if all colors are the same (invalid palette)
                let allSame = firstFour.dropFirst().allSatisfy {
                    $0.r == firstFour[0].r &&
                    $0.g == firstFour[0].g &&
                    $0.b == firstFour[0].b
                }
                
                if allSame {
                    // Invalid palette - use default CGA
                    cgaPalette = [
                        (0, 0, 0),       // Black
                        (0, 255, 255),   // Cyan
                        (255, 0, 255),   // Magenta
                        (255, 255, 255)  // White
                    ]
                } else {
                    cgaPalette = firstFour
                }
            } else {
                // Default CGA palette
                cgaPalette = [
                    (0, 0, 0),       // Black
                    (0, 255, 255),   // Cyan
                    (255, 0, 255),   // Magenta
                    (255, 255, 255)  // White
                ]
            }
            
            for y in 0..<height {
                let lineOffset = y * bytesPerLine
                for x in 0..<width {
                    let byteIndex = lineOffset + (x / 4)
                    let pixelInByte = 3 - (x % 4)  // High bits first
                    
                    if byteIndex < decompressedData.count {
                        let byteVal = decompressedData[byteIndex]
                        let colorIndex = Int((byteVal >> (pixelInByte * 2)) & 0x03)
                        let color = cgaPalette[min(colorIndex, cgaPalette.count - 1)]
                        
                        let bufferIdx = (y * width + x) * 4
                        rgbaBuffer[bufferIdx] = color.r
                        rgbaBuffer[bufferIdx + 1] = color.g
                        rgbaBuffer[bufferIdx + 2] = color.b
                        rgbaBuffer[bufferIdx + 3] = 255
                    }
                }
            }
        } else if totalBitsPerPixel <= 4 {
            // 1-4 bit indexed color
            for y in 0..<height {
                let lineOffset = y * bytesPerLine
                for x in 0..<width {
                    let byteIndex = lineOffset + (x / 8)
                    let bitIndex = 7 - (x % 8)
                    
                    if byteIndex < decompressedData.count {
                        let bit = (decompressedData[byteIndex] >> bitIndex) & 1
                        let color = palette[Int(bit)]
                        
                        let bufferIdx = (y * width + x) * 4
                        rgbaBuffer[bufferIdx] = color.r
                        rgbaBuffer[bufferIdx + 1] = color.g
                        rgbaBuffer[bufferIdx + 2] = color.b
                        rgbaBuffer[bufferIdx + 3] = 255
                    }
                }
            }
        }
        
        guard let cgImage = createCGImage(from: rgbaBuffer, width: width, height: height) else {
            return (nil, .Unknown)
        }
        
        return (cgImage, .PCX(width: width, height: height, bitsPerPixel: totalBitsPerPixel))
    }
    
    // --- Amstrad CPC SCR Decoder (16384 bytes) ---
    
    // Amstrad CPC Hardware Palette (27 colors - the "real" hardware colors)
    static let amstradCPCPalette: [(r: UInt8, g: UInt8, b: UInt8)] = [
        (0x00, 0x00, 0x00),  // 0: Black
        (0x00, 0x00, 0x80),  // 1: Blue
        (0x00, 0x00, 0xFF),  // 2: Bright Blue
        (0x80, 0x00, 0x00),  // 3: Red
        (0x80, 0x00, 0x80),  // 4: Magenta
        (0x80, 0x00, 0xFF),  // 5: Mauve
        (0xFF, 0x00, 0x00),  // 6: Bright Red
        (0xFF, 0x00, 0x80),  // 7: Purple
        (0xFF, 0x00, 0xFF),  // 8: Bright Magenta
        (0x00, 0x80, 0x00),  // 9: Green
        (0x00, 0x80, 0x80),  // 10: Cyan
        (0x00, 0x80, 0xFF),  // 11: Sky Blue
        (0x80, 0x80, 0x00),  // 12: Yellow
        (0x80, 0x80, 0x80),  // 13: White (actually grey)
        (0x80, 0x80, 0xFF),  // 14: Pastel Blue
        (0xFF, 0x80, 0x00),  // 15: Orange
        (0xFF, 0x80, 0x80),  // 16: Pink
        (0xFF, 0x80, 0xFF),  // 17: Pastel Magenta
        (0x00, 0xFF, 0x00),  // 18: Bright Green
        (0x00, 0xFF, 0x80),  // 19: Sea Green
        (0x00, 0xFF, 0xFF),  // 20: Bright Cyan
        (0x80, 0xFF, 0x00),  // 21: Lime
        (0x80, 0xFF, 0x80),  // 22: Pastel Green
        (0x80, 0xFF, 0xFF),  // 23: Pastel Cyan
        (0xFF, 0xFF, 0x00),  // 24: Bright Yellow
        (0xFF, 0xFF, 0x80),  // 25: Pastel Yellow
        (0xFF, 0xFF, 0xFF)   // 26: Bright White
    ]
    
    static func decodeAmstradCPC(data: Data) -> (image: CGImage?, type: AppleIIImageType) {
        guard data.count == 16384 else {
            return (nil, .Unknown)
        }
        
        // Try to detect the mode by analyzing the data
        // Mode 0 typically has more varied data (4 bits per pixel)
        // Mode 1 is most common (2 bits per pixel)
        // For now, we'll try both and see which looks better
        // Or default to Mode 1 as it's most common
        
        // Let's decode both Mode 0 and Mode 1
        // You can add heuristics here to auto-detect, but for now try Mode 1 first
        
        // Try Mode 1 first (most common)
        if let result = decodeAmstradCPCMode1(data: data) {
            return result
        }
        
        // Fallback to Mode 0
        if let result = decodeAmstradCPCMode0(data: data) {
            return result
        }
        
        return (nil, .Unknown)
    }
    
    // Mode 0: 160x200, 16 colors (4 bits per pixel)
    static func decodeAmstradCPCMode0(data: Data) -> (image: CGImage?, type: AppleIIImageType)? {
        let width = 160
        let height = 200
        let colorsPerMode = 16
        
        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)
        
        // Default Mode 0 palette (16 colors)
        let defaultPalette: [Int] = [
            1,  // Blue
            24, // Yellow
            20, // Cyan
            6,  // Red
            0,  // Black
            26, // White
            18, // Green
            8,  // Magenta
            13, // Grey
            25, // Pastel Yellow
            23, // Pastel Cyan
            17, // Pastel Magenta
            22, // Pastel Green
            16, // Pink
            15, // Orange
            14  // Pastel Blue
        ]
        
        for y in 0..<height {
            let block = y / 8
            let lineInBlock = y % 8
            let bytesPerLine = 80  // Same as Mode 1
            let lineOffset = (block * 2048) + (lineInBlock * bytesPerLine)
            
            for xByte in 0..<bytesPerLine {
                let byteOffset = lineOffset + xByte
                if byteOffset >= data.count { continue }
                
                let dataByte = data[byteOffset]
                
                // Mode 0: Each byte contains 2 pixels (4 bits each)
                // Bit order: pixel 0 uses bits 7,5,3,1 and pixel 1 uses bits 6,4,2,0
                
                for pixel in 0..<2 {
                    let x = xByte * 2 + pixel
                    if x >= width { continue }
                    
                    // Extract 4-bit color value with CPC's bit order
                    let nibble: UInt8
                    if pixel == 0 {
                        // Bits 7,5,3,1 (odd bits)
                        nibble = ((dataByte >> 7) & 1) << 3 |
                                 ((dataByte >> 5) & 1) << 2 |
                                 ((dataByte >> 3) & 1) << 1 |
                                 ((dataByte >> 1) & 1)
                    } else {
                        // Bits 6,4,2,0 (even bits)
                        nibble = ((dataByte >> 6) & 1) << 3 |
                                 ((dataByte >> 4) & 1) << 2 |
                                 ((dataByte >> 2) & 1) << 1 |
                                 ((dataByte >> 0) & 1)
                    }
                    
                    let paletteIndex = Int(nibble)
                    let hardwareColor = defaultPalette[paletteIndex]
                    let rgb = amstradCPCPalette[hardwareColor]
                    
                    let bufferIdx = (y * width + x) * 4
                    rgbaBuffer[bufferIdx] = rgb.r
                    rgbaBuffer[bufferIdx + 1] = rgb.g
                    rgbaBuffer[bufferIdx + 2] = rgb.b
                    rgbaBuffer[bufferIdx + 3] = 255
                }
            }
        }
        
        guard let cgImage = createCGImage(from: rgbaBuffer, width: width, height: height) else {
            return nil
        }
        
        return (cgImage, .AmstradCPC(mode: 0, colors: colorsPerMode))
    }
    
    // Mode 1: 320x200, 4 colors (2 bits per pixel)
    static func decodeAmstradCPCMode1(data: Data) -> (image: CGImage?, type: AppleIIImageType)? {
        let width = 320
        let height = 200
        let colorsPerMode = 4
        
        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)
        
        // Default Mode 1 palette
        let defaultPalette: [Int] = [1, 24, 20, 6] // Blue, Yellow, Cyan, Red
        
        for y in 0..<height {
            let block = y / 8
            let lineInBlock = y % 8
            let bytesPerLine = 80
            let lineOffset = (block * 2048) + (lineInBlock * bytesPerLine)
            
            for xByte in 0..<bytesPerLine {
                let byteOffset = lineOffset + xByte
                if byteOffset >= data.count { continue }
                
                let dataByte = data[byteOffset]
                
                // Mode 1: Each byte contains 4 pixels (2 bits each)
                for pixel in 0..<4 {
                    let x = xByte * 4 + pixel
                    if x >= width { continue }
                    
                    let bitPair: UInt8
                    switch pixel {
                    case 0: bitPair = ((dataByte >> 7) & 1) << 1 | ((dataByte >> 3) & 1)
                    case 1: bitPair = ((dataByte >> 6) & 1) << 1 | ((dataByte >> 2) & 1)
                    case 2: bitPair = ((dataByte >> 5) & 1) << 1 | ((dataByte >> 1) & 1)
                    case 3: bitPair = ((dataByte >> 4) & 1) << 1 | ((dataByte >> 0) & 1)
                    default: bitPair = 0
                    }
                    
                    let paletteIndex = Int(bitPair)
                    let hardwareColor = defaultPalette[paletteIndex]
                    let rgb = amstradCPCPalette[hardwareColor]
                    
                    let bufferIdx = (y * width + x) * 4
                    rgbaBuffer[bufferIdx] = rgb.r
                    rgbaBuffer[bufferIdx + 1] = rgb.g
                    rgbaBuffer[bufferIdx + 2] = rgb.b
                    rgbaBuffer[bufferIdx + 3] = 255
                }
            }
        }
        
        guard let cgImage = createCGImage(from: rgbaBuffer, width: width, height: height) else {
            return nil
        }
        
        return (cgImage, .AmstradCPC(mode: 1, colors: colorsPerMode))
    }
    
    // --- ZX Spectrum SCR Decoder (256x192, 6912 bytes) ---
    
    // ZX Spectrum Palette (BRIGHT 0 and BRIGHT 1)
    static let zxSpectrumPalette: [(r: UInt8, g: UInt8, b: UInt8)] = [
        // Normal intensity (BRIGHT 0)
        (0x00, 0x00, 0x00),  // 0: Black
        (0x00, 0x00, 0xD7),  // 1: Blue
        (0xD7, 0x00, 0x00),  // 2: Red
        (0xD7, 0x00, 0xD7),  // 3: Magenta
        (0x00, 0xD7, 0x00),  // 4: Green
        (0x00, 0xD7, 0xD7),  // 5: Cyan
        (0xD7, 0xD7, 0x00),  // 6: Yellow
        (0xD7, 0xD7, 0xD7),  // 7: White
        // Bright intensity (BRIGHT 1)
        (0x00, 0x00, 0x00),  // 8: Black (bright)
        (0x00, 0x00, 0xFF),  // 9: Blue (bright)
        (0xFF, 0x00, 0x00),  // 10: Red (bright)
        (0xFF, 0x00, 0xFF),  // 11: Magenta (bright)
        (0x00, 0xFF, 0x00),  // 12: Green (bright)
        (0x00, 0xFF, 0xFF),  // 13: Cyan (bright)
        (0xFF, 0xFF, 0x00),  // 14: Yellow (bright)
        (0xFF, 0xFF, 0xFF)   // 15: White (bright)
    ]
    
    static func decodeZXSpectrum(data: Data) -> (image: CGImage?, type: AppleIIImageType) {
        guard data.count == 6912 else {
            return (nil, .Unknown)
        }
        
        let width = 256
        let height = 192
        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)
        
        // ZX Spectrum memory layout:
        // 6144 bytes: Bitmap (256x192, 1 bit per pixel)
        // 768 bytes: Color attributes (32x24 cells, 8x8 pixels each)
        
        let bitmapOffset = 0
        let attributeOffset = 6144
        
        // Decode the screen
        // The bitmap has a weird memory layout for historical reasons:
        // It's divided into 3 sections of 2048 bytes each (top, middle, bottom third)
        // Within each section, lines are interleaved in a complex pattern
        
        for y in 0..<height {
            // Calculate the byte offset for this scanline in the weird ZX memory layout
            // The screen is divided into thirds (each 64 lines)
            let third = y / 64          // Which third (0, 1, 2)
            let lineInThird = y % 64
            let octave = lineInThird / 8   // Which 8-line block within the third
            let lineInOctave = lineInThird % 8
            
            // Calculate bitmap address
            let bitmapLineOffset = bitmapOffset + (third * 2048) + (lineInOctave * 256) + (octave * 32)
            
            // Calculate which attribute row this line belongs to
            let attrY = y / 8
            
            for x in 0..<width {
                let xByte = x / 8
                let xBit = 7 - (x % 8)
                
                // Get bitmap byte
                let bitmapByteOffset = bitmapLineOffset + xByte
                let bitmapByte = data[bitmapByteOffset]
                let pixelBit = (bitmapByte >> xBit) & 1
                
                // Get attribute byte (8x8 cell)
                let attrX = x / 8
                let attrIndex = attributeOffset + (attrY * 32) + attrX
                let attrByte = data[attrIndex]
                
                // Decode attribute byte:
                // Bit 7: FLASH (we'll ignore for static image)
                // Bit 6: BRIGHT (0 = normal, 1 = bright)
                // Bits 5-3: PAPER (background) color
                // Bits 2-0: INK (foreground) color
                
                let flash = (attrByte >> 7) & 1
                let bright = (attrByte >> 6) & 1
                let paper = (attrByte >> 3) & 0x07
                let ink = attrByte & 0x07
                
                // Add 8 to color index if BRIGHT is set
                let paperColor = Int(paper) + (bright == 1 ? 8 : 0)
                let inkColor = Int(ink) + (bright == 1 ? 8 : 0)
                
                // Select color based on pixel bit
                let colorIndex = (pixelBit == 1) ? inkColor : paperColor
                let rgb = zxSpectrumPalette[colorIndex]
                
                let bufferIdx = (y * width + x) * 4
                rgbaBuffer[bufferIdx] = rgb.r
                rgbaBuffer[bufferIdx + 1] = rgb.g
                rgbaBuffer[bufferIdx + 2] = rgb.b
                rgbaBuffer[bufferIdx + 3] = 255
            }
        }
        
        guard let cgImage = createCGImage(from: rgbaBuffer, width: width, height: height) else {
            return (nil, .Unknown)
        }
        
        return (cgImage, .ZXSpectrum)
    }
    
    // C64 HIRES Format - 9009 bytes (Art Studio variant or similar)
    // Format: 2 bytes load address + 8000 bytes bitmap + 1000 bytes screen RAM + 7 bytes extra
    static func decodeC64Hires(data: Data) -> (image: CGImage?, type: AppleIIImageType) {
        guard data.count == 9009 else {
            return (nil, .Unknown)
        }
        
        let width = 320
        let height = 200
        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)
        
        let bitmapOffset = 2
        let screenRAMOffset = 8002
        
        // Decode as HIRES (1 bit per pixel)
        for cellY in 0..<25 {
            for cellX in 0..<40 {
                let cellIndex = cellY * 40 + cellX
                
                // Screen RAM contains foreground (low nybble) and background (high nybble) colors
                let screenByte = data[screenRAMOffset + cellIndex]
                let bgColor = Int((screenByte >> 4) & 0x0F)
                let fgColor = Int(screenByte & 0x0F)
                
                for row in 0..<8 {
                    let bitmapByteOffset = bitmapOffset + (cellIndex * 8) + row
                    if bitmapByteOffset >= data.count { continue }
                    
                    let bitmapByte = data[bitmapByteOffset]
                    let y = cellY * 8 + row
                    
                    // Each bit is one pixel (320 pixels wide)
                    for bit in 0..<8 {
                        let x = cellX * 8 + bit
                        let bitVal = (bitmapByte >> (7 - bit)) & 1
                        let colorIndex = (bitVal == 0) ? fgColor : bgColor  // Inverted: 0 = foreground
                        
                        let rgb = c64Palette[colorIndex]
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
        
        guard let cgImage = createCGImage(from: rgbaBuffer, width: width, height: height) else {
            return (nil, .Unknown)
        }
        
        return (cgImage, .C64(format: "C64 HIRES"))
    }
    
    // --- Commodore 64 Decoders ---
    
    // C64 Color Palette (16 colors)
    static let c64Palette: [(r: UInt8, g: UInt8, b: UInt8)] = [
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
    
    // Koala Painter (.KOA, .KLA) - 10003 bytes
    // Format: 2 bytes load address + 8000 bytes bitmap + 1000 bytes screen RAM + 1000 bytes color RAM + 1 byte background
    static func decodeC64Koala(data: Data) -> (image: CGImage?, type: AppleIIImageType) {
        guard data.count == 10003 else {
            return (nil, .Unknown)
        }
        
        let width = 320
        let height = 200
        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)
        
        // Koala format offsets
        let bitmapOffset = 2           // Skip load address
        let screenRAMOffset = 8002     // Bitmap + load address
        let colorRAMOffset = 9002      // + screen RAM
        let backgroundOffset = 10002   // + color RAM
        
        let backgroundColor = data[backgroundOffset] & 0x0F
        
        // Decode bitmap (160x200 cells, each 4x8 pixels)
        for cellY in 0..<25 {  // 25 rows of cells
            for cellX in 0..<40 {  // 40 columns of cells
                let cellIndex = cellY * 40 + cellX
                
                // Get color information for this cell
                let screenByte = data[screenRAMOffset + cellIndex]
                let colorByte = data[colorRAMOffset + cellIndex]
                
                // Extract the 4 colors for this cell
                let color0 = backgroundColor  // Background (00)
                let color1 = (screenByte >> 4) & 0x0F  // Upper nybble (01)
                let color2 = screenByte & 0x0F         // Lower nybble (10)
                let color3 = colorByte & 0x0F          // Color RAM (11)
                
                let colors = [color0, color1, color2, color3]
                
                // Decode 8 rows of 4 pixels each
                for row in 0..<8 {
                    let bitmapByteOffset = bitmapOffset + (cellIndex * 8) + row
                    if bitmapByteOffset >= data.count { continue }
                    
                    let bitmapByte = data[bitmapByteOffset]
                    let y = cellY * 8 + row
                    
                    // Decode 4 pixels (2 bits per pixel)
                    for pixelPair in 0..<4 {
                        let x = cellX * 8 + (pixelPair * 2)
                        let bitShift = 6 - (pixelPair * 2)
                        let colorIndex = Int((bitmapByte >> bitShift) & 0x03)
                        
                        let c64Color = Int(colors[colorIndex])
                        let rgb = c64Palette[c64Color]
                        
                        // Each C64 pixel is 2 screen pixels wide (multicolor mode)
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
        
        guard let cgImage = createCGImage(from: rgbaBuffer, width: width, height: height) else {
            return (nil, .Unknown)
        }
        
        return (cgImage, .C64(format: "Koala Painter"))
    }
    
    // Advanced Art Studio (.ART, .OCP) - 10018 bytes
    // Note: Many 10018 byte files are actually Koala format with 15 extra bytes
    // This decoder treats them as standard Koala layout
    static func decodeC64ArtStudio(data: Data) -> (image: CGImage?, type: AppleIIImageType) {
        guard data.count == 10018 else {
            return (nil, .Unknown)
        }
        
        let width = 320
        let height = 200
        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)
        
        // Standard Koala offsets (10018 byte variant)
        let bitmapOffset = 2
        let screenRAMOffset = 8002
        let colorRAMOffset = 9002
        let backgroundOffset = 10002
        
        let backgroundColor = data[backgroundOffset] & 0x0F
        
        // Decode using standard Koala algorithm
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
                        let rgb = c64Palette[c64Color]
                        
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
        
        guard let cgImage = createCGImage(from: rgbaBuffer, width: width, height: height) else {
            return (nil, .Unknown)
        }
        
        return (cgImage, .C64(format: "C64 Multicolor (10018 bytes)"))
    }
    
    // --- Atari ST Degas Decoder (.PI1, .PI2, .PI3) ---
    static func decodeDegas(data: Data) -> (image: CGImage?, type: AppleIIImageType) {
        guard data.count >= 34 else {
            return (nil, .Unknown)
        }
        
        // Read resolution mode (0 = low, 1 = medium, 2 = high)
        let resolutionMode = Int(readBigEndianUInt16(data: data, offset: 0))
        
        let width: Int
        let height: Int
        let numPlanes: Int
        let numColors: Int
        let resolutionName: String
        
        switch resolutionMode {
        case 0: // Low res: 320x200, 16 colors (4 bitplanes)
            width = 320
            height = 200
            numPlanes = 4
            numColors = 16
            resolutionName = "Low"
            
        case 1: // Medium res: 640x200, 4 colors (2 bitplanes)
            width = 640
            height = 200
            numPlanes = 2
            numColors = 4
            resolutionName = "Medium"
            
        case 2: // High res: 640x400, 2 colors (1 bitplane, monochrome)
            width = 640
            height = 400
            numPlanes = 1
            numColors = 2
            resolutionName = "High"
            
        default:
            return (nil, .Unknown)
        }
        
        // Read palette (16 ST color words starting at offset 2)
        var palette: [(r: UInt8, g: UInt8, b: UInt8)] = []
        for i in 0..<16 {
            let colorWord = readBigEndianUInt16(data: data, offset: 2 + (i * 2))
            
            // Atari ST color format: 0x0RGB (4 bits per channel, 0-7 range)
            let r4 = (colorWord >> 8) & 0x07
            let g4 = (colorWord >> 4) & 0x07
            let b4 = colorWord & 0x07
            
            // Scale from 0-7 to 0-255
            let r = UInt8((r4 * 255) / 7)
            let g = UInt8((g4 * 255) / 7)
            let b = UInt8((b4 * 255) / 7)
            
            palette.append((r, g, b))
        }
        
        // Image data starts at offset 34
        let imageDataOffset = 34
        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)
        
        // Degas uses interleaved bitplanes per 16-pixel chunk (word)
        let wordsPerLine = width / 16
        let bytesPerLine = wordsPerLine * numPlanes * 2
        
        for y in 0..<height {
            let lineOffset = imageDataOffset + (y * bytesPerLine)
            
            for wordIdx in 0..<wordsPerLine {
                // Read all bitplanes for this 16-pixel word
                var planeWords: [UInt16] = []
                for plane in 0..<numPlanes {
                    let offset = lineOffset + (wordIdx * numPlanes * 2) + (plane * 2)
                    if offset + 1 < data.count {
                        planeWords.append(readBigEndianUInt16(data: data, offset: offset))
                    } else {
                        planeWords.append(0)
                    }
                }
                
                // Decode 16 pixels from the bitplane words
                for bit in 0..<16 {
                    let x = wordIdx * 16 + bit
                    if x >= width { break }
                    
                    let bitPos = 15 - bit
                    var colorIndex = 0
                    
                    // Build color index from bitplanes
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
        
        guard let cgImage = createCGImage(from: rgbaBuffer, width: width, height: height) else {
            return (nil, .Unknown)
        }
        
        return (cgImage, .DEGAS(resolution: resolutionName, colors: numColors))
    }
    
    // --- IFF/ILBM Decoder (Amiga Format) ---
    static func decodeIFF(data: Data) -> (image: CGImage?, type: AppleIIImageType) {
        guard data.count >= 12 else {
            return (nil, .Unknown)
        }
        
        // Verify FORM header
        guard let formHeader = String(data: data.subdata(in: 0..<4), encoding: .ascii),
              formHeader == "FORM" else {
            return (nil, .Unknown)
        }
        
        // Read file size (big-endian)
        let fileSize = readBigEndianUInt32(data: data, offset: 4)
        
        // Verify ILBM type
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
        
        // Parse IFF chunks
        while offset + 8 <= data.count {
            guard let chunkID = String(data: data.subdata(in: offset..<offset+4), encoding: .ascii) else {
                break
            }
            
            let chunkSize = Int(readBigEndianUInt32(data: data, offset: offset + 4))
            offset += 8
            
            if offset + chunkSize > data.count {
                break
            }
            
            switch chunkID {
            case "BMHD": // Bitmap Header
                if chunkSize >= 20 {
                    width = Int(readBigEndianUInt16(data: data, offset: offset))
                    height = Int(readBigEndianUInt16(data: data, offset: offset + 2))
                    numPlanes = Int(data[offset + 8])
                    masking = data[offset + 9]
                    compression = data[offset + 10]
                }
                
            case "CMAP": // Color Map
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
                
            case "BODY": // Image Data
                bodyOffset = offset
                bodySize = chunkSize
            
            default:
                break
            }
            
            // Move to next chunk (aligned to even boundary)
            offset += chunkSize
            if chunkSize % 2 == 1 {
                offset += 1
            }
        }
        
        // Validate we have all required data
        guard width > 0, height > 0, numPlanes > 0, bodyOffset > 0 else {
            return (nil, .Unknown)
        }
        
        // Check if this is 24-bit RGB (24 or 25 planes with masking)
        let is24Bit = (numPlanes == 24 || numPlanes == 25 || (numPlanes == 32))
        
        // Decode the image
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
        
        let colorDescription = is24Bit ? "24-bit RGB" : "\(1 << numPlanes) colors"
        return (finalImage, .IFF(width: width, height: height, colors: colorDescription))
    }
    
    static func decodeILBM24Body(data: Data, bodyOffset: Int, bodySize: Int, width: Int, height: Int, numPlanes: Int, compression: UInt8, masking: UInt8) -> CGImage? {
        
        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)
        var srcOffset = bodyOffset
        
        let bytesPerRow = ((width + 15) / 16) * 2
        let planesPerChannel = 8
        
        // 24-bit IFF uses interleaved bitplanes per scanline:
        // For each row: R0-R7, G0-G7, B0-B7 (8 planes per color channel)
        
        for y in 0..<height {
            var planeBits: [[UInt8]] = Array(repeating: [], count: numPlanes)
            
            // Read all 24 bitplanes for this scanline
            for plane in 0..<numPlanes {
                var rowData: [UInt8] = []
                
                if compression == 1 { // RLE compression (ByteRun1)
                    var bytesRead = 0
                    while bytesRead < bytesPerRow && srcOffset < bodyOffset + bodySize && srcOffset < data.count {
                        let cmd = Int8(bitPattern: data[srcOffset])
                        srcOffset += 1
                        
                        if cmd >= 0 {
                            // Literal run: copy next (cmd + 1) bytes
                            let count = Int(cmd) + 1
                            for _ in 0..<count {
                                if srcOffset < bodyOffset + bodySize && srcOffset < data.count && bytesRead < bytesPerRow {
                                    rowData.append(data[srcOffset])
                                    srcOffset += 1
                                    bytesRead += 1
                                }
                            }
                        } else if cmd != -128 {
                            // Repeat run: repeat next byte (-cmd + 1) times
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
                        // cmd == -128 is NOP, skip it
                    }
                } else {
                    // No compression
                    for _ in 0..<bytesPerRow {
                        if srcOffset < bodyOffset + bodySize && srcOffset < data.count {
                            rowData.append(data[srcOffset])
                            srcOffset += 1
                        }
                    }
                }
                
                planeBits[plane] = rowData
            }
            
            // Convert 24 bitplanes to RGB pixels for this scanline
            for x in 0..<width {
                let byteIndex = x / 8
                let bitIndex = 7 - (x % 8)
                
                var r: UInt8 = 0
                var g: UInt8 = 0
                var b: UInt8 = 0
                
                // Extract R, G, B values from their respective 8 bitplanes
                // Red: planes 0-7 (LSB in plane 0, MSB in plane 7)
                for bit in 0..<planesPerChannel {
                    let plane = bit
                    if plane < planeBits.count && byteIndex < planeBits[plane].count {
                        let bitVal = (planeBits[plane][byteIndex] >> bitIndex) & 1
                        r |= bitVal << bit  // LSB first!
                    }
                }
                
                // Green: planes 8-15 (LSB first)
                for bit in 0..<planesPerChannel {
                    let plane = planesPerChannel + bit
                    if plane < planeBits.count && byteIndex < planeBits[plane].count {
                        let bitVal = (planeBits[plane][byteIndex] >> bitIndex) & 1
                        g |= bitVal << bit  // LSB first!
                    }
                }
                
                // Blue: planes 16-23 (LSB first)
                for bit in 0..<planesPerChannel {
                    let plane = 2 * planesPerChannel + bit
                    if plane < planeBits.count && byteIndex < planeBits[plane].count {
                        let bitVal = (planeBits[plane][byteIndex] >> bitIndex) & 1
                        b |= bitVal << bit  // LSB first!
                    }
                }
                
                let bufferIdx = (y * width + x) * 4
                rgbaBuffer[bufferIdx] = r
                rgbaBuffer[bufferIdx + 1] = g
                rgbaBuffer[bufferIdx + 2] = b
                rgbaBuffer[bufferIdx + 3] = 255
            }
        }
        
        return createCGImage(from: rgbaBuffer, width: width, height: height)
    }
    
    static func decodeILBMBody(data: Data, bodyOffset: Int, bodySize: Int, width: Int, height: Int, numPlanes: Int, compression: UInt8, palette: [(r: UInt8, g: UInt8, b: UInt8)]) -> CGImage? {
        
        let bytesPerRow = ((width + 15) / 16) * 2 // Round up to word boundary
        var rgbaBuffer = [UInt8](repeating: 0, count: width * height * 4)
        
        // Create default palette if none provided
        var finalPalette = palette
        let numColors = 1 << numPlanes
        
        if finalPalette.isEmpty || finalPalette.count < numColors {
            // Generate grayscale palette
            finalPalette = []
            for i in 0..<numColors {
                let gray = UInt8((i * 255) / (numColors - 1))
                finalPalette.append((gray, gray, gray))
            }
        }
        
        var srcOffset = bodyOffset
        
        for y in 0..<height {
            var planeBits: [[UInt8]] = Array(repeating: [], count: numPlanes)
            
            // Read each bitplane for this row
            for plane in 0..<numPlanes {
                var rowData: [UInt8] = []
                
                if compression == 1 { // RLE compression
                    var bytesRead = 0
                    while bytesRead < bytesPerRow && srcOffset < bodyOffset + bodySize {
                        let cmd = Int8(bitPattern: data[srcOffset])
                        srcOffset += 1
                        
                        if cmd >= 0 {
                            // Copy next (cmd + 1) bytes literally
                            let count = Int(cmd) + 1
                            for _ in 0..<count {
                                if srcOffset < bodyOffset + bodySize && bytesRead < bytesPerRow {
                                    rowData.append(data[srcOffset])
                                    srcOffset += 1
                                    bytesRead += 1
                                }
                            }
                        } else if cmd != -128 {
                            // Repeat next byte (-cmd + 1) times
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
                    // No compression
                    for _ in 0..<bytesPerRow {
                        if srcOffset < bodyOffset + bodySize {
                            rowData.append(data[srcOffset])
                            srcOffset += 1
                        }
                    }
                }
                
                planeBits[plane] = rowData
            }
            
            // Convert bitplanes to pixels
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
        
        return createCGImage(from: rgbaBuffer, width: width, height: height)
    }
    
    // Helper functions for reading big-endian values
    static func readBigEndianUInt32(data: Data, offset: Int) -> UInt32 {
        guard offset + 4 <= data.count else { return 0 }
        return (UInt32(data[offset]) << 24) |
               (UInt32(data[offset + 1]) << 16) |
               (UInt32(data[offset + 2]) << 8) |
               UInt32(data[offset + 3])
    }
    
    static func readBigEndianUInt16(data: Data, offset: Int) -> UInt16 {
        guard offset + 2 <= data.count else { return 0 }
        return (UInt16(data[offset]) << 8) | UInt16(data[offset + 1])
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
