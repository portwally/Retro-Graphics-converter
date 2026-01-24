import SwiftUI

// MARK: - Labeled Toolbar Button (CyanHero style)

struct LabeledToolbarButton: View {
    let icon: String
    let label: String
    var isActive: Bool = false
    var isDisabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(isActive ? Color.accentColor.opacity(0.2) : Color.clear)
                    )
                    .foregroundColor(isDisabled ? Color(NSColor.tertiaryLabelColor) : (isActive ? .accentColor : Color(NSColor.labelColor)))

                Text(label)
                    .font(.system(size: 9))
                    .foregroundColor(isDisabled ? Color(NSColor.tertiaryLabelColor) : (isActive ? .accentColor : Color(NSColor.secondaryLabelColor)))
            }
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .help(label)
    }
}

// MARK: - Main Toolbar View

struct MainToolbarView: View {
    @Binding var zoomScale: CGFloat
    @Binding var cropMode: Bool
    let canUndo: Bool
    let hasImage: Bool
    let hasModification: Bool
    let hasSelection: Bool
    let hasImages: Bool
    let onImport: () -> Void
    let onExport: () -> Void
    let onScreensaver: () -> Void
    let onMovie: () -> Void
    let onUndo: () -> Void
    let onRotateLeft: () -> Void
    let onRotateRight: () -> Void
    let onFlipHorizontal: () -> Void
    let onFlipVertical: () -> Void
    let onInvert: () -> Void
    let onCopy: () -> Void
    let onCompare: () -> Void
    @Binding var showOriginal: Bool

    // Adjustments
    @Binding var showAdjustments: Bool
    @Binding var adjustments: ImageAdjustments
    let onAdjustmentsApply: () -> Void
    let onAdjustmentsReset: () -> Void
    let onAdjustmentsPreview: (ImageAdjustments) -> Void

    // Histogram
    let currentImage: NSImage?
    @State private var showHistogram = false

    private var zoomPercentage: Int {
        if zoomScale < 0 {
            return 100
        }
        return Int(zoomScale * 100)
    }

    private var isFitMode: Bool {
        zoomScale < 0
    }

