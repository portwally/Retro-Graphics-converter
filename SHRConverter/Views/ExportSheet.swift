import SwiftUI

// MARK: - Export Sheet View

struct ExportSheet: View {
    @Binding var isPresented: Bool
    let selectedCount: Int
    let onExport: (Set<ExportFormat>, Int) -> Void

    @State private var selectedFormats: Set<ExportFormat> = [.png]
    @State private var upscaleFactor: Int = 1

    var body: some View {
        VStack(spacing: 16) {
            // Header
            headerSection

            Divider()

            // Format selection
            formatSelectionSection

            Divider()

            // Scale options
            scaleOptionsSection

            Divider()

            // Buttons at bottom
            buttonSection
        }
        .padding(20)
        .frame(width: 400, height: 450)
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(spacing: 8) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 40))
                .foregroundColor(.accentColor)

            Text("Export Images")
                .font(.title2)
                .fontWeight(.semibold)

            Text("\(selectedCount) image\(selectedCount == 1 ? "" : "s") selected")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Format Selection

    private var formatSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Export Formats")
                .font(.headline)

            Text("Select one or more formats:")
                .font(.caption)
                .foregroundColor(.secondary)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(ExportFormat.allCases.filter { $0 != .original }, id: \.self) { format in
                    formatToggle(for: format)
                }

                Divider()
                    .padding(.vertical, 4)

                formatToggle(for: .original)
                    .help("Export in the original retro format (no conversion)")
            }
        }
    }

    private func formatToggle(for format: ExportFormat) -> some View {
        HStack {
            Toggle(isOn: binding(for: format)) {
                HStack {
                    Text(format.rawValue)
                        .frame(width: 100, alignment: .leading)

                    Text(formatDescription(for: format))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .toggleStyle(.checkbox)
        }
    }

    private func binding(for format: ExportFormat) -> Binding<Bool> {
        Binding(
            get: { selectedFormats.contains(format) },
            set: { isSelected in
                if isSelected {
                    selectedFormats.insert(format)
                } else {
                    selectedFormats.remove(format)
                }
            }
        )
    }

    private func formatDescription(for format: ExportFormat) -> String {
        switch format {
        case .png: return "Lossless, supports transparency"
        case .jpeg: return "Lossy compression, small files"
        case .tiff: return "High quality, large files"
        case .gif: return "256 colors max, animations"
        case .heic: return "Modern, efficient compression"
        case .original: return "Keep native retro format"
        }
    }

    // MARK: - Scale Options

    private var scaleOptionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Output Scale")
                .font(.headline)

            Picker("Scale factor:", selection: $upscaleFactor) {
                Text("1x (Original)").tag(1)
                Text("2x").tag(2)
                Text("4x").tag(4)
                Text("8x").tag(8)
            }
            .pickerStyle(.segmented)

            if upscaleFactor > 1 {
                Text("Images will be scaled using nearest-neighbor (pixel-perfect)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Button Section

    private var buttonSection: some View {
        HStack(spacing: 12) {
            Button("Cancel") {
                isPresented = false
            }
            .buttonStyle(.bordered)
            .keyboardShortcut(.cancelAction)

            Spacer()

            Button("Export \(selectedCount) Image\(selectedCount == 1 ? "" : "s")") {
                onExport(selectedFormats, upscaleFactor)
                isPresented = false
            }
            .buttonStyle(.borderedProminent)
            .disabled(selectedFormats.isEmpty)
            .keyboardShortcut(.defaultAction)
        }
    }
}

// MARK: - Preview

#Preview {
    ExportSheet(
        isPresented: .constant(true),
        selectedCount: 5,
        onExport: { formats, scale in
            print("Exporting to \(formats) at \(scale)x")
        }
    )
}
