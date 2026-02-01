import SwiftUI
import UniformTypeIdentifiers
import AppKit
import AVFoundation
import CoreMedia
import VideoToolbox

// MARK: - Content View

struct ContentView: View {
    @EnvironmentObject private var appState: AppState
    @State private var filesToConvert: [URL] = []
    @State private var imageItems: [ImageItem] = []
    @State private var selectedImage: ImageItem?
    @State private var selectedImages: Set<UUID> = []
    @State private var selectedExportFormat: ExportFormat = .png
    @State private var statusMessage: String = "Drag files/folders or open files to start."
    @State private var isProcessing = false
    @State private var progressString = ""
    @State private var showBrowser = true
    @State private var upscaleFactor: Int = 1
    @State private var zoomScale: CGFloat = -1.0  // -1 means "fit to window"
    @State private var filterFormat: String = "All"
    @State private var showCatalogBrowser = false
    @State private var currentCatalog: DiskCatalog? = nil
    @State private var cropMode = false
    @State private var cropStart: CGPoint?
    @State private var cropEnd: CGPoint?
    @State private var cropScale: CGFloat = 1.0  // Store the scale used during crop selection
    @State private var undoStack: [(id: UUID, image: NSImage, type: AppleIIImageType, data: Data?, paletteInfo: PaletteInfo?, modifiedPalette: PaletteInfo?, hasImageModification: Bool)] = []

    // New UI state
    @State private var showExportSheet = false
    @State private var showScreensaverSheet = false
    @State private var showMovieSheet = false
    @State private var currentScanline: Int? = 100
    @State private var removedCount = 0
    @State private var exportedCount = 0
    @State private var showOriginal = false

    // Adjustments state
    @State private var showAdjustments = false
    @State private var currentAdjustments = ImageAdjustments()
    @State private var previewAdjustments: ImageAdjustments?
    @State private var thumbnailSize: CGFloat = 80
    
