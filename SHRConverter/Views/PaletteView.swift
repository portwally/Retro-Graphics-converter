import SwiftUI
import AppKit

// MARK: - Palette View

struct PaletteView: View {
    let paletteInfo: PaletteInfo?
    @Binding var currentScanline: Int?
    let onColorEdit: ((Int, Int, NSColor) -> Void)?

    @State private var hoveredColorIndex: Int? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            headerView

            // Palette colors
            if let colors = displayPalette {
                paletteColorsView(colors: colors)
            } else {
                Text("No palette data")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Mode description
            if let info = paletteInfo {
                Text(info.displayDescription)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Text(headerText)
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            if paletteInfo?.isEditable == true {
                Text("Click to edit")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var headerText: String {
        guard let info = paletteInfo else { return "Palette" }

        switch info.type {
        case .perScanline:
            let line = currentScanline ?? 100
            return "Palette (Line \(line) of \(info.paletteCount))"
        case .multiPalette:
            if let scb = info.scbMapping, let line = currentScanline, line < scb.count {
                return "Palette \(scb[line]) (Line \(line))"
            }
            return "Palette (\(info.paletteCount) available)"
        case .fixed:
            return "Palette (\(info.colorsPerPalette) colors, fixed)"
        case .single:
            return "Palette (\(info.colorsPerPalette) colors)"
        }
    }

    // MARK: - Display Palette

    private var displayPalette: [PaletteColor]? {
        guard let info = paletteInfo else { return nil }

        switch info.type {
        case .perScanline:
            let line = currentScanline ?? 100
            return info.palette(forScanline: line)
        case .multiPalette:
            if let scb = info.scbMapping, let line = currentScanline, line < scb.count {
                let paletteIndex = scb[line]
                if paletteIndex < info.palettes.count {
                    return info.palettes[paletteIndex]
                }
            }
            return info.primaryPalette
        case .single, .fixed:
            return info.primaryPalette
        }
    }

    private var currentPaletteIndex: Int {
        guard let info = paletteInfo else { return 0 }

        switch info.type {
        case .perScanline:
            return currentScanline ?? 100
        case .multiPalette:
            if let scb = info.scbMapping, let line = currentScanline, line < scb.count {
                return scb[line]
            }
            return 0
        case .single, .fixed:
            return 0
        }
    }

    // MARK: - Palette Colors View

    private func paletteColorsView(colors: [PaletteColor]) -> some View {
        // Determine layout based on number of colors
        let maxColorsPerRow = 16
        let rows = (colors.count + maxColorsPerRow - 1) / maxColorsPerRow

        return VStack(alignment: .leading, spacing: 2) {
            ForEach(0..<rows, id: \.self) { row in
                HStack(spacing: 2) {
                    ForEach(0..<min(maxColorsPerRow, colors.count - row * maxColorsPerRow), id: \.self) { col in
                        let index = row * maxColorsPerRow + col
                        if index < colors.count {
                            ColorSwatchView(
                                color: colors[index],
                                index: index,
                                isEditable: paletteInfo?.isEditable ?? false,
                                isHovered: hoveredColorIndex == index,
                                onHover: { hoveredColorIndex = $0 ? index : nil },
                                onEdit: { newColor in
                                    onColorEdit?(currentPaletteIndex, index, newColor)
                                }
                            )
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Color Swatch View

struct ColorSwatchView: View {
    let color: PaletteColor
    let index: Int
    let isEditable: Bool
    let isHovered: Bool
    let onHover: (Bool) -> Void
    let onEdit: (NSColor) -> Void

    var body: some View {
        Rectangle()
            .fill(Color(color.nsColor))
            .frame(width: 16, height: 16)
            .border(isHovered ? Color.white : Color.gray.opacity(0.3), width: isHovered ? 2 : 0.5)
            .onHover { hovering in
                onHover(hovering)
            }
            .onTapGesture {
                if isEditable {
                    openColorPanel()
                }
            }
            .help("Color \(index): \(color.hexString)\(isEditable ? " - Click to edit" : "")")
    }

    private func openColorPanel() {
        let colorPanel = NSColorPanel.shared
        colorPanel.color = color.nsColor
        colorPanel.setTarget(nil)
        colorPanel.setAction(nil)
        colorPanel.isContinuous = true
        colorPanel.showsAlpha = false

        // Create a handler for color changes
        let handler = ColorPanelHandler(onColorChange: onEdit)
        colorPanel.setTarget(handler)
        colorPanel.setAction(#selector(ColorPanelHandler.colorChanged(_:)))

        // Store handler to keep it alive
        objc_setAssociatedObject(colorPanel, "colorHandler", handler, .OBJC_ASSOCIATION_RETAIN)

        colorPanel.orderFront(nil)
    }
}

// MARK: - Color Panel Handler

class ColorPanelHandler: NSObject {
    let onColorChange: (NSColor) -> Void

    init(onColorChange: @escaping (NSColor) -> Void) {
        self.onColorChange = onColorChange
    }

    @objc func colorChanged(_ sender: NSColorPanel) {
        onColorChange(sender.color)
    }
}

// MARK: - Preview

#Preview {
    PaletteView(
        paletteInfo: nil,
        currentScanline: .constant(nil),
        onColorEdit: nil
    )
    .padding()
    .background(Color(NSColor.controlBackgroundColor))
}
