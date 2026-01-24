import SwiftUI
import AppKit

// MARK: - Adjustment Parameters

struct ImageAdjustments: Equatable {
    var brightness: Double = 0.0  // Range: -1.0 to 1.0
    var contrast: Double = 0.0    // Range: -1.0 to 1.0

    static let identity = ImageAdjustments()

    var isIdentity: Bool {
        brightness == 0.0 && contrast == 0.0
    }
}

// MARK: - Adjustments View

struct AdjustmentsView: View {
    @Binding var adjustments: ImageAdjustments
    let onApply: () -> Void
    let onReset: () -> Void
    let onPreview: (ImageAdjustments) -> Void

    @State private var localBrightness: Double = 0.0
    @State private var localContrast: Double = 0.0

    var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Text("Adjustments")
                    .font(.headline)
                Spacer()
            }

            // Brightness slider
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Brightness")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%+.0f%%", localBrightness * 100))
                        .font(.system(size: 11, design: .monospaced))
                        .frame(width: 50, alignment: .trailing)
                }

                HStack {
                    Image(systemName: "sun.min")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

                    Slider(value: $localBrightness, in: -1.0...1.0)
                        .onChange(of: localBrightness) { _, _ in
                            updatePreview()
                        }

                    Image(systemName: "sun.max")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }

            // Contrast slider
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Contrast")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(String(format: "%+.0f%%", localContrast * 100))
                        .font(.system(size: 11, design: .monospaced))
                        .frame(width: 50, alignment: .trailing)
                }

                HStack {
                    Image(systemName: "circle.lefthalf.filled")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)

                    Slider(value: $localContrast, in: -1.0...1.0)
                        .onChange(of: localContrast) { _, _ in
                            updatePreview()
                        }

                    Image(systemName: "circle.lefthalf.striped.horizontal")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }

            Divider()

            // Buttons
            HStack {
                Button("Reset") {
                    localBrightness = 0.0
                    localContrast = 0.0
                    onReset()
                }
                .buttonStyle(.bordered)

                Spacer()

                Button("Apply") {
                    adjustments = ImageAdjustments(
                        brightness: localBrightness,
                        contrast: localContrast
                    )
                    onApply()
                }
                .buttonStyle(.borderedProminent)
                .disabled(localBrightness == 0.0 && localContrast == 0.0)
            }
        }
        .padding(16)
        .frame(width: 280)
        .onAppear {
            localBrightness = adjustments.brightness
            localContrast = adjustments.contrast
        }
    }

    private func updatePreview() {
        let newAdjustments = ImageAdjustments(
            brightness: localBrightness,
            contrast: localContrast
        )
        onPreview(newAdjustments)
    }
}

// MARK: - Adjustments Button

struct AdjustmentsButton: View {
    let hasImage: Bool
    @Binding var showAdjustments: Bool
    @Binding var adjustments: ImageAdjustments
    let onApply: () -> Void
    let onReset: () -> Void
    let onPreview: (ImageAdjustments) -> Void

    var body: some View {
        Button(action: { showAdjustments.toggle() }) {
            VStack(spacing: 2) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 18))
                    .frame(width: 36, height: 36)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(showAdjustments ? Color.accentColor.opacity(0.2) : Color.clear)
                    )
                    .foregroundColor(!hasImage ? Color(NSColor.tertiaryLabelColor) :
                                    (showAdjustments ? .accentColor : Color(NSColor.labelColor)))

                Text("Adjust")
                    .font(.system(size: 9))
                    .foregroundColor(!hasImage ? Color(NSColor.tertiaryLabelColor) :
                                    (showAdjustments ? .accentColor : Color(NSColor.secondaryLabelColor)))
            }
        }
        .buttonStyle(.plain)
        .disabled(!hasImage)
        .help("Brightness/Contrast Adjustments")
        .popover(isPresented: $showAdjustments, arrowEdge: .bottom) {
            AdjustmentsView(
                adjustments: $adjustments,
                onApply: {
                    showAdjustments = false
                    onApply()
                },
                onReset: onReset,
                onPreview: onPreview
            )
        }
    }
}

// MARK: - Image Processing

extension NSImage {
    func adjustedImage(brightness: Double, contrast: Double) -> NSImage? {
        guard let cgImage = self.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            return nil
        }

        let width = cgImage.width
        let height = cgImage.height

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

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        guard let data = context.data else { return nil }
        let pixels = data.bindMemory(to: UInt8.self, capacity: width * height * 4)

        // Calculate brightness and contrast adjustments
        // Brightness: add/subtract value
        // Contrast: multiply by factor centered at 128

        let brightnessOffset = brightness * 255.0
        let contrastFactor = contrast >= 0 ? (1.0 + contrast * 3.0) : (1.0 + contrast)

        for i in 0..<(width * height) {
            let offset = i * 4

            // Apply contrast (centered at 128) then brightness
            for c in 0..<3 {
                var value = Double(pixels[offset + c])

                // Apply contrast
                value = (value - 128.0) * contrastFactor + 128.0

                // Apply brightness
                value = value + brightnessOffset

                // Clamp to 0-255
                pixels[offset + c] = UInt8(max(0, min(255, Int(value))))
            }
            // Alpha stays the same (offset + 3)
        }

        guard let adjustedCGImage = context.makeImage() else {
            return nil
        }

        return NSImage(cgImage: adjustedCGImage, size: NSSize(width: width, height: height))
    }
}

// MARK: - Preview

#Preview {
    VStack {
        AdjustmentsView(
            adjustments: .constant(ImageAdjustments()),
            onApply: {},
            onReset: {},
            onPreview: { _ in }
        )

        AdjustmentsButton(
            hasImage: true,
            showAdjustments: .constant(false),
            adjustments: .constant(ImageAdjustments()),
            onApply: {},
            onReset: {},
            onPreview: { _ in }
        )
    }
    .padding()
}