    // Computed property for the image to display (handles Before/After toggle and adjustments preview)
    var displayImage: NSImage? {
        guard let selected = selectedImage else { return nil }

        // If showing original and we have original data, re-decode it
        if showOriginal, let originalData = selected.originalData {
            // Re-decode with original palette
            if let originalPalette = selected.paletteInfo,
               let originalImage = PaletteRenderer.rerenderWithPalette(data: originalData, type: selected.type, palette: originalPalette) {
                return originalImage
            }
            // Fallback: re-decode from scratch
            let result = SHRDecoder.decode(data: originalData, filename: selected.url.lastPathComponent)
            if let cgImage = result.image {
                return NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            }
        }

        // Apply preview adjustments if any
        if let adjustments = previewAdjustments, !adjustments.isIdentity {
            return selected.image.adjustedImage(
                brightness: adjustments.brightness,
                contrast: adjustments.contrast
            )
        }

        // Return the current (possibly modified) image
        return selected.image
    }

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
        VStack(spacing: 0) {
            // Main Toolbar
            MainToolbarView(
                zoomScale: $zoomScale,
                cropMode: $cropMode,
                canUndo: !undoStack.isEmpty,
                hasImage: selectedImage != nil,
                hasModification: selectedImage?.hasAnyModification == true && selectedImage?.originalData != nil,
                hasSelection: !selectedImages.isEmpty,
                hasImages: !imageItems.isEmpty,
                onImport: { openFiles() },
                onExport: { showExportSheet = true },
                onScreensaver: { showScreensaverSheet = true },
                onMovie: { showMovieSheet = true },
                onUndo: { undoLastAction() },
                onRotateLeft: { transformImages(transform: .rotateLeft) },
                onRotateRight: { transformImages(transform: .rotateRight) },
                onFlipHorizontal: { transformImages(transform: .flipHorizontal) },
                onFlipVertical: { transformImages(transform: .flipVertical) },
                onInvert: { transformImages(transform: .invert) },
                onCopy: { copyImageToClipboard() },
                onCompare: { showOriginal.toggle() },
                showOriginal: $showOriginal,
                showAdjustments: $showAdjustments,
                adjustments: $currentAdjustments,
                onAdjustmentsApply: { applyAdjustments() },
                onAdjustmentsReset: { resetAdjustmentsPreview() },
                onAdjustmentsPreview: { adjustments in previewAdjustments = adjustments },
                currentImage: selectedImage?.image
            )

            Divider()

            // Main content area
            HSplitView {
                if showBrowser {
                    browserPanel.frame(minWidth: 250, idealWidth: 300)
                }
                previewPanel.frame(minWidth: 500)
            }

            Divider()

            // Info Bar
            InfoBarView(
                selectedImage: selectedImage,
                currentScanline: $currentScanline,
                onColorEdit: { paletteIndex, colorIndex, newColor in
                    handleColorEdit(paletteIndex: paletteIndex, colorIndex: colorIndex, newColor: newColor)
                },
                onResetPalette: {
                    resetPaletteModification()
                }
            )

            Divider()

            // Status Bar
            StatusBarView(
                importedCount: imageItems.count,
                selectedCount: selectedImages.count,
                removedCount: removedCount,
                exportedCount: exportedCount
            )
        }
        .sheet(isPresented: $showCatalogBrowser) {
            if let catalog = currentCatalog {
                DiskCatalogBrowserView(catalog: catalog, onImport: { selectedEntries in importCatalogEntries(selectedEntries); showCatalogBrowser = false }, onCancel: { showCatalogBrowser = false })
            }
        }
        .sheet(isPresented: $showExportSheet) {
            ExportSheet(
                isPresented: $showExportSheet,
                selectedCount: selectedImages.isEmpty ? (selectedImage != nil ? 1 : imageItems.count) : selectedImages.count,
                onExport: { formats, scale in
                    performBatchExport(formats: formats, scale: scale)
                }
            )
        }
        .sheet(isPresented: $showScreensaverSheet) {
            ScreensaverExportSheet(
                isPresented: $showScreensaverSheet,
                selectedCount: selectedImages.isEmpty ? (selectedImage != nil ? 1 : imageItems.count) : selectedImages.count,
                onExport: { name, scale, openSettings in
                    exportAsScreensaver(name: name, scale: scale, openSettings: openSettings)
                }
            )
        }
        .sheet(isPresented: $showMovieSheet) {
            MovieExportSheet(
                isPresented: $showMovieSheet,
                selectedCount: selectedImages.isEmpty ? (selectedImage != nil ? 1 : imageItems.count) : selectedImages.count,
                onExport: { settings in
                    exportAsMovie(settings: settings)
                }
            )
        }
        .onChange(of: appState.undoTrigger) { oldValue, newValue in
            undoLastAction()
        }
        .onChange(of: appState.openFolderRequest) { oldValue, newValue in
            if let folder = newValue {
                processFilesAndFolders(urls: [folder])
                appState.openFolderRequest = nil
            }
        }
    }
    
    var browserPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
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
                LazyVGrid(columns: [GridItem(.adaptive(minimum: thumbnailSize + 40), spacing: 10)], spacing: 10) {
                    ForEach(filteredImages) { item in
                        ImageThumbnailView(item: item, isSelected: selectedImage?.id == item.id, isChecked: selectedImages.contains(item.id), thumbnailSize: thumbnailSize,
                            onSelect: { selectedImage = item },
                            onToggleCheck: { if selectedImages.contains(item.id) { selectedImages.remove(item.id) } else { selectedImages.insert(item.id) } })
                    }
                }.padding(.horizontal, 5)
            }
            .onDrop(of: [.fileURL, .url, .data, .png, .jpeg, .gif, .bmp, .tiff, .pcx, .shr, .pic, .pnt, .twoimg, .dsk, .hdv, .do_disk, .po, .bbc, .adf, .st, .atr], isTargeted: nil) { providers in loadDroppedFiles(providers); return true }

            Divider()

            // Thumbnail size slider
            HStack(spacing: 8) {
                Image(systemName: "photo")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                Slider(value: $thumbnailSize, in: 50...150, step: 10)
                    .frame(maxWidth: 120)
                Image(systemName: "photo.fill")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 4)
        }.padding(8).background(Color(NSColor.controlBackgroundColor))
    }
    
    var previewPanel: some View {
        VStack(spacing: 8) {
            // Crop mode controls (only shown when in crop mode with selection)
            if cropMode && cropStart != nil && cropEnd != nil {
                HStack(spacing: 8) {
                    Spacer()
                    Button(action: { copySelectedArea() }) {
                        Label("Copy", systemImage: "doc.on.doc")
                    }
                    .help("Copy selected area")

                    Button(action: { cropToSelection() }) {
                        Label("Apply Crop", systemImage: "checkmark.circle")
                    }
                    .buttonStyle(.borderedProminent)
                    .help("Crop to selection")

                    Button(action: { clearSelection() }) {
                        Label("Clear", systemImage: "xmark")
                    }
                    .help("Clear selection")
                    Spacer()
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(NSColor.controlBackgroundColor))
            }

            ZStack {
                Color(NSColor.controlBackgroundColor)
                
                if let selectedImg = selectedImage, let imageToShow = displayImage {
                    GeometryReader { geometry in
                        let fitScale = min(
                            (geometry.size.width - 16) / CGFloat(imageToShow.size.width),
                            (geometry.size.height - 16) / CGFloat(imageToShow.size.height)
                        )
                        let effectiveScale = zoomScale < 0 ? max(1.0, fitScale) : zoomScale

                        ScrollView([.horizontal, .vertical], showsIndicators: true) {
                            ZStack {
                                Image(nsImage: imageToShow)
                                    .resizable()
                                    .interpolation(.none)
                                    .frame(width: CGFloat(imageToShow.size.width) * effectiveScale, height: CGFloat(imageToShow.size.height) * effectiveScale)

                                // Crop overlay
                                if cropMode {
                                    CropOverlayView(
                                        imageSize: imageToShow.size,
                                        imageScale: effectiveScale,
                                        cropStart: $cropStart,
                                        cropEnd: $cropEnd
                                    )
                                    .frame(width: CGFloat(imageToShow.size.width) * effectiveScale, height: CGFloat(imageToShow.size.height) * effectiveScale)
                                }

                                // Scanline tracking overlay for multi-palette images
                                if !cropMode, let paletteInfo = selectedImg.activePalette, paletteInfo.paletteCount > 1 {
                                    ScanlineTrackingOverlay(
                                        imageSize: imageToShow.size,
                                        imageScale: effectiveScale,
                                        paletteCount: paletteInfo.paletteCount,
                                        currentScanline: $currentScanline
                                    )
                                    .frame(width: CGFloat(imageToShow.size.width) * effectiveScale, height: CGFloat(imageToShow.size.height) * effectiveScale)
                                }
                            }
                            .gesture(
                                cropMode ?
                                DragGesture(minimumDistance: 0)
                                    .onChanged { value in
                                        handleCropDrag(value: value, imageSize: imageToShow.size, scale: effectiveScale)
                                    }
                                    .onEnded { _ in
                                        // Validate selection size
                                        if let start = cropStart, let end = cropEnd {
                                            let width = abs(end.x - start.x)
                                            let height = abs(end.y - start.y)
                                            if width < 5 || height < 5 {
                                                clearSelection()
                                            }
                                        }
                                    }
                                : nil
                            )
                            .onHover { hovering in
                                if cropMode {
                                    if hovering {
                                        NSCursor.crosshair.push()
                                    } else {
                                        NSCursor.pop()
                                    }
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(cropMode ? Color.black.opacity(0.3) : Color.clear)
                    }.padding(8)
                } else if imageItems.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "photo.stack").font(.system(size: 48)).foregroundColor(.secondary)
                        Text("Retro Graphics Converter").font(.headline)
                        Text("Supports Apple II (including disk images: 2IMG, DSK, HDV), Amiga IFF, Atari ST, C64, ZX Spectrum, Amstrad CPC, PCX, BMP, MacPaint, plus modern formats.").multilineTextAlignment(.center).font(.caption).foregroundColor(.secondary).padding(.horizontal, 20)
                        Text("Drag & drop files/folders or click 'Open Files...'").font(.caption).foregroundColor(.secondary)
                    }.padding()
                } else {
                    VStack(spacing: 12) {
                        Image(systemName: "hand.tap").font(.system(size: 48)).foregroundColor(.secondary)
                        Text("Select an image from the browser").font(.headline).foregroundColor(.secondary)
                    }
                }
                
                if isProcessing {
                    VStack(spacing: 10) { ProgressView().controlSize(.large); Text(progressString).font(.caption).padding(.top, 10) }
                        .padding().background(Color(NSColor.windowBackgroundColor).opacity(0.9)).cornerRadius(10)
                }
            }
            .frame(maxHeight: .infinity)
            .onDrop(of: [.fileURL, .url, .data, .png, .jpeg, .gif, .bmp, .tiff, .pcx, .shr, .pic, .pnt, .twoimg, .dsk, .hdv, .do_disk, .po, .bbc, .adf, .st, .atr], isTargeted: nil) { providers in loadDroppedFiles(providers); return true }

            // Bottom quick actions bar (only show when processing)
            if isProcessing {
                HStack(spacing: 12) {
                    Spacer()
                    ProgressView()
                        .controlSize(.small)
                    Text(progressString)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 6)
            }
        }
        .padding(4)
    }

    // MARK: - Palette Handling

    func handleColorEdit(paletteIndex: Int, colorIndex: Int, newColor: NSColor) {
        guard var item = selectedImage,
              let originalPalette = item.paletteInfo,
              let originalData = item.originalData else { return }

        // Create modified palette if not already modified
        if item.modifiedPalette == nil {
            item.modifiedPalette = originalPalette
        }

        // Update the color in the modified palette
        let paletteColor = PaletteColor(nsColor: newColor)
        item.modifiedPalette?.updateColor(paletteIndex: paletteIndex, colorIndex: colorIndex, newColor: paletteColor)

        // Re-render the image with the modified palette for live preview
        if let modifiedPalette = item.modifiedPalette,
           let newImage = PaletteRenderer.rerenderWithPalette(data: originalData, type: item.type, palette: modifiedPalette) {
            item.image = newImage
        }

        // Update the image item
        if let index = imageItems.firstIndex(where: { $0.id == item.id }) {
            imageItems[index] = item
            selectedImage = imageItems[index]
        }

        statusMessage = "Color \(colorIndex) modified - live preview"
    }

    func resetPaletteModification() {
        guard var item = selectedImage,
              let originalData = item.originalData,
              let originalPalette = item.paletteInfo else { return }

        // Reset modified palette
        item.modifiedPalette = nil

        // Re-render with original palette to restore original appearance
        if let originalImage = PaletteRenderer.rerenderWithPalette(data: originalData, type: item.type, palette: originalPalette) {
            item.image = originalImage
        } else {
            // Fallback: re-decode from original data
            let result = SHRDecoder.decode(data: originalData, filename: item.url.lastPathComponent)
            if let cgImage = result.image {
                item.image = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
            }
        }

        if let index = imageItems.firstIndex(where: { $0.id == item.id }) {
            imageItems[index] = item
            selectedImage = imageItems[index]
        }

        statusMessage = "Palette reset to original"
    }

    // MARK: - Batch Export

    func performBatchExport(formats: Set<ExportFormat>, scale: Int) {
        var itemsToExport: [ImageItem] = []

        if !selectedImages.isEmpty {
            itemsToExport = imageItems.filter { selectedImages.contains($0.id) }
        } else if let current = selectedImage {
            itemsToExport = [current]
        } else {
            itemsToExport = imageItems
        }

        guard !itemsToExport.isEmpty, !formats.isEmpty else { return }

        let openPanel = NSOpenPanel()
        openPanel.canChooseFiles = false
        openPanel.canChooseDirectories = true
        openPanel.allowsMultipleSelection = false
        openPanel.canCreateDirectories = true
        openPanel.prompt = "Save"

        if openPanel.runModal() == .OK, let outputFolderURL = openPanel.url {
            isProcessing = true
            let savedUpscale = upscaleFactor
            upscaleFactor = scale

            DispatchQueue.global(qos: .userInitiated).async {
                var totalExported = 0

                for format in formats {
                    self.selectedExportFormat = format

                    for (index, item) in itemsToExport.enumerated() {
                        DispatchQueue.main.async {
                            self.progressString = "Exporting \(index + 1)/\(itemsToExport.count) as \(format.rawValue)"
                        }

                        let fileExtension = format == .original ? item.originalFileExtension : format.fileExtension
                        let baseName = item.url.deletingPathExtension().lastPathComponent
                        let filename: String

                        if formats.count > 1 && format != .original {
                            filename = "\(baseName).\(fileExtension)"
                        } else {
                            filename = "\(baseName).\(fileExtension)"
                        }

                        let outputURL = outputFolderURL.appendingPathComponent(filename)

                        if self.saveImage(image: item.image, to: outputURL, format: format, originalData: item.originalData, originalExtension: item.originalFileExtension) {
                            totalExported += 1
                        }
                    }
                }

                DispatchQueue.main.async {
                    self.upscaleFactor = savedUpscale
                    self.isProcessing = false
                    self.exportedCount += totalExported
                    self.statusMessage = "Exported \(totalExported) file(s) to \(outputFolderURL.lastPathComponent)"
                    self.progressString = ""
                }
            }
        }
    }

    // MARK: - Screensaver Export

    func exportAsScreensaver(name: String, scale: Int, openSettings: Bool) {
        // Determine which images to export
        var itemsToExport: [ImageItem] = []

        if !selectedImages.isEmpty {
            itemsToExport = imageItems.filter { selectedImages.contains($0.id) }
        } else if let current = selectedImage {
            itemsToExport = [current]
        } else {
            itemsToExport = imageItems
        }

        guard !itemsToExport.isEmpty else {
            statusMessage = "No images to export"
            return
        }

        // Create the destination folder
        let picturesFolder = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Pictures")
            .appendingPathComponent("Retro Screensavers")
            .appendingPathComponent(name)

        do {
            try FileManager.default.createDirectory(at: picturesFolder, withIntermediateDirectories: true)
        } catch {
            statusMessage = "Failed to create folder: \(error.localizedDescription)"
            return
        }

        isProcessing = true
        let savedUpscale = upscaleFactor
        upscaleFactor = scale

        DispatchQueue.global(qos: .userInitiated).async {
            var totalExported = 0

            for (index, item) in itemsToExport.enumerated() {
                DispatchQueue.main.async {
                    self.progressString = "Creating screensaver \(index + 1)/\(itemsToExport.count)"
                }

                let baseName = item.url.deletingPathExtension().lastPathComponent
                // Add index to ensure unique filenames
                let filename = "\(String(format: "%03d", index + 1))_\(baseName).png"
                let outputURL = picturesFolder.appendingPathComponent(filename)

                if self.saveImage(image: item.image, to: outputURL, format: .png, originalData: nil, originalExtension: "png") {
                    totalExported += 1
                }
            }

            DispatchQueue.main.async {
                self.upscaleFactor = savedUpscale
                self.isProcessing = false
                self.exportedCount += totalExported
                self.statusMessage = "Created screensaver '\(name)' with \(totalExported) images"
                self.progressString = ""

                // Open System Settings if requested
                if openSettings {
                    self.openScreenSaverSettings()
                }

                // Reveal in Finder
                NSWorkspace.shared.selectFile(nil, inFileViewerRootedAtPath: picturesFolder.path)
            }
        }
    }

    private func openScreenSaverSettings() {
        // In macOS Sonoma/Sequoia, Screen Saver is part of Wallpaper settings
        // Open using the 'open' command with the correct URL scheme
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/open")
        process.arguments = ["x-apple.systempreferences:com.apple.Wallpaper-Settings.extension"]
        try? process.run()
    }

    // MARK: - Movie Export

    func exportAsMovie(settings: MovieExportSettings) {
        // Determine which images to export
        var itemsToExport: [ImageItem] = []

        if !selectedImages.isEmpty {
            itemsToExport = imageItems.filter { selectedImages.contains($0.id) }
        } else if let current = selectedImage {
            itemsToExport = [current]
        } else {
            itemsToExport = imageItems
        }

        guard itemsToExport.count >= 2 else {
            // Show alert dialog for better visibility
            let alert = NSAlert()
            alert.messageText = "Not Enough Images"
            alert.informativeText = "You need at least 2 images to create a movie slideshow. Currently you have \(itemsToExport.count) image\(itemsToExport.count == 1 ? "" : "s") selected."
            alert.alertStyle = .warning
            alert.addButton(withTitle: "OK")
            alert.runModal()
            statusMessage = "Need at least 2 images to create a movie"
            return
        }

        // Show save panel
        let savePanel = NSSavePanel()
        savePanel.allowedContentTypes = settings.format == .mov ? [UTType.quickTimeMovie] : [UTType.mpeg4Movie]
        savePanel.nameFieldStringValue = "\(settings.name).\(settings.format.rawValue)"
        savePanel.canCreateDirectories = true

        guard savePanel.runModal() == .OK, let outputURL = savePanel.url else { return }

        isProcessing = true
        statusMessage = "Creating movie..."

        DispatchQueue.global(qos: .userInitiated).async {
            // Scale images
            let scaledImages = itemsToExport.compactMap { item -> CGImage? in
                guard let cgImage = item.image.cgImage(forProposedRect: nil, context: nil, hints: nil) else { return nil }
                let newSize = CGSize(width: cgImage.width * settings.scale, height: cgImage.height * settings.scale)
                return SHRDecoder.scaleCGImage(cgImage, to: newSize)
            }

            guard !scaledImages.isEmpty else {
                DispatchQueue.main.async {
                    self.isProcessing = false
                    self.statusMessage = "Failed to process images"
                }
                return
            }

            let success = self.createVideoFile(images: scaledImages, outputURL: outputURL, settings: settings)

            DispatchQueue.main.async {
                self.isProcessing = false
                if success {
                    self.statusMessage = "Movie saved: \(outputURL.lastPathComponent)"
                    NSWorkspace.shared.selectFile(outputURL.path, inFileViewerRootedAtPath: outputURL.deletingLastPathComponent().path)
                } else {
                    self.statusMessage = "Failed to create movie"
                }
            }
        }
    }

    private func createVideoFile(images: [CGImage], outputURL: URL, settings: MovieExportSettings) -> Bool {
        guard let firstImage = images.first else { return false }

        // Use target resolution size directly
        let outputSize = settings.resolution.size

        // Remove existing file
        try? FileManager.default.removeItem(at: outputURL)

        // Create asset writer
        guard let assetWriter = try? AVAssetWriter(outputURL: outputURL, fileType: settings.format == .mov ? .mov : .mp4) else {
            return false
        }

        // Select codec based on settings
        let codecType: AVVideoCodecType = settings.codec == .hevc ? .hevc : .h264
        var compressionProperties: [String: Any] = [
            AVVideoAverageBitRateKey: 10_000_000  // 10 Mbps
        ]

        // Add codec-specific settings
        if settings.codec == .hevc {
            compressionProperties[AVVideoProfileLevelKey] = kVTProfileLevel_HEVC_Main_AutoLevel
        } else {
            compressionProperties[AVVideoProfileLevelKey] = AVVideoProfileLevelH264HighAutoLevel
        }

        let videoSettings: [String: Any] = [
            AVVideoCodecKey: codecType,
            AVVideoWidthKey: Int(outputSize.width),
            AVVideoHeightKey: Int(outputSize.height),
            AVVideoCompressionPropertiesKey: compressionProperties
        ]

        let writerInput = AVAssetWriterInput(mediaType: .video, outputSettings: videoSettings)
        writerInput.expectsMediaDataInRealTime = false

        let sourceBufferAttributes: [String: Any] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Int(outputSize.width),
            kCVPixelBufferHeightKey as String: Int(outputSize.height)
        ]

        let adaptor = AVAssetWriterInputPixelBufferAdaptor(
            assetWriterInput: writerInput,
            sourcePixelBufferAttributes: sourceBufferAttributes
        )

        assetWriter.add(writerInput)

        guard assetWriter.startWriting() else {
            print("Failed to start writing: \(assetWriter.error?.localizedDescription ?? "unknown")")
            return false
        }
        assetWriter.startSession(atSourceTime: .zero)

        // Use 30fps for broad compatibility
        let fps: Int32 = 30
        let framesPerImage = Int(settings.duration * Double(fps))
        let transitionFrameCount = settings.transition != .none ? 15 : 0
        var frameNumber: Int64 = 0

        for (index, image) in images.enumerated() {
            // Write frames for this image's duration
            let holdFrames = max(1, framesPerImage - (index < images.count - 1 ? transitionFrameCount : 0))

            for _ in 0..<holdFrames {
                while !writerInput.isReadyForMoreMediaData {
                    Thread.sleep(forTimeInterval: 0.01)
                }

                if let pixelBuffer = createPixelBufferFromPool(adaptor: adaptor, image: image, size: outputSize) {
                    let presentationTime = CMTime(value: frameNumber, timescale: fps)
                    if !adaptor.append(pixelBuffer, withPresentationTime: presentationTime) {
                        print("Failed to append frame \(frameNumber)")
                    }
                    frameNumber += 1
                }
            }

            // Add transition to next image
            if settings.transition != .none && index < images.count - 1 {
                let nextImage = images[index + 1]
                // Pick a random transition for each image, or use the selected one
                let currentTransition = settings.transition == .random
                    ? TransitionType.randomTransition()
                    : settings.transition

                for t in 1...transitionFrameCount {
                    while !writerInput.isReadyForMoreMediaData {
                        Thread.sleep(forTimeInterval: 0.01)
                    }

                    let progress = CGFloat(t) / CGFloat(transitionFrameCount)
                    if let transitionImage = renderTransitionFrame(
                        from: image,
                        to: nextImage,
                        progress: progress,
                        transition: currentTransition,
                        size: outputSize
                    ),
                       let pixelBuffer = createPixelBufferFromPool(adaptor: adaptor, image: transitionImage, size: outputSize) {
                        let presentationTime = CMTime(value: frameNumber, timescale: fps)
                        adaptor.append(pixelBuffer, withPresentationTime: presentationTime)
                        frameNumber += 1
                    }
                }
            }

            DispatchQueue.main.async {
                self.progressString = "Processing image \(index + 1)/\(images.count)"
            }
        }

        writerInput.markAsFinished()

        let semaphore = DispatchSemaphore(value: 0)
        assetWriter.finishWriting {
            semaphore.signal()
        }
        semaphore.wait()

        DispatchQueue.main.async {
            self.progressString = ""
        }

        return assetWriter.status == .completed
    }

    private func createPixelBufferFromPool(adaptor: AVAssetWriterInputPixelBufferAdaptor, image: CGImage, size: CGSize) -> CVPixelBuffer? {
        guard let pool = adaptor.pixelBufferPool else { return nil }

        var pixelBuffer: CVPixelBuffer?
        let status = CVPixelBufferPoolCreatePixelBuffer(kCFAllocatorDefault, pool, &pixelBuffer)
        guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue
        ) else { return nil }

        // Fill with black background
        context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(origin: .zero, size: size))

        // Calculate centered position with aspect ratio preservation
        let imageSize = CGSize(width: image.width, height: image.height)
        let scale = min(size.width / imageSize.width, size.height / imageSize.height)
        let scaledSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let origin = CGPoint(
            x: (size.width - scaledSize.width) / 2,
            y: (size.height - scaledSize.height) / 2
        )

        context.interpolationQuality = .none  // Nearest neighbor for pixel art
        context.draw(image, in: CGRect(origin: origin, size: scaledSize))

        return buffer
    }

    private func createPixelBuffer(from image: CGImage, size: CGSize) -> CVPixelBuffer? {
        var pixelBuffer: CVPixelBuffer?
        let attrs: [String: Any] = [
            kCVPixelBufferCGImageCompatibilityKey as String: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey as String: true
        ]

        let status = CVPixelBufferCreate(
            kCFAllocatorDefault,
            Int(size.width),
            Int(size.height),
            kCVPixelFormatType_32ARGB,
            attrs as CFDictionary,
            &pixelBuffer
        )

        guard status == kCVReturnSuccess, let buffer = pixelBuffer else { return nil }

        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }

        guard let context = CGContext(
            data: CVPixelBufferGetBaseAddress(buffer),
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: CVPixelBufferGetBytesPerRow(buffer),
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.noneSkipFirst.rawValue
        ) else { return nil }

        // Fill with black background
        context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
        context.fill(CGRect(origin: .zero, size: size))

        // Calculate centered position
        let imageSize = CGSize(width: image.width, height: image.height)
        let scale = min(size.width / imageSize.width, size.height / imageSize.height)
        let scaledSize = CGSize(width: imageSize.width * scale, height: imageSize.height * scale)
        let origin = CGPoint(
            x: (size.width - scaledSize.width) / 2,
            y: (size.height - scaledSize.height) / 2
        )

        context.interpolationQuality = .none  // Nearest neighbor for pixel art
        context.draw(image, in: CGRect(origin: origin, size: scaledSize))

        return buffer
    }

    private func blendImages(_ image1: CGImage, _ image2: CGImage, alpha: CGFloat, size: CGSize) -> CGImage? {
        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.interpolationQuality = .none

        // Calculate centered positions for both images
        let image1Size = CGSize(width: image1.width, height: image1.height)
        let scale1 = min(size.width / image1Size.width, size.height / image1Size.height)
        let scaledSize1 = CGSize(width: image1Size.width * scale1, height: image1Size.height * scale1)
        let origin1 = CGPoint(x: (size.width - scaledSize1.width) / 2, y: (size.height - scaledSize1.height) / 2)

        let image2Size = CGSize(width: image2.width, height: image2.height)
        let scale2 = min(size.width / image2Size.width, size.height / image2Size.height)
        let scaledSize2 = CGSize(width: image2Size.width * scale2, height: image2Size.height * scale2)
        let origin2 = CGPoint(x: (size.width - scaledSize2.width) / 2, y: (size.height - scaledSize2.height) / 2)

        // Draw first image
        context.setAlpha(1 - alpha)
        context.draw(image1, in: CGRect(origin: origin1, size: scaledSize1))

        // Draw second image blended
        context.setAlpha(alpha)
        context.draw(image2, in: CGRect(origin: origin2, size: scaledSize2))

        return context.makeImage()
    }

    private func renderTransitionFrame(
        from image1: CGImage,
        to image2: CGImage,
        progress: CGFloat,
        transition: TransitionType,
        size: CGSize
    ) -> CGImage? {
        guard let context = CGContext(
            data: nil,
            width: Int(size.width),
            height: Int(size.height),
            bitsPerComponent: 8,
            bytesPerRow: 0,
            space: CGColorSpaceCreateDeviceRGB(),
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else { return nil }

        context.interpolationQuality = .none

        // Calculate centered positions for both images
        let image1Size = CGSize(width: image1.width, height: image1.height)
        let scale1 = min(size.width / image1Size.width, size.height / image1Size.height)
        let scaledSize1 = CGSize(width: image1Size.width * scale1, height: image1Size.height * scale1)
        let origin1 = CGPoint(x: (size.width - scaledSize1.width) / 2, y: (size.height - scaledSize1.height) / 2)

        let image2Size = CGSize(width: image2.width, height: image2.height)
        let scale2 = min(size.width / image2Size.width, size.height / image2Size.height)
        let scaledSize2 = CGSize(width: image2Size.width * scale2, height: image2Size.height * scale2)
        let origin2 = CGPoint(x: (size.width - scaledSize2.width) / 2, y: (size.height - scaledSize2.height) / 2)

        switch transition {
        case .none, .random:
            // .none should not happen, .random is resolved before calling this function
            // Fallback to crossfade
            context.setAlpha(1 - progress)
            context.draw(image1, in: CGRect(origin: origin1, size: scaledSize1))
            context.setAlpha(progress)
            context.draw(image2, in: CGRect(origin: origin2, size: scaledSize2))

        case .crossfade:
            // Draw first image fading out
            context.setAlpha(1 - progress)
            context.draw(image1, in: CGRect(origin: origin1, size: scaledSize1))
            // Draw second image fading in
            context.setAlpha(progress)
            context.draw(image2, in: CGRect(origin: origin2, size: scaledSize2))

        case .fadeBlack:
            // First half: fade to black
            // Second half: fade from black to new image
            if progress < 0.5 {
                let fadeOut = 1 - (progress * 2)
                context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
                context.fill(CGRect(origin: .zero, size: size))
                context.setAlpha(fadeOut)
                context.draw(image1, in: CGRect(origin: origin1, size: scaledSize1))
            } else {
                let fadeIn = (progress - 0.5) * 2
                context.setFillColor(CGColor(red: 0, green: 0, blue: 0, alpha: 1))
                context.fill(CGRect(origin: .zero, size: size))
                context.setAlpha(fadeIn)
                context.draw(image2, in: CGRect(origin: origin2, size: scaledSize2))
            }

        case .slideLeft:
            let offset = size.width * progress
            context.draw(image1, in: CGRect(x: origin1.x - offset, y: origin1.y, width: scaledSize1.width, height: scaledSize1.height))
            context.draw(image2, in: CGRect(x: origin2.x + size.width - offset, y: origin2.y, width: scaledSize2.width, height: scaledSize2.height))

        case .slideRight:
            let offset = size.width * progress
            context.draw(image1, in: CGRect(x: origin1.x + offset, y: origin1.y, width: scaledSize1.width, height: scaledSize1.height))
            context.draw(image2, in: CGRect(x: origin2.x - size.width + offset, y: origin2.y, width: scaledSize2.width, height: scaledSize2.height))

        case .slideUp:
            let offset = size.height * progress
            context.draw(image1, in: CGRect(x: origin1.x, y: origin1.y + offset, width: scaledSize1.width, height: scaledSize1.height))
            context.draw(image2, in: CGRect(x: origin2.x, y: origin2.y - size.height + offset, width: scaledSize2.width, height: scaledSize2.height))

        case .slideDown:
            let offset = size.height * progress
            context.draw(image1, in: CGRect(x: origin1.x, y: origin1.y - offset, width: scaledSize1.width, height: scaledSize1.height))
            context.draw(image2, in: CGRect(x: origin2.x, y: origin2.y + size.height - offset, width: scaledSize2.width, height: scaledSize2.height))

        case .wipeLeft:
            // Draw new image, then draw old image clipped from right
            context.draw(image2, in: CGRect(origin: origin2, size: scaledSize2))
            let clipWidth = size.width * (1 - progress)
            context.clip(to: CGRect(x: 0, y: 0, width: clipWidth, height: size.height))
            context.draw(image1, in: CGRect(origin: origin1, size: scaledSize1))

        case .wipeRight:
            // Draw new image, then draw old image clipped from left
            context.draw(image2, in: CGRect(origin: origin2, size: scaledSize2))
            let clipOffset = size.width * progress
            context.clip(to: CGRect(x: clipOffset, y: 0, width: size.width - clipOffset, height: size.height))
            context.draw(image1, in: CGRect(origin: origin1, size: scaledSize1))

        case .zoomIn:
            // Old image zooms in and fades out
            let zoomScale = 1.0 + (progress * 0.5)  // Zoom from 1x to 1.5x
            let zoomedSize1 = CGSize(width: scaledSize1.width * zoomScale, height: scaledSize1.height * zoomScale)
            let zoomedOrigin1 = CGPoint(
                x: (size.width - zoomedSize1.width) / 2,
                y: (size.height - zoomedSize1.height) / 2
            )
            context.setAlpha(1 - progress)
            context.draw(image1, in: CGRect(origin: zoomedOrigin1, size: zoomedSize1))
            context.setAlpha(progress)
            context.draw(image2, in: CGRect(origin: origin2, size: scaledSize2))

        case .zoomOut:
            // Old image shrinks and fades out
            let zoomScale = 1.0 - (progress * 0.5)  // Shrink from 1x to 0.5x
            let zoomedSize1 = CGSize(width: scaledSize1.width * zoomScale, height: scaledSize1.height * zoomScale)
            let zoomedOrigin1 = CGPoint(
                x: (size.width - zoomedSize1.width) / 2,
                y: (size.height - zoomedSize1.height) / 2
            )
            context.setAlpha(1 - progress)
            context.draw(image1, in: CGRect(origin: zoomedOrigin1, size: zoomedSize1))
            context.setAlpha(progress)
            context.draw(image2, in: CGRect(origin: origin2, size: scaledSize2))
        }

        return context.makeImage()
    }

    // MARK: - File Handling
    
    func importCatalogEntries(_ entries: [DiskCatalogEntry]) {
        DispatchQueue.global(qos: .userInitiated).async {
            var newItems: [ImageItem] = []
            for entry in entries {
                // Check if the entry already has a specific platform type (e.g., AmstradCPC from DSK reader)
                var finalType: AppleIIImageType = entry.imageType
                var cgImage: CGImage? = nil

                // For AmstradCPC types, use the CPC decoder directly to preserve the type
                if case .AmstradCPC = entry.imageType {
                    let cpcResult = RetroDecoder.decodeAmstradCPC(data: entry.data)
                    cgImage = cpcResult.image
                    if cpcResult.image != nil {
                        finalType = cpcResult.type  // Use detailed CPC type from decoder
                    }
                } else if case .MSX = entry.imageType {
                    // For MSX types, use MSXDecoder directly with original filename
                    let msxResult = MSXDecoder.decode(data: entry.data, filename: entry.name)
                    cgImage = msxResult.image
                    if msxResult.image != nil {
                        finalType = msxResult.type
                    }
                } else {
                    // Use original name for non-Apple II formats (fileType 0) to preserve extension,
                    // but nameWithTypeInfo for ProDOS files to pass file type info
                    let filename = entry.fileType == 0 ? entry.name : entry.nameWithTypeInfo
                    let decodeResult = SHRDecoder.decode(data: entry.data, filename: filename)
                    cgImage = decodeResult.image
                    finalType = decodeResult.type
                }

                if entry.isImage, let image = cgImage {
                    let url = URL(fileURLWithPath: "/catalog/\(entry.name)")
                    let nsImage = NSImage(cgImage: image, size: NSSize(width: image.width, height: image.height))
                    // Extract palette info
                    let paletteInfo = PaletteExtractor.extractPalette(from: entry.data, type: finalType, filename: entry.name)
                    newItems.append(ImageItem(url: url, image: nsImage, type: finalType, originalData: entry.data, paletteInfo: paletteInfo))
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
                removedCount += 1
                statusMessage = "Image deleted."
            }
        } else {
            let count = selectedImages.count
            imageItems.removeAll { selectedImages.contains($0.id) }
            selectedImages.removeAll()
            if let current = selectedImage, !imageItems.contains(where: { $0.id == current.id }) { selectedImage = imageItems.first }
            if imageItems.isEmpty { selectedImage = nil; showBrowser = false }
            removedCount += count
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
                    let fileExtension = self.selectedExportFormat == .original ? item.originalFileExtension : self.selectedExportFormat.fileExtension
                    let filename = "\(newName).\(fileExtension)"
                    if self.saveImage(image: item.image, to: outputFolderURL.appendingPathComponent(filename), format: self.selectedExportFormat, originalData: item.originalData, originalExtension: item.originalFileExtension) { successCount += 1 }
                }
                DispatchQueue.main.async { self.isProcessing = false; self.statusMessage = "Exported \(successCount) of \(self.imageItems.count) image(s) with custom names"; self.progressString = "" }
            }
        }
    }
    
    func openFiles() {
        let openPanel = NSOpenPanel()
        openPanel.allowsOtherFileTypes = true; openPanel.allowsMultipleSelection = true; openPanel.canChooseDirectories = true; openPanel.canChooseFiles = true
        openPanel.prompt = "Open Files or Folders"
        openPanel.allowedContentTypes = [.png, .jpeg, .gif, .bmp, .tiff, .pcx, .shr, .pic, .pnt, .scr, .twoimg, .dsk, .hdv, .do_disk, .po, .st, .data]
        if openPanel.runModal() == .OK {
            // Add folders to recent folders
            for url in openPanel.urls {
                var isDirectory: ObjCBool = false
                if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory), isDirectory.boolValue {
                    appState.addRecentFolder(url)
                }
            }
            processFilesAndFolders(urls: openPanel.urls)
        }
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
                    
                    // Check for disk images by file extension only
                    let possibleDiskImage = !isModernImage && (
                        fileName.lowercased().hasSuffix(".po") ||
                        fileName.lowercased().hasSuffix(".do") ||
                        fileName.lowercased().hasSuffix(".dsk") ||
                        fileName.lowercased().hasSuffix(".2mg") ||
                        fileName.lowercased().hasSuffix(".hdv") ||
                        fileName.lowercased().hasSuffix(".img") ||
                        fileName.lowercased().hasSuffix(".d64") ||
                        fileName.lowercased().hasSuffix(".d71") ||
                        fileName.lowercased().hasSuffix(".d81") ||
                        fileName.lowercased().hasSuffix(".adf") ||
                        fileName.lowercased().hasSuffix(".st") ||
                        fileName.lowercased().hasSuffix(".atr")
                    )
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
                            let paletteInfo = PaletteExtractor.extractPalette(from: data, type: result.type, filename: fileName)
                            newItems.append(ImageItem(url: fileURL, image: nsImage, type: result.type, originalData: data, paletteInfo: paletteInfo)); successCount += 1
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
                if fileExtension == "2mg" || fileExtension == "dsk" || fileExtension == "hdv" || fileExtension == "po" || fileExtension == "do" || fileExtension == "img" || fileExtension == "d64" || fileExtension == "d71" || fileExtension == "d81" || fileExtension == "adf" || fileExtension == "st" || fileExtension == "atr" {
                    if let catalog = DiskImageReader.readDiskCatalog(data: data, filename: url.lastPathComponent) {
                        DispatchQueue.main.async { self.currentCatalog = catalog; self.showCatalogBrowser = true; self.isProcessing = false }
                        continue
                    }
                    for diskFile in DiskImageReader.readDiskImage(data: data) {
                        if let cgImage = SHRDecoder.decode(data: diskFile.data, filename: diskFile.name).image {
                            let virtualURL = url.appendingPathComponent(diskFile.name)
                            let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                            let paletteInfo = PaletteExtractor.extractPalette(from: diskFile.data, type: diskFile.type, filename: diskFile.name)
                            newItems.append(ImageItem(url: virtualURL, image: nsImage, type: diskFile.type, originalData: diskFile.data, paletteInfo: paletteInfo)); successCount += 1
                        }
                    }
                } else {
                    let result = SHRDecoder.decode(data: data, filename: url.lastPathComponent)
                    if let cgImage = result.image, result.type != .Unknown {
                        let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                        let paletteInfo = PaletteExtractor.extractPalette(from: data, type: result.type, filename: url.lastPathComponent)
                        newItems.append(ImageItem(url: url, image: nsImage, type: result.type, originalData: data, paletteInfo: paletteInfo)); successCount += 1
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
        let fileExtension = selectedExportFormat == .original ? item.originalFileExtension : selectedExportFormat.fileExtension
        savePanel.allowedContentTypes = [UTType(filenameExtension: fileExtension)!]
        savePanel.nameFieldStringValue = "\(item.url.deletingPathExtension().lastPathComponent).\(fileExtension)"
        savePanel.prompt = "Export"; savePanel.canCreateDirectories = true
        savePanel.begin { response in
            if response == .OK, let outputURL = savePanel.url {
                self.isProcessing = true
                DispatchQueue.global(qos: .userInitiated).async {
                    let success = self.saveImage(image: item.image, to: outputURL, format: self.selectedExportFormat, originalData: item.originalData, originalExtension: item.originalFileExtension)
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
                        let fileExtension = self.selectedExportFormat == .original ? item.originalFileExtension : self.selectedExportFormat.fileExtension
                        let filename = "\(item.url.deletingPathExtension().lastPathComponent).\(fileExtension)"
                        if self.saveImage(image: item.image, to: outputFolderURL.appendingPathComponent(filename), format: self.selectedExportFormat, originalData: item.originalData, originalExtension: item.originalFileExtension) { successCount += 1 }
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
                    let fileExtension = self.selectedExportFormat == .original ? item.originalFileExtension : self.selectedExportFormat.fileExtension
                    let filename = "\(item.url.deletingPathExtension().lastPathComponent).\(fileExtension)"
                    if self.saveImage(image: item.image, to: outputFolderURL.appendingPathComponent(filename), format: self.selectedExportFormat, originalData: item.originalData, originalExtension: item.originalFileExtension) { successCount += 1 }
                }
                DispatchQueue.main.async { self.isProcessing = false; self.statusMessage = "Exported \(successCount) of \(self.imageItems.count) image(s)"; self.progressString = "" }
            }
        }
    }
    
    func saveImage(image: NSImage, to outputURL: URL, format: ExportFormat, originalData: Data? = nil, originalExtension: String = "bin") -> Bool {
        // Bei "Original" Format die Original-Daten direkt speichern
        if format == .original {
            guard let data = originalData else {
                // Keine Original-Daten verfügbar - kann nicht exportieren
                DispatchQueue.main.async {
                    let alert = NSAlert()
                    alert.messageText = "Original data not available"
                    alert.informativeText = "This image was loaded without preserving the original data. Please select a different export format."
                    alert.alertStyle = .warning
                    alert.addButton(withTitle: "OK")
                    alert.runModal()
                }
                return false
            }
            do {
                try data.write(to: outputURL)
                return true
            } catch {
                return false
            }
        }
        
        // Für andere Formate: Bild konvertieren
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
        case .original:
            return false // wird oben behandelt
        }
        guard let finalData = outputData else { return false }
        do { try finalData.write(to: outputURL); return true } catch { return false }
    }
    
    // MARK: - Crop Tool Functions
    
    func toggleCropMode() {
        cropMode.toggle()
        if !cropMode {
            clearSelection()
            NSCursor.pop() // Reset cursor when exiting crop mode
        }
    }
    
    func clearSelection() {
        cropStart = nil
        cropEnd = nil
    }
    
    func handleCropDrag(value: DragGesture.Value, imageSize: CGSize, scale: CGFloat) {
        // Get coordinates relative to the image
        let location = value.location
        let startLocation = value.startLocation

        // Store the scale being used for this crop selection
        cropScale = scale

        // Clamp to image bounds using the actual display scale
        func clamp(_ point: CGPoint) -> CGPoint {
            CGPoint(
                x: max(0, min(point.x, imageSize.width * scale)),
                y: max(0, min(point.y, imageSize.height * scale))
            )
        }

        if cropStart == nil {
            cropStart = clamp(startLocation)
        }
        cropEnd = clamp(location)
    }
    
    func copySelectedArea() {
        guard let selectedImg = selectedImage,
              let start = cropStart,
              let end = cropEnd else { return }
        
        if let cropped = cropImageToRect(image: selectedImg.image, start: start, end: end) {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.writeObjects([cropped])
            statusMessage = "Selection copied to clipboard (\(Int(cropped.size.width))×\(Int(cropped.size.height)))"
        }
    }
    
    func cropToSelection() {
        guard let selectedImg = selectedImage,
              let start = cropStart,
              let end = cropEnd else { 
            return 
        }
        
        if let cropped = cropImageToRect(image: selectedImg.image, start: start, end: end) {
            // Replace image in list
            if let index = imageItems.firstIndex(where: { $0.id == selectedImg.id }) {
                guard let cgImage = cropped.cgImage(forProposedRect: nil, context: nil, hints: nil) else { 
                    return 
                }
                
                // Save current state to undo stack
                let undoItem = (
                    id: selectedImg.id,
                    image: selectedImg.image,
                    type: selectedImg.type,
                    data: selectedImg.originalData,
                    paletteInfo: selectedImg.paletteInfo,
                    modifiedPalette: selectedImg.modifiedPalette,
                    hasImageModification: selectedImg.hasImageModification
                )
                undoStack.append(undoItem)
                
                // Limit undo stack to 10 items
                if undoStack.count > 10 {
                    undoStack.removeFirst()
                }
                
                // Update undo availability
                appState.setCanUndo(true)
                
                let newImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))

                // Behalte die gleiche ID bei! Preserve originalData for Original toggle
                var croppedItem = ImageItem(
                    id: selectedImg.id,
                    url: selectedImg.url,
                    image: newImage,
                    type: selectedImg.type,
                    originalData: selectedImg.originalData,  // Preserve original data
                    paletteInfo: selectedImg.paletteInfo,
                    hasImageModification: true  // Mark as modified
                )
                croppedItem.modifiedPalette = selectedImg.modifiedPalette
                imageItems[index] = croppedItem
                
                selectedImage = imageItems[index]
                statusMessage = "Image cropped to \(Int(cropped.size.width))×\(Int(cropped.size.height)) (⌘Z to undo)"
                
                // Exit crop mode
                cropMode = false
                clearSelection()
            }
        }
    }
    
    func undoLastAction() {
        guard let lastAction = undoStack.popLast() else {
            statusMessage = "Nothing to undo"
            return
        }

        // Find and restore the image
        if let index = imageItems.firstIndex(where: { $0.id == lastAction.id }) {
            // Behalte die gleiche ID bei!
            var restoredItem = ImageItem(
                id: lastAction.id,
                url: imageItems[index].url,
                image: lastAction.image,
                type: lastAction.type,
                originalData: lastAction.data,
                paletteInfo: lastAction.paletteInfo,
                hasImageModification: lastAction.hasImageModification
            )
            restoredItem.modifiedPalette = lastAction.modifiedPalette
            imageItems[index] = restoredItem

            selectedImage = imageItems[index]
            statusMessage = "Undo successful"

            // Update undo availability
            appState.setCanUndo(!undoStack.isEmpty)
        }
    }

    func rotateSelectedImage(clockwise: Bool) {
        guard let current = selectedImage,
              let index = imageItems.firstIndex(where: { $0.id == current.id }) else {
            return
        }

        // Save to undo stack before rotating
        let undoItem = (
            id: current.id,
            image: current.image,
            type: current.type,
            data: current.originalData,
            paletteInfo: current.paletteInfo,
            modifiedPalette: current.modifiedPalette,
            hasImageModification: current.hasImageModification
        )
        undoStack.append(undoItem)

        // Limit undo stack to 10 items
        if undoStack.count > 10 {
            undoStack.removeFirst()
        }

        appState.setCanUndo(true)

        // Rotate the image
        guard let rotatedImage = rotateImage(current.image, clockwise: clockwise) else {
            return
        }

        // Update the image item - preserve originalData for Original toggle
        var updatedItem = ImageItem(
            id: current.id,
            url: current.url,
            image: rotatedImage,
            type: current.type,
            originalData: current.originalData,  // Preserve original data
            paletteInfo: current.paletteInfo,
            hasImageModification: true  // Mark as modified
        )
        updatedItem.modifiedPalette = current.modifiedPalette
        imageItems[index] = updatedItem
        selectedImage = updatedItem

        statusMessage = clockwise ? "Rotated right 90°" : "Rotated left 90°"
    }

    private func rotateImage(_ image: NSImage, clockwise: Bool) -> NSImage? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let width = cgImage.width
        let height = cgImage.height

        // Create a new bitmap context with swapped dimensions
        guard let colorSpace = cgImage.colorSpace,
              let context = CGContext(
                data: nil,
                width: height,
                height: width,
                bitsPerComponent: cgImage.bitsPerComponent,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: cgImage.bitmapInfo.rawValue
              ) else {
            return nil
        }

        // Apply rotation transform
        if clockwise {
            // Rotate 90° clockwise
            context.translateBy(x: CGFloat(height), y: 0)
            context.rotate(by: .pi / 2)
        } else {
            // Rotate 90° counter-clockwise
            context.translateBy(x: 0, y: CGFloat(width))
            context.rotate(by: -.pi / 2)
        }

        // Draw the original image
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Create the rotated image
        guard let rotatedCGImage = context.makeImage() else {
            return nil
        }

        return NSImage(cgImage: rotatedCGImage, size: NSSize(width: height, height: width))
    }

    func flipSelectedImage(horizontal: Bool) {
        guard let current = selectedImage,
              let index = imageItems.firstIndex(where: { $0.id == current.id }) else {
            return
        }

        // Save to undo stack before flipping
        let undoItem = (
            id: current.id,
            image: current.image,
            type: current.type,
            data: current.originalData,
            paletteInfo: current.paletteInfo,
            modifiedPalette: current.modifiedPalette,
            hasImageModification: current.hasImageModification
        )
        undoStack.append(undoItem)

        // Limit undo stack to 10 items
        if undoStack.count > 10 {
            undoStack.removeFirst()
        }

        appState.setCanUndo(true)

        // Flip the image
        guard let flippedImage = flipImage(current.image, horizontal: horizontal) else {
            return
        }

        // Update the image item - preserve originalData for Original toggle
        var updatedItem = ImageItem(
            id: current.id,
            url: current.url,
            image: flippedImage,
            type: current.type,
            originalData: current.originalData,  // Preserve original data
            paletteInfo: current.paletteInfo,
            hasImageModification: true  // Mark as modified
        )
        updatedItem.modifiedPalette = current.modifiedPalette
        imageItems[index] = updatedItem
        selectedImage = updatedItem

        statusMessage = horizontal ? "Flipped horizontally" : "Flipped vertically"
    }

    private func flipImage(_ image: NSImage, horizontal: Bool) -> NSImage? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let width = cgImage.width
        let height = cgImage.height

        // Create a new bitmap context
        guard let colorSpace = cgImage.colorSpace,
              let context = CGContext(
                data: nil,
                width: width,
                height: height,
                bitsPerComponent: cgImage.bitsPerComponent,
                bytesPerRow: 0,
                space: colorSpace,
                bitmapInfo: cgImage.bitmapInfo.rawValue
              ) else {
            return nil
        }

        // Apply flip transform
        if horizontal {
            // Flip horizontally
            context.translateBy(x: CGFloat(width), y: 0)
            context.scaleBy(x: -1, y: 1)
        } else {
            // Flip vertically
            context.translateBy(x: 0, y: CGFloat(height))
            context.scaleBy(x: 1, y: -1)
        }

        // Draw the original image
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Create the flipped image
        guard let flippedCGImage = context.makeImage() else {
            return nil
        }

        return NSImage(cgImage: flippedCGImage, size: NSSize(width: width, height: height))
    }

    // MARK: - Batch Transform Support

    enum TransformType {
        case rotateLeft
        case rotateRight
        case flipHorizontal
        case flipVertical
        case invert
    }

    func transformImages(transform: TransformType) {
        // Determine which images to transform
        var itemsToTransform: [ImageItem] = []

        if !selectedImages.isEmpty {
            // Batch mode: transform all selected images
            itemsToTransform = imageItems.filter { selectedImages.contains($0.id) }
        } else if let current = selectedImage {
            // Single mode: transform current image
            itemsToTransform = [current]
        }

        guard !itemsToTransform.isEmpty else { return }

        for item in itemsToTransform {
            guard let index = imageItems.firstIndex(where: { $0.id == item.id }) else { continue }

            // Save to undo stack before transforming
            let undoItem = (
                id: item.id,
                image: item.image,
                type: item.type,
                data: item.originalData,
                paletteInfo: item.paletteInfo,
                modifiedPalette: item.modifiedPalette,
                hasImageModification: item.hasImageModification
            )
            undoStack.append(undoItem)

            // Apply the transform
            var transformedImage: NSImage?
            switch transform {
            case .rotateLeft:
                transformedImage = rotateImage(item.image, clockwise: false)
            case .rotateRight:
                transformedImage = rotateImage(item.image, clockwise: true)
            case .flipHorizontal:
                transformedImage = flipImage(item.image, horizontal: true)
            case .flipVertical:
                transformedImage = flipImage(item.image, horizontal: false)
            case .invert:
                transformedImage = invertImage(item.image)
            }

            guard let newImage = transformedImage else { continue }

            // Update the image item - preserve originalData so Original toggle works
            var updatedItem = ImageItem(
                id: item.id,
                url: item.url,
                image: newImage,
                type: item.type,
                originalData: item.originalData,  // Preserve original data for Original toggle
                paletteInfo: item.paletteInfo,
                hasImageModification: true  // Mark as modified
            )
            updatedItem.modifiedPalette = item.modifiedPalette
            imageItems[index] = updatedItem

            // Update selected image if it was the one transformed
            if selectedImage?.id == item.id {
                selectedImage = updatedItem
            }
        }

        // Limit undo stack to 10 items
        while undoStack.count > 10 {
            undoStack.removeFirst()
        }

        appState.setCanUndo(true)

        // Status message
        let transformName: String
        switch transform {
        case .rotateLeft: transformName = "Rotated left"
        case .rotateRight: transformName = "Rotated right"
        case .flipHorizontal: transformName = "Flipped horizontally"
        case .flipVertical: transformName = "Flipped vertically"
        case .invert: transformName = "Inverted colors"
        }

        if itemsToTransform.count > 1 {
            statusMessage = "\(transformName) \(itemsToTransform.count) images (⌘Z to undo)"
        } else {
            statusMessage = "\(transformName) (⌘Z to undo)"
        }
    }

    private func invertImage(_ image: NSImage) -> NSImage? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let width = cgImage.width
        let height = cgImage.height

        // Create a new bitmap context with RGBA format for inversion
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        guard let context = CGContext(
            data: nil,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return nil
        }

        // Draw the original image
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Get the pixel data
        guard let data = context.data else { return nil }
        let pixels = data.bindMemory(to: UInt8.self, capacity: width * height * 4)

        // Invert each pixel (but not alpha)
        for i in 0..<(width * height) {
            let offset = i * 4
            pixels[offset] = 255 - pixels[offset]         // R
            pixels[offset + 1] = 255 - pixels[offset + 1] // G
            pixels[offset + 2] = 255 - pixels[offset + 2] // B
            // Alpha (offset + 3) stays the same
        }

        // Create the inverted image
        guard let invertedCGImage = context.makeImage() else {
            return nil
        }

        return NSImage(cgImage: invertedCGImage, size: NSSize(width: width, height: height))
    }

    func copyImageToClipboard() {
        guard let current = selectedImage else {
            statusMessage = "No image selected"
            return
        }

        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects([current.image])

        statusMessage = "Image copied to clipboard (\(Int(current.image.size.width))×\(Int(current.image.size.height)))"
    }

    // MARK: - Adjustments

    func applyAdjustments() {
        guard let current = selectedImage,
              !currentAdjustments.isIdentity else {
            previewAdjustments = nil
            return
        }

        // Push current state to undo stack
        undoStack.append((
            id: current.id,
            image: current.image,
            type: current.type,
            data: current.originalData,
            paletteInfo: current.paletteInfo,
            modifiedPalette: current.modifiedPalette,
            hasImageModification: current.hasImageModification
        ))

        // Apply adjustments
        if let adjustedImage = current.image.adjustedImage(
            brightness: currentAdjustments.brightness,
            contrast: currentAdjustments.contrast
        ) {
            // Update the image item - preserve originalData so Original toggle works
            if let index = imageItems.firstIndex(where: { $0.id == current.id }) {
                var newItem = ImageItem(
                    id: current.id,
                    url: current.url,
                    image: adjustedImage,
                    type: current.type,
                    originalData: current.originalData,  // Preserve original data for Original toggle
                    paletteInfo: current.paletteInfo,
                    hasImageModification: true  // Mark as modified
                )
                newItem.modifiedPalette = current.modifiedPalette
                imageItems[index] = newItem
                selectedImage = imageItems[index]
            }
            statusMessage = "Adjustments applied"
        }

        // Reset state
        previewAdjustments = nil
        currentAdjustments = ImageAdjustments()
    }

    func resetAdjustmentsPreview() {
        previewAdjustments = nil
        currentAdjustments = ImageAdjustments()
    }

    func cropImageToRect(image: NSImage, start: CGPoint, end: CGPoint) -> NSImage? {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        // Convert from view coordinates to image coordinates using the stored crop scale
        let scale = cropScale > 0 ? cropScale : 1.0
        let x1 = min(start.x, end.x) / scale
        let y1 = min(start.y, end.y) / scale
        let x2 = max(start.x, end.x) / scale
        let y2 = max(start.y, end.y) / scale

        let cropRect = CGRect(
            x: x1,
            y: y1,
            width: x2 - x1,
            height: y2 - y1
        )

        guard let croppedCGImage = cgImage.cropping(to: cropRect) else {
            return nil
        }

        return NSImage(cgImage: croppedCGImage, size: NSSize(
            width: croppedCGImage.width,
            height: croppedCGImage.height
        ))
    }
}

