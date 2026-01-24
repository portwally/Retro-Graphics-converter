import SwiftUI

// MARK: - Help View

struct HelpView: View {
    @Environment(\.dismiss) private var dismiss
    var initialSection: HelpSection = .gettingStarted
    @State private var selectedSection: HelpSection = .gettingStarted

    var body: some View {
        NavigationSplitView {
            List(HelpSection.allCases, selection: $selectedSection) { section in
                Label(section.title, systemImage: section.icon)
                    .tag(section)
            }
            .listStyle(.sidebar)
            .frame(minWidth: 200)
        } detail: {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    helpContent(for: selectedSection)
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(minWidth: 800, minHeight: 600)
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Done") {
                    dismiss()
                }
            }
        }
        .onAppear {
            selectedSection = initialSection
        }
    }

    @ViewBuilder
    private func helpContent(for section: HelpSection) -> some View {
        switch section {
        case .gettingStarted:
            gettingStartedContent
        case .importingImages:
            importingImagesContent
        case .browsingImages:
            browsingImagesContent
        case .imageTools:
            imageToolsContent
        case .paletteEditing:
            paletteEditingContent
        case .exportingImages:
            exportingImagesContent
        case .supportedFormats:
            supportedFormatsContent
        case .keyboardShortcuts:
            keyboardShortcutsContent
        case .troubleshooting:
            troubleshootingContent
        }
    }

    // MARK: - Getting Started

    private var gettingStartedContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Getting Started")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Retro Graphics Converter is a powerful tool for viewing, editing, and converting vintage computer graphics from platforms like the Apple II, Apple IIgs, Commodore 64, Amiga, Atari ST, MSX, BBC Micro, TRS-80/CoCo, and more.")
                .font(.body)

            Divider()

            HelpSectionHeader(title: "Quick Start", icon: "bolt.fill")

            NumberedStep(number: 1, title: "Import Images", description: "Click the Import button or drag and drop image files or disk images into the window.")

            NumberedStep(number: 2, title: "Browse & Select", description: "Use the sidebar to browse imported images. Click to select, or use Select All.")

            NumberedStep(number: 3, title: "Preview & Edit", description: "View images in the preview area. Edit palette colors by clicking on them.")

            NumberedStep(number: 4, title: "Export", description: "Click Export to save images in modern formats (PNG, JPEG, etc.) with optional scaling.")

            Divider()

            HelpSectionHeader(title: "Interface Overview", icon: "rectangle.3.group")

            BulletPoint(text: "**Toolbar** - Import/Export, zoom, rotate, flip, crop, and undo tools")
            BulletPoint(text: "**Sidebar** - Thumbnail browser with selection controls")
            BulletPoint(text: "**Preview Area** - Large view of selected image with checkerboard background")
            BulletPoint(text: "**Info Bar** - File information and palette display")
            BulletPoint(text: "**Status Bar** - Counts for imported, selected, removed, and exported files")
        }
    }

    // MARK: - Importing Images

    private var importingImagesContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Importing Images")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("There are several ways to import retro graphics into the application.")
                .font(.body)

            Divider()

            HelpSectionHeader(title: "Import Methods", icon: "square.and.arrow.down")

            BulletPoint(text: "**Import Button** - Click to open a file picker dialog")
            BulletPoint(text: "**Drag & Drop** - Drag files directly onto the window")
            BulletPoint(text: "**Keyboard** - Press Cmd+O to open the import dialog")

            Divider()

            HelpSectionHeader(title: "Supported Input Types", icon: "doc.richtext")

            BulletPoint(text: "**Individual image files** - SHR, HGR, DHGR, IFF, Degas, PCX, BMP, etc.")
            BulletPoint(text: "**Apple II disk images** - .dsk, .do, .po, .2mg, .hdv containing multiple images")
            BulletPoint(text: "**C64 disk images** - .d64, .d71, .d81 (1541/1571/1581 floppy disks)")
            BulletPoint(text: "**ProDOS volumes** - PNT and PIC files are automatically detected")
            BulletPoint(text: "**DOS 3.3 disks** - Binary graphics files")

            Divider()

            HelpSectionHeader(title: "Disk Image Browser", icon: "externaldrive")

            Text("When you open a disk image, a catalog browser appears showing all recognized graphics files. You can:")
                .font(.body)

            BulletPoint(text: "Double-click files to import them individually")
            BulletPoint(text: "Use Select All to select all images")
            BulletPoint(text: "Import selected files with the Import button")
        }
    }

    // MARK: - Browsing Images

    private var browsingImagesContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Browsing Images")
                .font(.largeTitle)
                .fontWeight(.bold)

            Divider()

            HelpSectionHeader(title: "Thumbnail Browser", icon: "photo.on.rectangle")

            Text("The sidebar shows thumbnails of all imported images with file names and format information.")
                .font(.body)

            BulletPoint(text: "**Click** - Select a single image")
            BulletPoint(text: "**Cmd+Click** - Add/remove from selection")
            BulletPoint(text: "**Shift+Click** - Select a range")
            BulletPoint(text: "**Select All** - Select all images in the browser")

            Divider()

            HelpSectionHeader(title: "Preview Controls", icon: "magnifyingglass")

            BulletPoint(text: "**Zoom In/Out** - Use the + and - buttons or scroll wheel")
            BulletPoint(text: "**Fit to Window** - Auto-scale image to fit the preview area")
            BulletPoint(text: "**Zoom Percentage** - Shows current zoom level")

            Divider()

            HelpSectionHeader(title: "Crop Tool", icon: "crop")

            Text("The crop tool allows you to select a region of the image:")
                .font(.body)

            NumberedStep(number: 1, title: "Activate", description: "Click the crop button in the toolbar")
            NumberedStep(number: 2, title: "Select Region", description: "Click and drag to select the area to keep")
            NumberedStep(number: 3, title: "Apply", description: "The crop is applied automatically")
            NumberedStep(number: 4, title: "Undo", description: "Press Cmd+Z or click Undo to revert")

            Divider()

            HelpSectionHeader(title: "Removing Images", icon: "trash")

            BulletPoint(text: "Select images and press Delete to remove them from the browser")
            BulletPoint(text: "This does not delete the original files")
        }
    }

    // MARK: - Image Tools

    private var imageToolsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Image Tools")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("The toolbar provides powerful tools for transforming and editing your images.")
                .font(.body)

            Divider()

            HelpSectionHeader(title: "Rotation", icon: "rotate.right")

            Text("Rotate images in 90° increments:")
                .font(.body)

            BulletPoint(text: "**Rotate L** - Rotate 90° counter-clockwise (left)")
            BulletPoint(text: "**Rotate R** - Rotate 90° clockwise (right)")

            Divider()

            HelpSectionHeader(title: "Flip / Mirror", icon: "arrow.left.and.right.righttriangle.left.righttriangle.right")

            Text("Create mirror images:")
                .font(.body)

            BulletPoint(text: "**Flip H** - Flip horizontally (mirror left-right)")
            BulletPoint(text: "**Flip V** - Flip vertically (mirror top-bottom)")

            Divider()

            HelpSectionHeader(title: "Zoom Controls", icon: "magnifyingglass")

            BulletPoint(text: "**Zoom -** - Decrease magnification (min 25%)")
            BulletPoint(text: "**Zoom +** - Increase magnification (max 800%)")
            BulletPoint(text: "**Fit** - Auto-fit image to preview area")
            BulletPoint(text: "**Percentage display** - Shows current zoom level")

            Divider()

            HelpSectionHeader(title: "Crop Tool", icon: "crop")

            Text("Select and crop a region of the image:")
                .font(.body)

            NumberedStep(number: 1, title: "Activate", description: "Click the Crop button in the toolbar")
            NumberedStep(number: 2, title: "Select", description: "Click and drag to draw a selection rectangle")
            NumberedStep(number: 3, title: "Apply", description: "Release to crop to the selected area")

            Divider()

            HelpSectionHeader(title: "Undo", icon: "arrow.uturn.backward")

            Text("All transformations (rotate, flip, crop) can be undone:")
                .font(.body)

            BulletPoint(text: "Click **Undo** in the toolbar or press **Cmd+Z**")
            BulletPoint(text: "Up to 10 actions can be undone")
            BulletPoint(text: "Undo restores the previous image state completely")

            Divider()

            HelpSectionHeader(title: "Important Notes", icon: "info.circle")

            BulletPoint(text: "All transformations are applied to the **preview only**")
            BulletPoint(text: "Original files are **never modified**")
            BulletPoint(text: "Transformed images are saved when you **Export**")
            BulletPoint(text: "Tools are disabled when no image is selected")
        }
    }

    // MARK: - Palette Editing

    private var paletteEditingContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Palette Editing")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("One of the most powerful features is the ability to edit palette colors with live preview.")
                .font(.body)

            Divider()

            HelpSectionHeader(title: "How It Works", icon: "paintpalette")

            Text("The palette display in the info bar shows the colors used by the current image. For editable palettes, you can modify colors to create custom color schemes.")
                .font(.body)

            BulletPoint(text: "**Click a color swatch** to open the macOS color picker")
            BulletPoint(text: "**Choose a new color** and the preview updates instantly")
            BulletPoint(text: "**Hover over colors** to see the color index and hex value")

            Divider()

            HelpSectionHeader(title: "Palette Types", icon: "square.grid.3x3")

            BulletPoint(text: "**Fixed** - Non-editable system palettes (C64, ZX Spectrum)")
            BulletPoint(text: "**Single** - One palette for the entire image (standard SHR, IFF)")
            BulletPoint(text: "**Multiple** - Multiple palettes selectable per scanline (SHR)")
            BulletPoint(text: "**Per-Scanline** - Unique palette for each line (3200-color mode)")

            Divider()

            HelpSectionHeader(title: "Scanline-Linked Palettes", icon: "line.3.horizontal")

            Text("For 3200-color images, move your mouse over the preview to see the palette for each scanline. The palette display updates automatically as you move.")
                .font(.body)

            Divider()

            HelpSectionHeader(title: "Important Notes", icon: "info.circle")

            BulletPoint(text: "Palette edits affect **exported images only**")
            BulletPoint(text: "Original files are **never modified**")
            BulletPoint(text: "Edits are preserved until you close the app or remove the image")
        }
    }

    // MARK: - Exporting Images

    private var exportingImagesContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Exporting Images")
                .font(.largeTitle)
                .fontWeight(.bold)

            Divider()

            HelpSectionHeader(title: "Export Dialog", icon: "square.and.arrow.up")

            Text("Click the Export button to open the export dialog. You can configure:")
                .font(.body)

            BulletPoint(text: "**Output formats** - PNG, JPEG, TIFF, BMP, GIF")
            BulletPoint(text: "**Scale factor** - 1x (original), 2x, or 4x")
            BulletPoint(text: "**Output location** - Choose where to save files")

            Divider()

            HelpSectionHeader(title: "Format Recommendations", icon: "star")

            BulletPoint(text: "**PNG** - Best for pixel art, lossless compression")
            BulletPoint(text: "**JPEG** - Good for photos, smaller file size")
            BulletPoint(text: "**TIFF** - Professional use, maximum quality")
            BulletPoint(text: "**GIF** - Limited to 256 colors, good for simple graphics")
            BulletPoint(text: "**BMP** - Universal compatibility, uncompressed")

            Divider()

            HelpSectionHeader(title: "Scaling", icon: "arrow.up.left.and.arrow.down.right")

            Text("Retro graphics are typically small (280x192 to 640x400). Scaling enlarges them for modern displays:")
                .font(.body)

            BulletPoint(text: "**1x** - Original size, best for archival")
            BulletPoint(text: "**2x** - Good for most uses")
            BulletPoint(text: "**4x** - Large size for printing or wallpapers")

            Divider()

            HelpSectionHeader(title: "Palette Modifications", icon: "paintpalette.fill")

            Text("If you've edited colors in the palette, exported images will use your modified colors. This is great for creating custom color schemes or correcting faded palettes.")
                .font(.body)

            Divider()

            HelpSectionHeader(title: "Create a Screensaver", icon: "tv")

            Text("Turn your retro graphics collection into a macOS screensaver:")
                .font(.body)

            NumberedStep(number: 1, title: "Select Images", description: "Select the images you want in your screensaver (or leave unselected for all)")

            NumberedStep(number: 2, title: "Click Screensaver", description: "Click the Screensaver button in the toolbar")

            NumberedStep(number: 3, title: "Configure", description: "Enter a name and choose a scale (4x recommended for modern displays)")

            NumberedStep(number: 4, title: "Create", description: "Click 'Create Screensaver' - images are saved to ~/Pictures/Retro Screensavers/")

            Text("Setting up in System Settings:")
                .font(.headline)
                .padding(.top, 8)

            NumberedStep(number: 1, title: "Open Settings", description: "The Wallpaper & Screen Saver panel opens automatically")

            NumberedStep(number: 2, title: "Select Screen Saver", description: "Click 'Screen Saver' at the top of the panel")

            NumberedStep(number: 3, title: "Choose Style", description: "Pick a style like Shuffle, Hello, or Shifting Tiles")

            NumberedStep(number: 4, title: "Add Folder", description: "Click the preview image, then 'Add Folder...'")

            NumberedStep(number: 5, title: "Select Your Folder", description: "Navigate to Pictures → Retro Screensavers → your folder name")

            BulletPoint(text: "Your retro graphics will now display as your Mac screensaver!")

            Divider()

            HelpSectionHeader(title: "Create a Movie", icon: "film")

            Text("Export your retro graphics as a video slideshow:")
                .font(.body)

            NumberedStep(number: 1, title: "Select Images", description: "Select the images you want in your movie (or leave unselected for all)")

            NumberedStep(number: 2, title: "Click Movie", description: "Click the Movie button in the toolbar")

            NumberedStep(number: 3, title: "Choose Format", description: "Select MP4 (universal) or MOV (macOS)")

            NumberedStep(number: 4, title: "Configure Settings", description: "Set duration per image, transition style, resolution, and codec")

            NumberedStep(number: 5, title: "Create", description: "Click 'Create Movie' and choose where to save")

            Text("Movie Options:")
                .font(.headline)
                .padding(.top, 8)

            BulletPoint(text: "**Duration** - How long each image displays (1-10 seconds)")

            BulletPoint(text: "**Transitions** - None, Crossfade, Fade to Black, Slides, Wipes, Zooms, or Random")

            BulletPoint(text: "**Resolution** - 720p, 1080p, or 4K output")

            BulletPoint(text: "**Codec** - H.264 (compatible everywhere) or H.265 (better quality, smaller files)")

            BulletPoint(text: "**Scale** - 2x, 4x, or 8x pixel scaling with nearest-neighbor interpolation")
        }
    }

    // MARK: - Supported Formats

    private var supportedFormatsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Supported Formats")
                .font(.largeTitle)
                .fontWeight(.bold)

            Divider()

            HelpSectionHeader(title: "Apple II Family", icon: "desktopcomputer")

            FormatRow(format: "HGR", description: "Hi-Res Graphics (280x192, 6 colors)")
            FormatRow(format: "DHGR", description: "Double Hi-Res (560x192, 16 colors)")
            FormatRow(format: "SHR", description: "Super Hi-Res (320x200, 16 colors per line)")
            FormatRow(format: "3200", description: "3200-color mode (unique palette per scanline)")
            FormatRow(format: "3201", description: "Compressed 3200-color (PackBytes)")
            FormatRow(format: "PNT/PIC", description: "ProDOS graphics files")
            FormatRow(format: "816/Paint", description: "Baudville 816/Paint format")
            FormatRow(format: "Paintworks", description: "Activision Paintworks format")
            FormatRow(format: "APF", description: "Apple Preferred Format")
            FormatRow(format: "DreamGrafix", description: "256 and 3200-color modes with LZW compression")

            Divider()

            HelpSectionHeader(title: "Commodore", icon: "cpu")

            FormatRow(format: "Koala", description: "C64 multicolor bitmap (320x200)")
            FormatRow(format: "Art Studio", description: "C64 high-res art format")

            Divider()

            HelpSectionHeader(title: "Amiga", icon: "memorychip")

            FormatRow(format: "IFF/ILBM", description: "Interchange File Format (up to 256 colors)")

            Divider()

            HelpSectionHeader(title: "Atari ST", icon: "rectangle.split.3x1")

            FormatRow(format: "Degas", description: "PI1/PI2/PI3 (16/4/2 colors)")

            Divider()

            HelpSectionHeader(title: "PC Formats", icon: "pc")

            FormatRow(format: "PCX", description: "PC Paintbrush (1-24 bit)")
            FormatRow(format: "BMP", description: "Windows Bitmap (1-24 bit)")

            Divider()

            HelpSectionHeader(title: "MSX", icon: "tv")

            FormatRow(format: "Screen 1", description: "Text/tile mode (256x192, 16 colors)")
            FormatRow(format: "Screen 2", description: "Graphics II mode (256x192, 16 colors)")
            FormatRow(format: "Screen 5", description: "MSX2 bitmap (256x212, 16 colors)")
            FormatRow(format: "Screen 8", description: "MSX2 256-color mode (256x212)")

            Divider()

            HelpSectionHeader(title: "BBC Micro", icon: "rectangle.on.rectangle")

            FormatRow(format: "MODE 0", description: "High-res 2-color (640x256)")
            FormatRow(format: "MODE 1", description: "4-color mode (320x256)")
            FormatRow(format: "MODE 2", description: "16-color mode (160x256)")
            FormatRow(format: "MODE 4/5", description: "Reduced memory modes (10KB)")

            Divider()

            HelpSectionHeader(title: "TRS-80 / CoCo", icon: "display")

            FormatRow(format: "Model I/III", description: "Block graphics (128x48)")
            FormatRow(format: "PMODE 3/4", description: "CoCo graphics (128x192, 256x192)")
            FormatRow(format: "CoCo 3", description: "Enhanced modes (320x200, 16 colors)")

            Divider()

            HelpSectionHeader(title: "Other", icon: "square.grid.2x2")

            FormatRow(format: "ZX Spectrum", description: "Spectrum screen files (256x192)")
            FormatRow(format: "Amstrad CPC", description: "Mode 0/1 graphics (16/4 colors)")
            FormatRow(format: "MacPaint", description: "Classic Mac 1-bit graphics")

            Divider()

            HelpSectionHeader(title: "Disk Images", icon: "externaldrive.fill")

            FormatRow(format: ".dsk", description: "Apple II disk image (140K/800K)")
            FormatRow(format: ".do", description: "DOS-ordered disk image")
            FormatRow(format: ".po", description: "ProDOS-ordered disk image")
            FormatRow(format: ".2mg", description: "Universal disk image format")
            FormatRow(format: ".hdv", description: "Hard drive volume image")
            FormatRow(format: ".d64", description: "C64 1541 floppy disk image (170K)")
            FormatRow(format: ".d71", description: "C64 1571 dual-sided floppy (340K)")
            FormatRow(format: ".d81", description: "C64 1581 3.5\" floppy (800K)")
        }
    }

    // MARK: - Keyboard Shortcuts

    private var keyboardShortcutsContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Keyboard Shortcuts")
                .font(.largeTitle)
                .fontWeight(.bold)

            Divider()

            HelpSectionHeader(title: "File Operations", icon: "doc")

            ShortcutRow(keys: "Cmd + O", action: "Import files")
            ShortcutRow(keys: "Cmd + E", action: "Export selected images")
            ShortcutRow(keys: "Cmd + A", action: "Select all images")

            Divider()

            HelpSectionHeader(title: "Editing", icon: "pencil")

            ShortcutRow(keys: "Cmd + Z", action: "Undo last action")
            ShortcutRow(keys: "Delete", action: "Remove selected images")

            Divider()

            HelpSectionHeader(title: "View", icon: "eye")

            ShortcutRow(keys: "Cmd + +", action: "Zoom in")
            ShortcutRow(keys: "Cmd + -", action: "Zoom out")
            ShortcutRow(keys: "Cmd + 0", action: "Fit to window")

            Divider()

            HelpSectionHeader(title: "Navigation", icon: "arrow.left.arrow.right")

            ShortcutRow(keys: "Up/Down Arrow", action: "Previous/Next image")
            ShortcutRow(keys: "Home", action: "First image")
            ShortcutRow(keys: "End", action: "Last image")
        }
    }

    // MARK: - Troubleshooting

    private var troubleshootingContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Troubleshooting")
                .font(.largeTitle)
                .fontWeight(.bold)

            Divider()

            HelpSectionHeader(title: "Image Won't Load", icon: "exclamationmark.triangle")

            BulletPoint(text: "Verify the file is a supported format")
            BulletPoint(text: "Check that the file isn't corrupted")
            BulletPoint(text: "For disk images, ensure the disk format is DOS 3.3 or ProDOS")
            BulletPoint(text: "Some non-standard formats may not be recognized")

            Divider()

            HelpSectionHeader(title: "Colors Look Wrong", icon: "paintpalette")

            BulletPoint(text: "Different emulators use different color palettes")
            BulletPoint(text: "Use palette editing to adjust colors to your preference")
            BulletPoint(text: "Apple II artifact colors vary based on monitor type")

            Divider()

            HelpSectionHeader(title: "Disk Image Issues", icon: "externaldrive.badge.exclamationmark")

            BulletPoint(text: "Some copy-protected disks cannot be read")
            BulletPoint(text: "Non-standard sector interleaving may cause issues")
            BulletPoint(text: "Bootable slideshow disks use raw scanning mode")

            Divider()

            HelpSectionHeader(title: "Export Problems", icon: "square.and.arrow.up.trianglebadge.exclamationmark")

            BulletPoint(text: "Ensure you have write permission to the output folder")
            BulletPoint(text: "Check available disk space for large exports")
            BulletPoint(text: "Try a different output format if one fails")

            Divider()

            HelpSectionHeader(title: "Getting Help", icon: "questionmark.circle")

            Text("If you encounter issues not covered here:")
                .font(.body)

            HStack(alignment: .top, spacing: 8) {
                Text("•")
                    .foregroundColor(.secondary)
                Link("Visit the project's GitHub page for support",
                     destination: URL(string: "https://github.com/portwally/Retro-Graphics-converter")!)
                    .font(.body)
            }
            .padding(.leading, 16)

            BulletPoint(text: "Check for updates that may fix your issue")
            BulletPoint(text: "Report bugs with detailed reproduction steps")
        }
    }
}

