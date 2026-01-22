import SwiftUI
import AppKit

// MARK: - Info Bar View

struct InfoBarView: View {
    let selectedImage: ImageItem?
    @Binding var currentScanline: Int?
    let onColorEdit: ((Int, Int, NSColor) -> Void)?
    let onResetPalette: (() -> Void)?

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
            Text("Source File")
                .font(.caption)
                .foregroundColor(.secondary)

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
