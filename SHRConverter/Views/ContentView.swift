import SwiftUI
import UniformTypeIdentifiers
import AppKit

// MARK: - Content View

struct ContentView: View {
    @State private var filesToConvert: [URL] = []
    @State private var imageItems: [ImageItem] = []
    @State private var selectedImage: ImageItem?
    @State private var selectedImages: Set<UUID> = []
    @State private var selectedExportFormat: ExportFormat = .png
    @State private var statusMessage: String = "Drag files/folders or open files to start."
    @State private var isProcessing = false
    @State private var progressString = ""
    @State private var showBrowser = false
    @State private var upscaleFactor: Int = 1
    @State private var zoomScale: CGFloat = 1.0
    @State private var filterFormat: String = "All"
    @State private var showCatalogBrowser = false
    @State private var currentCatalog: DiskCatalog? = nil
    
    var filteredImages: [ImageItem] {
        if filterFormat == "All" { return imageItems }
        return imageItems.filter { item in
            let typeName = item.type.displayName
            switch filterFormat {
            case "Apple II": return typeName.contains("SHR") || typeName.contains("HGR") || typeName.contains("DHGR")
            case "C64": return typeName.contains("C64")
            case "Amiga": return typeName.contains("IFF")
            case "Atari ST": return typeName.contains("DEGAS")
            case "ZX Spectrum": return typeName.contains("ZX Spectrum")
            case "CPC": return typeName.contains("CPC")
            case "PC": return typeName.contains("PCX") || typeName.contains("BMP")
            case "Mac": return typeName.contains("MacPaint")
            case "Modern": return typeName.contains("PNG") || typeName.contains("JPEG") || typeName.contains("GIF") || typeName.contains("TIFF") || typeName.contains("HEIC") || typeName.contains("WEBP")
            default: return true
            }
        }
    }
    
    var body: some View {
        HSplitView {
            if showBrowser && !imageItems.isEmpty { browserPanel.frame(minWidth: 250, idealWidth: 300) }
            mainPanel.frame(minWidth: 500)
        }
        .padding()
        .sheet(isPresented: $showCatalogBrowser) {
            if let catalog = currentCatalog {
                DiskCatalogBrowserView(catalog: catalog, onImport: { selectedEntries in importCatalogEntries(selectedEntries); showCatalogBrowser = false }, onCancel: { showCatalogBrowser = false })
            }
        }
    }
    