// MARK: - Crop Overlay View

struct CropOverlayView: View {
    let imageSize: CGSize
    let imageScale: CGFloat
    @Binding var cropStart: CGPoint?
    @Binding var cropEnd: CGPoint?
    
    var selectionRect: CGRect? {
        guard let start = cropStart, let end = cropEnd else { return nil }
        return CGRect(
            x: min(start.x, end.x),
            y: min(start.y, end.y),
            width: abs(end.x - start.x),
            height: abs(end.y - start.y)
        )
    }
    
    var body: some View {
        ZStack {
            if let rect = selectionRect {
                // Dimmed area outside selection
                GeometryReader { geo in
                    Path { path in
                        path.addRect(CGRect(origin: .zero, size: geo.size))
                        path.addRect(rect)
                    }
                    .fill(style: FillStyle(eoFill: true))
                    .foregroundColor(Color.black.opacity(0.5))
                }
                
                // Selection border
                Rectangle()
                    .stroke(Color.white, lineWidth: 2)
                    .frame(width: rect.width, height: rect.height)
                    .position(x: rect.midX, y: rect.midY)
                
                // Selection info with better contrast
                let pixelWidth = Int(rect.width / imageScale)
                let pixelHeight = Int(rect.height / imageScale)
                Text("\(pixelWidth)×\(pixelHeight)")
                    .font(.system(.caption, design: .monospaced))
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.black.opacity(0.85))
                            .overlay(
                                RoundedRectangle(cornerRadius: 4)
                                    .stroke(Color.white.opacity(0.5), lineWidth: 1)
                            )
                    )
                    .position(x: rect.midX, y: rect.minY - 18)
                
                // Corner handles
                ForEach(0..<4, id: \.self) { corner in
                    Circle()
                        .fill(Color.white)
                        .frame(width: 8, height: 8)
                        .overlay(Circle().stroke(Color.black, lineWidth: 1))
                        .position(
                            x: corner % 2 == 0 ? rect.minX : rect.maxX,
                            y: corner < 2 ? rect.minY : rect.maxY
                        )
                }
            } else {
                Text("Drag to select area")
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.black.opacity(0.85))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.white.opacity(0.5), lineWidth: 1)
                            )
                    )
            }
        }
    }
}