    var body: some View {
        HStack(spacing: 12) {
            // Import/Export group (left side)
            HStack(spacing: 8) {
                LabeledToolbarButton(
                    icon: "square.and.arrow.down",
                    label: "Import",
                    action: onImport
                )

                LabeledToolbarButton(
                    icon: "square.and.arrow.up",
                    label: "Export",
                    action: onExport
                )

                LabeledToolbarButton(
                    icon: "tv",
                    label: "Screensaver",
                    isDisabled: !hasImages,
                    action: onScreensaver
                )

                LabeledToolbarButton(
                    icon: "film",
                    label: "Movie",
                    isDisabled: !hasImages,
                    action: onMovie
                )
            }

            Spacer()

            // Zoom group
            HStack(spacing: 8) {
                LabeledToolbarButton(
                    icon: "minus.magnifyingglass",
                    label: "−",
                    isDisabled: isFitMode,
                    action: zoomOut
                )

                // Zoom percentage display
                VStack(spacing: 2) {
                    Text("\(zoomPercentage)%")
                        .font(.system(size: 14, weight: .medium, design: .monospaced))
                        .frame(width: 50, height: 36)
                        .foregroundColor(Color(NSColor.labelColor))

                    Text("Zoom")
                        .font(.system(size: 9))
                        .foregroundColor(Color(NSColor.secondaryLabelColor))
                }

                LabeledToolbarButton(
                    icon: "plus.magnifyingglass",
                    label: "+",
                    action: zoomIn
                )

                LabeledToolbarButton(
                    icon: "arrow.up.backward.and.arrow.down.forward",
                    label: "Fit",
                    isActive: isFitMode,
                    action: fitToWindow
                )
            }

            Divider()
                .frame(height: 50)

            // Transform group (Rotate, Flip, Invert)
            HStack(spacing: 8) {
                LabeledToolbarButton(
                    icon: "rotate.left",
                    label: "Rotate L",
                    isDisabled: !hasImage && !hasSelection,
                    action: onRotateLeft
                )

                LabeledToolbarButton(
                    icon: "rotate.right",
                    label: "Rotate R",
                    isDisabled: !hasImage && !hasSelection,
                    action: onRotateRight
                )

                LabeledToolbarButton(
                    icon: "arrow.left.and.right.righttriangle.left.righttriangle.right",
                    label: "Flip H",
                    isDisabled: !hasImage && !hasSelection,
                    action: onFlipHorizontal
                )

                LabeledToolbarButton(
                    icon: "arrow.up.and.down.righttriangle.up.righttriangle.down",
                    label: "Flip V",
                    isDisabled: !hasImage && !hasSelection,
                    action: onFlipVertical
                )

                LabeledToolbarButton(
                    icon: "circle.lefthalf.filled",
                    label: "Invert",
                    isDisabled: !hasImage && !hasSelection,
                    action: onInvert
                )
            }

            Divider()
                .frame(height: 50)

            // Clipboard & Compare group
            HStack(spacing: 8) {
                LabeledToolbarButton(
                    icon: "doc.on.doc",
                    label: "Copy",
                    isDisabled: !hasImage,
                    action: onCopy
                )

                LabeledToolbarButton(
                    icon: "eye.slash",
                    label: showOriginal ? "Modified" : "Original",
                    isActive: showOriginal,
                    isDisabled: !hasModification,
                    action: onCompare
                )
            }

            Divider()
                .frame(height: 50)

            // Adjustments & Histogram group
            HStack(spacing: 8) {
                LabeledToolbarButton(
                    icon: "slider.horizontal.3",
                    label: "Adjust",
                    isActive: showAdjustments,
                    isDisabled: !hasImage,
                    action: { showAdjustments.toggle() }
                )
                .popover(isPresented: $showAdjustments, arrowEdge: .bottom) {
                    AdjustmentsView(
                        adjustments: $adjustments,
                        onApply: {
                            showAdjustments = false
                            onAdjustmentsApply()
                        },
                        onReset: onAdjustmentsReset,
                        onPreview: onAdjustmentsPreview
                    )
                }

                LabeledToolbarButton(
                    icon: "chart.bar.fill",
                    label: "Histo",
                    isActive: showHistogram,
                    isDisabled: !hasImage,
                    action: { showHistogram.toggle() }
                )
                .popover(isPresented: $showHistogram, arrowEdge: .bottom) {
                    HistogramView(image: currentImage)
                }
            }

            Divider()
                .frame(height: 50)

            // Crop/Undo group
            HStack(spacing: 8) {
                LabeledToolbarButton(
                    icon: "crop",
                    label: "Crop",
                    isActive: cropMode,
                    action: { cropMode.toggle() }
                )

                LabeledToolbarButton(
                    icon: "arrow.uturn.backward",
                    label: "Undo",
                    isDisabled: !canUndo,
                    action: onUndo
                )
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
    }

    private func zoomOut() {
        if zoomScale < 0 {
            zoomScale = 1.0
        }
        zoomScale = max(0.25, zoomScale - 0.25)
    }

    private func zoomIn() {
        if zoomScale < 0 {
            zoomScale = 1.0
        }
        zoomScale = min(8.0, zoomScale + 0.25)
    }

    private func fitToWindow() {
        zoomScale = -1.0
    }
}

// MARK: - Zoom Controls (Legacy - kept for compatibility)

struct ZoomControlsView: View {
    @Binding var zoomScale: CGFloat

    private var zoomPercentage: Int {
        if zoomScale < 0 {
            return 100
        }
        return Int(zoomScale * 100)
    }

    private var isFitMode: Bool {
        zoomScale < 0
    }

    var body: some View {
        HStack(spacing: 8) {
            Button(action: zoomOut) {
                Image(systemName: "minus.magnifyingglass")
                    .font(.system(size: 14))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderless)
            .disabled(isFitMode)
            .help("Zoom Out")

            Text("\(zoomPercentage)%")
                .font(.system(.body, design: .default))
                .frame(width: 50)

            Button(action: zoomIn) {
                Image(systemName: "plus.magnifyingglass")
                    .font(.system(size: 14))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderless)
            .help("Zoom In")

            Button(action: fitToWindow) {
                Image(systemName: "arrow.up.backward.and.arrow.down.forward")
                    .font(.system(size: 14))
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.borderless)
            .help("Fit to Window")
        }
    }

    private func zoomOut() {
        if zoomScale < 0 {
            zoomScale = 1.0
        }
        zoomScale = max(0.25, zoomScale - 0.25)
    }

    private func zoomIn() {
        if zoomScale < 0 {
            zoomScale = 1.0
        }
        zoomScale = min(8.0, zoomScale + 0.25)
    }

    private func fitToWindow() {
        zoomScale = -1.0
    }
}

// MARK: - Crop Tools (Legacy - kept for compatibility)

struct CropToolsView: View {
    @Binding var cropMode: Bool
    let canUndo: Bool
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: 4) {
            Toggle(isOn: $cropMode) {
                Image(systemName: "crop")
                    .frame(width: 20, height: 20)
            }
            .toggleStyle(.button)
            .help("Crop Tool")

            Button(action: onUndo) {
                Image(systemName: "arrow.uturn.backward")
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.borderless)
            .disabled(!canUndo)
            .help("Undo")
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 0) {
        MainToolbarView(
            zoomScale: .constant(1.0),
            cropMode: .constant(false),
            canUndo: true,
            hasImage: true,
            hasModification: true,
            hasSelection: false,
            hasImages: true,
            onImport: {},
            onExport: {},
            onScreensaver: {},
            onMovie: {},
            onUndo: {},
            onRotateLeft: {},
            onRotateRight: {},
            onFlipHorizontal: {},
            onFlipVertical: {},
            onInvert: {},
            onCopy: {},
            onCompare: {},
            showOriginal: .constant(false),
            showAdjustments: .constant(false),
            adjustments: .constant(ImageAdjustments()),
            onAdjustmentsApply: {},
            onAdjustmentsReset: {},
            onAdjustmentsPreview: { _ in },
            currentImage: nil
        )

        Divider()

        MainToolbarView(
            zoomScale: .constant(-1.0),
            cropMode: .constant(true),
            canUndo: false,
            hasImage: false,
            hasModification: false,
            hasSelection: true,
            hasImages: false,
            onImport: {},
            onExport: {},
            onScreensaver: {},
            onMovie: {},
            onUndo: {},
            onRotateLeft: {},
            onRotateRight: {},
            onFlipHorizontal: {},
            onFlipVertical: {},
            onInvert: {},
            onCopy: {},
            onCompare: {},
            showOriginal: .constant(true),
            showAdjustments: .constant(false),
            adjustments: .constant(ImageAdjustments()),
            onAdjustmentsApply: {},
            onAdjustmentsReset: {},
            onAdjustmentsPreview: { _ in },
            currentImage: nil
        )
    }
    .frame(width: 1100)
}
