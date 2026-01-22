import SwiftUI
import AppKit

// MARK: - Info Bar View

struct InfoBarView: View {
    let selectedImage: ImageItem?
    @Binding var currentScanline: Int?
    let onColorEdit: ((Int, Int, NSColor) -> Void)?
    let onResetPalette: (() -> Void)?

    @State private var showInfoPopover = false

    var body: some View {
        HStack(spacing: 0) {
            // File Info section
            fileInfoSection
                .frame(minWidth: 200, maxWidth: 280)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            Divider()

            // Palette section
            paletteSection
                .padding(.horizontal, 12)
                .padding(.vertical, 8)

            Spacer()
        }
        .frame(height: 80)
        .background(Color(NSColor.controlBackgroundColor))
    }

    // MARK: - File Info Section

    private var fileInfoSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text("Source File")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                if selectedImage != nil {
                    Button(action: { showInfoPopover.toggle() }) {
                        Image(systemName: "info.circle")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Show image details")
                    .popover(isPresented: $showInfoPopover, arrowEdge: .bottom) {
                        imageInfoPopover
                    }
                }
            }

            if let image = selectedImage {
                Text(image.filename)
                    .font(.system(.body, design: .monospaced))
                    .lineLimit(1)
                    .truncationMode(.middle)

                HStack(spacing: 8) {
                    // Type badge
                    Text(image.type.displayName)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.blue.opacity(0.2))
                        .cornerRadius(4)

                    // Resolution
                    let res = image.type.resolution
                    if res.width > 0 && res.height > 0 {
                        Text("\(res.width)x\(res.height)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            } else {
                Text("No file selected")
                    .font(.body)
                    .foregroundColor(.secondary)

                Text("Import images to get started")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Image Info Popover

    private var imageInfoPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Image Details")
                .font(.headline)

            if let image = selectedImage {
                Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 6) {
                    GridRow {
                        Text("Filename:")
                            .foregroundColor(.secondary)
                        Text(image.filename)
                            .fontWeight(.medium)
                    }

                    GridRow {
                        Text("Format:")
                            .foregroundColor(.secondary)
                        Text(image.type.displayName)
                    }

                    GridRow {
                        Text("Dimensions:")
                            .foregroundColor(.secondary)
                        Text("\(Int(image.image.size.width)) × \(Int(image.image.size.height)) px")
                    }

                    if let paletteInfo = image.activePalette {
                        GridRow {
                            Text("Colors:")
                                .foregroundColor(.secondary)
                            Text("\(paletteInfo.colorsPerPalette) colors")
                        }

                        if paletteInfo.paletteCount > 1 {
                            GridRow {
                                Text("Palettes:")
                                    .foregroundColor(.secondary)
                                Text("\(paletteInfo.paletteCount) palettes")
                            }
                        }
                    }

                    if let data = image.originalData {
                        GridRow {
                            Text("File Size:")
                                .foregroundColor(.secondary)
                            Text(formatFileSize(data.count))
                        }
                    }

                    GridRow {
                        Text("Source:")
                            .foregroundColor(.secondary)
                        Text(image.url.path)
                            .lineLimit(2)
                            .truncationMode(.middle)
                            .font(.caption)
                    }

                    if image.hasPaletteModification {
                        GridRow {
                            Text("Status:")
                                .foregroundColor(.secondary)
                            HStack(spacing: 4) {
                                Image(systemName: "pencil.circle.fill")
                                    .foregroundColor(.orange)
                                Text("Modified palette")
                            }
                        }
                    }
                }
                .font(.system(.body, design: .monospaced))
            }
        }
        .padding()
        .frame(minWidth: 300)
    }

    private func formatFileSize(_ bytes: Int) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }

    // MARK: - Palette Section

    private var paletteSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                if let image = selectedImage, image.hasPaletteModification {
                    Button(action: { onResetPalette?() }) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.counterclockwise")
                            Text("Reset")
                        }
                        .font(.caption)
                    }
                    .buttonStyle(.borderless)
                }
            }

            PaletteView(
                paletteInfo: selectedImage?.activePalette,
                currentScanline: $currentScanline,
                onColorEdit: onColorEdit
            )
        }
    }
}

// MARK: - Preview

#Preview {
    VStack(spacing: 20) {
        // With selected image
        InfoBarView(
            selectedImage: nil,
            currentScanline: .constant(100),
            onColorEdit: nil,
            onResetPalette: nil
        )

        Divider()

        // Without selected image
        InfoBarView(
            selectedImage: nil,
            currentScanline: .constant(nil),
            onColorEdit: nil,
            onResetPalette: nil
        )
    }
    .frame(width: 700)
}