// MARK: - Helper Views

private struct HelpSectionHeader: View {
    let title: String
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(.accentColor)
            Text(title)
                .font(.title2)
                .fontWeight(.semibold)
        }
        .padding(.top, 8)
    }
}

private struct BulletPoint: View {
    let text: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .foregroundColor(.secondary)
            Text(text)
                .font(.body)
        }
        .padding(.leading, 16)
    }
}

private struct NumberedStep: View {
    let number: Int
    let title: String
    let description: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(number)")
                .font(.headline)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Color.accentColor)
                .clipShape(Circle())

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.headline)
                Text(description)
                    .font(.body)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.leading, 8)
    }
}

private struct FormatRow: View {
    let format: String
    let description: String

    var body: some View {
        HStack(alignment: .top) {
            Text(format)
                .font(.system(.body, design: .monospaced))
                .fontWeight(.medium)
                .frame(width: 100, alignment: .leading)
            Text(description)
                .font(.body)
                .foregroundColor(.secondary)
        }
        .padding(.leading, 16)
    }
}

private struct ShortcutRow: View {
    let keys: String
    let action: String

    var body: some View {
        HStack {
            Text(keys)
                .font(.system(.body, design: .monospaced))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(4)
                .frame(width: 140, alignment: .leading)
            Text(action)
                .font(.body)
        }
        .padding(.leading, 16)
    }
}

// MARK: - Preview

#Preview {
    HelpView()
}