// MARK: - Scanline Tracking Overlay

struct ScanlineTrackingOverlay: NSViewRepresentable {
    let imageSize: CGSize
    let imageScale: CGFloat
    let paletteCount: Int
    @Binding var currentScanline: Int?

    func makeNSView(context: Context) -> ScanlineTrackingNSView {
        let view = ScanlineTrackingNSView()
        view.imageSize = imageSize
        view.imageScale = imageScale
        view.paletteCount = paletteCount
        view.onScanlineChanged = { scanline in
            DispatchQueue.main.async {
                self.currentScanline = scanline
            }
        }
        return view
    }

    func updateNSView(_ nsView: ScanlineTrackingNSView, context: Context) {
        nsView.imageSize = imageSize
        nsView.imageScale = imageScale
        nsView.paletteCount = paletteCount
    }
}

class ScanlineTrackingNSView: NSView {
    var imageSize: CGSize = .zero
    var imageScale: CGFloat = 1.0
    var paletteCount: Int = 200
    var onScanlineChanged: ((Int) -> Void)?

    private var trackingArea: NSTrackingArea?
    private var currentLine: Int = -1

    override func updateTrackingAreas() {
        super.updateTrackingAreas()

        if let existing = trackingArea {
            removeTrackingArea(existing)
        }

        trackingArea = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }

    override func mouseMoved(with event: NSEvent) {
        let location = convert(event.locationInWindow, from: nil)

        // Calculate scanline based on Y position
        // Note: NSView coordinates have origin at bottom-left, so we flip
        let flippedY = bounds.height - location.y
        let imageY = flippedY / imageScale

        // Clamp to valid range
        let scanline = max(0, min(paletteCount - 1, Int(imageY)))

        if scanline != currentLine {
            currentLine = scanline
            onScanlineChanged?(scanline)
        }
    }

    override func mouseExited(with event: NSEvent) {
        // Keep the last scanline when mouse exits (don't reset)
    }
}