    var browserPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Image Browser").font(.headline)
                Spacer()
                Button(action: { if selectedImages.count == filteredImages.count { selectedImages.removeAll() } else { selectedImages = Set(filteredImages.map { $0.id }) } }) {
                    Image(systemName: selectedImages.count == filteredImages.count ? "checkmark.square.fill" : "square")
                }.help(selectedImages.count == filteredImages.count ? "Deselect All" : "Select All")
                Button(action: { deleteSelectedImages() }) { Image(systemName: "trash") }.help(selectedImages.isEmpty ? "Delete current image" : "Delete \(selectedImages.count) selected image(s)")
            }
            HStack {
                Text("Filter:").font(.caption)
                Picker("", selection: $filterFormat) {
                    Text("All").tag("All"); Text("Apple II").tag("Apple II"); Text("C64").tag("C64"); Text("Amiga").tag("Amiga")
                    Text("Atari ST").tag("Atari ST"); Text("ZX Spectrum").tag("ZX Spectrum"); Text("Amstrad CPC").tag("CPC")
                    Text("PC (PCX/BMP)").tag("PC"); Text("Mac").tag("Mac"); Text("Modern (PNG/JPG)").tag("Modern")
                }.labelsHidden()
                Spacer()
            }
            Divider()
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 10)], spacing: 10) {
                    ForEach(filteredImages) { item in
                        ImageThumbnailView(item: item, isSelected: selectedImage?.id == item.id, isChecked: selectedImages.contains(item.id),
                            onSelect: { selectedImage = item },
                            onToggleCheck: { if selectedImages.contains(item.id) { selectedImages.remove(item.id) } else { selectedImages.insert(item.id) } })
                    }
                }.padding(.horizontal, 5)
            }
            .onDrop(of: [.fileURL, .url, .data, .png, .jpeg, .gif, .bmp, .tiff, .pcx, .shr, .pic, .pnt, .twoimg, .dsk, .hdv], isTargeted: nil) { providers in loadDroppedFiles(providers); return true }
        }.padding().background(Color(NSColor.controlBackgroundColor))
    }
    
    var mainPanel: some View {
        VStack(spacing: 20) {
            if !imageItems.isEmpty && selectedImage != nil {
                HStack {
                    Spacer()
                    if let selectedImg = selectedImage {
                        HStack(spacing: 15) {
                            HStack(spacing: 8) {
                                Text(selectedImg.filename).font(.caption).fontWeight(.medium)
                                Text("•").foregroundColor(.secondary)
                                Text(selectedImg.type.displayName).font(.caption).padding(.horizontal, 6).padding(.vertical, 2).background(Color.blue.opacity(0.2)).cornerRadius(4)
                            }
                            Divider().frame(height: 20)
                            HStack(spacing: 8) {
                                Button(action: { zoomScale = max(0.5, zoomScale / 1.5) }) { Image(systemName: "minus.magnifyingglass") }.help("Zoom Out")
                                Text("\(Int(zoomScale * 100))%").font(.caption).monospacedDigit().frame(width: 50)
                                Button(action: { zoomScale = min(10.0, zoomScale * 1.5) }) { Image(systemName: "plus.magnifyingglass") }.help("Zoom In")
                                Button(action: { zoomScale = 1.0 }) { Image(systemName: "arrow.counterclockwise") }.help("Reset Zoom")
                            }.buttonStyle(.borderless)
                        }
                    }
                }.padding(.horizontal).padding(.vertical, 8).background(Color(NSColor.controlBackgroundColor)).cornerRadius(8)
            }
            
            ZStack {
                RoundedRectangle(cornerRadius: 12).stroke(style: StrokeStyle(lineWidth: 2, dash: [10])).foregroundColor(isProcessing ? .blue : (!imageItems.isEmpty ? .green : .secondary)).background(Color(NSColor.controlBackgroundColor))
                
                if let selectedImg = selectedImage {
                    GeometryReader { geometry in
                        ScrollView([.horizontal, .vertical], showsIndicators: true) {
                            Image(nsImage: selectedImg.image).resizable().interpolation(.none)
                                .frame(width: CGFloat(selectedImg.image.size.width) * zoomScale, height: CGFloat(selectedImg.image.size.height) * zoomScale)
                                .gesture(MagnificationGesture().onChanged { value in zoomScale = max(0.5, min(value, 10.0)) })
                        }.frame(maxWidth: .infinity, maxHeight: .infinity)
                    }.frame(height: 450).padding()
                } else if imageItems.isEmpty {
                    VStack(spacing: 15) {
                        Image(systemName: "photo.stack").font(.system(size: 50)).foregroundColor(.secondary)
                        Text("Retro Graphics Converter").font(.headline)
                        Text("Supports Apple II (including disk images: 2IMG, DSK, HDV), Amiga IFF, Atari ST, C64, ZX Spectrum, Amstrad CPC, PCX, BMP, MacPaint, plus modern formats.").multilineTextAlignment(.center).font(.caption).foregroundColor(.secondary)
                        Text("Drag & drop files/folders or click 'Open Files...'").font(.caption).foregroundColor(.secondary)
                    }
                } else {
                    VStack(spacing: 15) {
                        Image(systemName: "hand.tap").font(.system(size: 50)).foregroundColor(.secondary)
                        Text("Select an image from the browser").font(.headline).foregroundColor(.secondary)
                    }
                }
                
                if isProcessing {
                    VStack(spacing: 10) { ProgressView().scaleEffect(1.5); Text(progressString).font(.caption).padding(.top, 10) }
                        .padding().background(Color(NSColor.windowBackgroundColor).opacity(0.9)).cornerRadius(10)
                }
            }
            .frame(height: 450)
            .onDrop(of: [.fileURL, .url, .data, .png, .jpeg, .gif, .bmp, .tiff, .pcx, .shr, .pic, .pnt, .twoimg, .dsk, .hdv], isTargeted: nil) { providers in loadDroppedFiles(providers); return true }
            
            VStack(spacing: 10) {
                HStack {
                    Button("Open Files...") { openFiles() }
                    Button(showBrowser ? "Hide Browser" : "Show Browser") { withAnimation { showBrowser.toggle() } }.disabled(imageItems.isEmpty)
                    Spacer()
                    Picker("Upscale:", selection: $upscaleFactor) { Text("1x (Original)").tag(1); Text("2x").tag(2); Text("4x").tag(4); Text("8x").tag(8) }.frame(width: 150)
                    Picker("Export As:", selection: $selectedExportFormat) { ForEach(ExportFormat.allCases, id: \.self) { format in Text(format.rawValue).tag(format) } }.frame(width: 180)
                }
                HStack(spacing: 10) {
                    Button("Export Selected (\(selectedImages.isEmpty ? 1 : selectedImages.count))...") { exportSelectedImages() }.disabled((selectedImage == nil && selectedImages.isEmpty) || isProcessing)
                    Button("Export All (\(imageItems.count))...") { exportAllImages() }.disabled(imageItems.isEmpty || isProcessing)
                    Button("Export with Custom Names...") { showBatchRename() }.disabled(imageItems.isEmpty || isProcessing)
                    Spacer()
                }
            }
            
            VStack(alignment: .leading, spacing: 5) {
                Text(statusMessage).font(.headline)
                if !progressString.isEmpty && !isProcessing { Text(progressString).font(.caption).foregroundColor(.secondary) }
            }.frame(maxWidth: .infinity, alignment: .leading)
        }.padding()
    }
    
    // MARK: - File Handling
    
    func importCatalogEntries(_ entries: [DiskCatalogEntry]) {
        DispatchQueue.global(qos: .userInitiated).async {
            var newItems: [ImageItem] = []
            for entry in entries {
                if entry.isImage, let cgImage = SHRDecoder.decode(data: entry.data, filename: entry.name).image {
                    let url = URL(fileURLWithPath: "/catalog/\(entry.name)")
                    let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                    newItems.append(ImageItem(url: url, image: nsImage, type: entry.imageType))
                }
            }
            DispatchQueue.main.async {
                self.imageItems.append(contentsOf: newItems)
                if !newItems.isEmpty { self.showBrowser = true; if self.selectedImage == nil { self.selectedImage = newItems.first } }
                self.statusMessage = "Imported \(newItems.count) image(s) from catalog"
            }
        }
    }
    
    func clearAllImages() {
        imageItems = []; selectedImage = nil; selectedImages.removeAll(); filesToConvert = []
        statusMessage = "All images cleared."; progressString = ""; showBrowser = false
    }
    
    func deleteSelectedImages() {
        if selectedImages.isEmpty {
            if let current = selectedImage {
                imageItems.removeAll { $0.id == current.id }
                selectedImage = imageItems.first
                if imageItems.isEmpty { showBrowser = false }
                statusMessage = "Image deleted."
            }
        } else {
            let count = selectedImages.count
            imageItems.removeAll { selectedImages.contains($0.id) }
            selectedImages.removeAll()
            if let current = selectedImage, !imageItems.contains(where: { $0.id == current.id }) { selectedImage = imageItems.first }
            if imageItems.isEmpty { selectedImage = nil; showBrowser = false }
            statusMessage = "Deleted \(count) image(s)."
        }
    }
    
    func showBatchRename() {
        let alert = NSAlert()
        alert.messageText = "Batch Export with Custom Names"
        alert.informativeText = "Export all images with custom names. Use {n} for number, {name} for original name."
        alert.alertStyle = .informational; alert.addButton(withTitle: "Export"); alert.addButton(withTitle: "Cancel")
        let inputField = NSTextField(frame: NSRect(x: 0, y: 0, width: 300, height: 24))
        inputField.stringValue = "{name}_converted"; alert.accessoryView = inputField
        if alert.runModal() == .alertFirstButtonReturn { batchExportWithRename(pattern: inputField.stringValue) }
    }
    
    func batchExportWithRename(pattern: String) {
        guard !imageItems.isEmpty else { return }
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false; openPanel.canChooseDirectories = true; openPanel.allowsMultipleSelection = false
        openPanel.canCreateDirectories = true; openPanel.prompt = "Select Export Folder"
        if openPanel.runModal() == .OK, let outputFolderURL = openPanel.url {
            isProcessing = true
            DispatchQueue.global(qos: .userInitiated).async {
                var successCount = 0
                for (index, item) in self.imageItems.enumerated() {
                    DispatchQueue.main.async { self.progressString = "Exporting \(index + 1) of \(self.imageItems.count)" }
                    var newName = pattern.replacingOccurrences(of: "{n}", with: "\(index + 1)").replacingOccurrences(of: "{name}", with: item.url.deletingPathExtension().lastPathComponent)
                    let filename = "\(newName).\(self.selectedExportFormat.fileExtension)"
                    if self.saveImage(image: item.image, to: outputFolderURL.appendingPathComponent(filename), format: self.selectedExportFormat) { successCount += 1 }
                }
                DispatchQueue.main.async { self.isProcessing = false; self.statusMessage = "Exported \(successCount) of \(self.imageItems.count) image(s) with custom names"; self.progressString = "" }
            }
        }
    }
    
    func openFiles() {
        let openPanel = NSOpenPanel()
        openPanel.allowsOtherFileTypes = true; openPanel.allowsMultipleSelection = true; openPanel.canChooseDirectories = true; openPanel.canChooseFiles = true
        openPanel.prompt = "Open Files or Folders"
        openPanel.allowedContentTypes = [.png, .jpeg, .gif, .bmp, .tiff, .pcx, .shr, .pic, .pnt, .twoimg, .dsk, .hdv, .data]
        if openPanel.runModal() == .OK { processFilesAndFolders(urls: openPanel.urls) }
    }
    
    func loadDroppedFiles(_ providers: [NSItemProvider]) {
        isProcessing = true; statusMessage = "Loading dropped files..."
        var filesToProcess: [(data: Data, name: String, url: URL?)] = []
        let dispatchGroup = DispatchGroup()
        
        for (index, provider) in providers.enumerated() {
            dispatchGroup.enter()
            provider.loadFileRepresentation(forTypeIdentifier: UTType.data.identifier) { url, error in
                if let url = url, let data = try? Data(contentsOf: url) {
                    filesToProcess.append((data: data, name: url.lastPathComponent, url: url))
                    dispatchGroup.leave()
                } else {
                    guard let typeIdentifier = provider.registeredTypeIdentifiers.first else { dispatchGroup.leave(); return }
                    provider.loadDataRepresentation(forTypeIdentifier: typeIdentifier) { data, error in
                        defer { dispatchGroup.leave() }
                        if let data = data { filesToProcess.append((data: data, name: "dropped_file_\(index).\(typeIdentifier.split(separator: ".").last ?? "bin")", url: nil)) }
                    }
                }
            }
        }
        
        dispatchGroup.notify(queue: .main) {
            if filesToProcess.isEmpty { self.isProcessing = false; self.statusMessage = "No files received"; return }
            DispatchQueue.global(qos: .userInitiated).async {
                var newItems: [ImageItem] = []; var successCount = 0
                for (fileIndex, file) in filesToProcess.enumerated() {
                    DispatchQueue.main.async { self.progressString = "Processing \(fileIndex + 1) of \(filesToProcess.count): \(file.name)" }
                    let data = file.data; let fileName = file.name
                    let isPNG = data.count >= 8 && data[0] == 0x89 && data[1] == 0x50 && data[2] == 0x4E && data[3] == 0x47
                    let isJPEG = data.count >= 2 && data[0] == 0xFF && data[1] == 0xD8
                    let isGIF = data.count >= 6 && data[0] == 0x47 && data[1] == 0x49 && data[2] == 0x46
                    let isBMP = data.count >= 2 && data[0] == 0x42 && data[1] == 0x4D
                    let isPCX = data.count >= 128 && data[0] == 0x0A
                    let isModernImage = isPNG || isJPEG || isGIF || isBMP || isPCX
                    let possibleDiskImage = !isModernImage && (data.count == 143360 || data.count == 819200 || data.count > 100000)
                    var processedAsDiskImage = false
                    
                    if possibleDiskImage {
                        if let catalog = DiskImageReader.readDiskCatalog(data: data, filename: fileName) {
                            DispatchQueue.main.async { self.currentCatalog = catalog; self.showCatalogBrowser = true; self.isProcessing = false }
                            continue
                        }
                        DispatchQueue.main.async { self.statusMessage = "Could not read disk image: \(fileName)" }
                        processedAsDiskImage = true
                    }
                    
                    if !processedAsDiskImage {
                        let result = SHRDecoder.decode(data: data, filename: fileName)
                        if let cgImage = result.image, result.type != .Unknown {
                            let fileURL = file.url ?? URL(fileURLWithPath: "/\(fileName)")
                            let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                            newItems.append(ImageItem(url: fileURL, image: nsImage, type: result.type)); successCount += 1
                        }
                    }
                }
                DispatchQueue.main.async {
                    self.imageItems.append(contentsOf: newItems); self.isProcessing = false
                    if successCount > 0 { self.statusMessage = "Loaded \(successCount) image(s) from \(filesToProcess.count) file(s)"; self.showBrowser = true; if self.selectedImage == nil { self.selectedImage = newItems.first } }
                    else { self.statusMessage = "No valid images found" }
                    self.progressString = ""
                }
            }
        }
    }
    
    func processFilesAndFolders(urls: [URL]) {
        guard !urls.isEmpty else { isProcessing = false; return }
        isProcessing = true; statusMessage = "Scanning files and folders..."
        DispatchQueue.global(qos: .userInitiated).async {
            var allFileURLs: [URL] = []
            for url in urls {
                var isDirectory: ObjCBool = false
                if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) {
                    if isDirectory.boolValue { if let files = self.scanFolder(url: url) { allFileURLs.append(contentsOf: files) } }
                    else { allFileURLs.append(url) }
                }
            }
            DispatchQueue.main.async {
                if allFileURLs.isEmpty { self.isProcessing = false; self.statusMessage = "No files found"; self.progressString = "" }
                else { self.processFiles(urls: allFileURLs) }
            }
        }
    }
    
    func scanFolder(url: URL) -> [URL]? {
        var fileURLs: [URL] = []
        guard let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: [.isRegularFileKey], options: [.skipsHiddenFiles]) else { return nil }
        for case let fileURL as URL in enumerator {
            if let fileAttributes = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]), fileAttributes.isRegularFile == true {
                if let fileSize = (try? FileManager.default.attributesOfItem(atPath: fileURL.path)[.size] as? Int), fileSize > 0 { fileURLs.append(fileURL) }
            }
        }
        return fileURLs
    }
    
    func processFiles(urls: [URL]) {
        guard !urls.isEmpty else { isProcessing = false; return }
        isProcessing = true; statusMessage = "Processing \(urls.count) file(s)..."
        DispatchQueue.global(qos: .userInitiated).async {
            var newItems: [ImageItem] = []; var successCount = 0
            for (index, url) in urls.enumerated() {
                DispatchQueue.main.async { self.progressString = "Processing \(index + 1) of \(urls.count): \(url.lastPathComponent)" }
                guard let data = try? Data(contentsOf: url) else { continue }
                let fileExtension = url.pathExtension.lowercased()
                if fileExtension == "2mg" || fileExtension == "dsk" || fileExtension == "hdv" || fileExtension == "po" {
                    if let catalog = DiskImageReader.readDiskCatalog(data: data, filename: url.lastPathComponent) {
                        DispatchQueue.main.async { self.currentCatalog = catalog; self.showCatalogBrowser = true; self.isProcessing = false }
                        continue
                    }
                    for diskFile in DiskImageReader.readDiskImage(data: data) {
                        if let cgImage = SHRDecoder.decode(data: diskFile.data, filename: diskFile.name).image {
                            let virtualURL = url.appendingPathComponent(diskFile.name)
                            let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                            newItems.append(ImageItem(url: virtualURL, image: nsImage, type: diskFile.type)); successCount += 1
                        }
                    }
                } else {
                    let result = SHRDecoder.decode(data: data, filename: url.lastPathComponent)
                    if let cgImage = result.image, result.type != .Unknown {
                        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                        newItems.append(ImageItem(url: url, image: nsImage, type: result.type)); successCount += 1
                    }
                }
            }
            DispatchQueue.main.async {
                self.imageItems.append(contentsOf: newItems); self.isProcessing = false
                self.statusMessage = "Loaded \(successCount) image(s) from \(urls.count) file(s)"; self.progressString = ""
                if !newItems.isEmpty { self.showBrowser = true; if self.selectedImage == nil { self.selectedImage = newItems.first } }
            }
        }
    }
    
    // MARK: - Export Functions
    
    func exportSingleImage(_ item: ImageItem) {
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = [UTType(filenameExtension: selectedExportFormat.fileExtension)!]
        savePanel.nameFieldStringValue = "\(item.url.deletingPathExtension().lastPathComponent).\(selectedExportFormat.fileExtension)"
        savePanel.prompt = "Export"; savePanel.canCreateDirectories = true
        savePanel.begin { response in
            if response == .OK, let outputURL = savePanel.url {
                self.isProcessing = true
                DispatchQueue.global(qos: .userInitiated).async {
                    let success = self.saveImage(image: item.image, to: outputURL, format: self.selectedExportFormat)
                    DispatchQueue.main.async {
                        self.isProcessing = false
                        self.statusMessage = success ? "Exported: \(outputURL.lastPathComponent)" : "Export failed!"; self.progressString = ""
                    }
                }
            }
        }
    }
    
    func exportSelectedImages() {
        var itemsToExport: [ImageItem] = []
        if !selectedImages.isEmpty { itemsToExport = imageItems.filter { selectedImages.contains($0.id) } }
        else if let current = selectedImage { itemsToExport = [current] }
        guard !itemsToExport.isEmpty else { return }
        
        if itemsToExport.count == 1 { exportSingleImage(itemsToExport[0]) }
        else {
            let openPanel = NSOpenPanel()
            openPanel.canChooseFiles = false; openPanel.canChooseDirectories = true; openPanel.allowsMultipleSelection = false
            openPanel.canCreateDirectories = true; openPanel.prompt = "Select Export Folder"
            if openPanel.runModal() == .OK, let outputFolderURL = openPanel.url {
                isProcessing = true
                DispatchQueue.global(qos: .userInitiated).async {
                    var successCount = 0
                    for (index, item) in itemsToExport.enumerated() {
                        DispatchQueue.main.async { self.progressString = "Exporting \(index + 1) of \(itemsToExport.count)" }
                        let filename = "\(item.url.deletingPathExtension().lastPathComponent).\(self.selectedExportFormat.fileExtension)"
                        if self.saveImage(image: item.image, to: outputFolderURL.appendingPathComponent(filename), format: self.selectedExportFormat) { successCount += 1 }
                    }
                    DispatchQueue.main.async { self.isProcessing = false; self.statusMessage = "Exported \(successCount) of \(itemsToExport.count) selected image(s)"; self.progressString = "" }
                }
            }
        }
    }
    
    func exportAllImages() {
        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false; openPanel.canChooseDirectories = true; openPanel.allowsMultipleSelection = false
        openPanel.canCreateDirectories = true; openPanel.prompt = "Select Export Folder"
        if openPanel.runModal() == .OK, let outputFolderURL = openPanel.url {
            isProcessing = true
            DispatchQueue.global(qos: .userInitiated).async {
                var successCount = 0
                for (index, item) in self.imageItems.enumerated() {
                    DispatchQueue.main.async { self.progressString = "Exporting \(index + 1) of \(self.imageItems.count)" }
                    let filename = "\(item.url.deletingPathExtension().lastPathComponent).\(self.selectedExportFormat.fileExtension)"
                    if self.saveImage(image: item.image, to: outputFolderURL.appendingPathComponent(filename), format: self.selectedExportFormat) { successCount += 1 }
                }
                DispatchQueue.main.async { self.isProcessing = false; self.statusMessage = "Exported \(successCount) of \(self.imageItems.count) image(s)"; self.progressString = "" }
            }
        }
    }
    
    func saveImage(image: NSImage, to outputURL: URL, format: ExportFormat) -> Bool {
        var finalImage = image
        if upscaleFactor > 1 {
            if let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil), let upscaled = SHRDecoder.upscaleCGImage(cgImage, factor: upscaleFactor) {
                finalImage = NSImage(cgImage: upscaled, size: NSSize(width: upscaled.width, height: upscaled.height))
            }
        }
        guard let tiffData = finalImage.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiffData) else { return false }
        
        var outputData: Data? = nil
        switch format {
        case .png: outputData = bitmap.representation(using: .png, properties: [:])
        case .jpeg: outputData = bitmap.representation(using: .jpeg, properties: [.compressionFactor: 0.9])
        case .tiff: outputData = bitmap.representation(using: .tiff, properties: [:])
        case .gif: outputData = bitmap.representation(using: .gif, properties: [.ditherTransparency: true])
        case .heic:
            if let cgImage = finalImage.cgImage(forProposedRect: nil, context: nil, hints: nil) { outputData = HEICConverter.convert(cgImage: cgImage) }
        }
        guard let finalData = outputData else { return false }
        do { try finalData.write(to: outputURL); return true } catch { return false }
    }
}
