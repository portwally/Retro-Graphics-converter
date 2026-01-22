import SwiftUI

// MARK: - Main Toolbar View

struct MainToolbarView: View {
    @Binding var zoomScale: CGFloat
    @Binding var cropMode: Bool
    let canUndo: Bool
    let onImport: () -> Void
    let onExport: () -> Void
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            // Left side: Import/Export buttons
            HStack(spacing: 4) {
                Button(action: onImport) {
                    Label("Import", systemImage: "square.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)

                Button(action: onExport) {
                    Label("Export", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.bordered)
            }

            Spacer()

            // Right side: Tools
            HStack(spacing: 12) {
                // Zoom controls
                ZoomControlsView(zoomScale: $zoomScale)

                Divider()
                    .frame(height: 20)

                // Crop and Undo
                CropToolsView(
                    cropMode: $cropMode,
                    canUndo: canUndo,
                    onUndo: onUndo
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color(NSColor.windowBackgroundColor))
    }
}

// MARK: - Zoom Controls

struct ZoomControlsView: View {
    @Binding var zoomScale: CGFloat

    private var zoomPercentage: Int {
        if zoomScale < 0 {
            return 100  // Fit mode
        }
        return Int(zoomScale * 100)
    }

    private var isFitMode: Bool {
        zoomScale < 0
    }

    var body: some View {
        HStack(spacing: 4) {
            Button(action: zoomOut) {
                Image(systemName: "minus")
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.borderless)
            .disabled(isFitMode)

            Text(isFitMode ? "Fit" : "\(zoomPercentage)%")
                .font(.system(.caption, design: .monospaced))
                .frame(width: 44)

            Button(action: zoomIn) {
                Image(systemName: "plus")
                    .frame(width: 20, height: 20)
            }
            .buttonStyle(.borderless)

            Button(action: fitToWindow) {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .frame(width: 20, height: 20)
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

// MARK: - Crop Tools

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
    VStack {
        MainToolbarView(
            zoomScale: .constant(1.0),
            cropMode: .constant(false),
            canUndo: true,
            onImport: {},
            onExport: {},
            onUndo: {}
        )

        MainToolbarView(
            zoomScale: .constant(-1.0),
            cropMode: .constant(true),
            canUndo: false,
            onImport: {},
            onExport: {},
            onUndo: {}
        )
    }
    .frame(width: 600)
}
