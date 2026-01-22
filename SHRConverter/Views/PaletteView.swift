import SwiftUI
import AppKit

// MARK: - Palette View

struct PaletteView: View {
    let paletteInfo: PaletteInfo?
    @Binding var currentScanline: Int?
    let onColorEdit: ((Int, Int, NSColor) -> Void)?

    @State private var hoveredColorIndex: Int? = nil
    @State private var showAllPalettes: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header
            headerView

            // Palette colors
            if let colors = displayPalette {
                HStack(alignment: .top, spacing: 8) {
                    paletteColorsView(colors: colors)

                    // Show edit button for multi-palette modes (3200-color, SHR with multiple palettes)
                    if let info = paletteInfo, info.paletteCount > 1 {
                        Button(action: { showAllPalettes = true }) {
                            VStack(spacing: 2) {
                                Image(systemName: "square.grid.3x3")
                                    .font(.system(size: 14))
                                Text("Edit")
                                    .font(.system(size: 9))
                                Text("\(info.paletteCount)")
                                    .font(.system(size: 9, weight: .medium))
                            }
                            .frame(width: 40)
                        }
                        .buttonStyle(.bordered)
                        .help("Edit all \(info.paletteCount) palettes")
                    }
                }
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
        .sheet(isPresented: $showAllPalettes) {
            if let info = paletteInfo {
                AllPalettesView(
                    paletteInfo: info,
                    currentScanline: currentScanline,
                    onColorEdit: onColorEdit,
                    isPresented: $showAllPalettes
                )
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
        // Determine layout based on number of colors - no scrolling, fit all colors
        let config = paletteLayoutConfig(for: colors.count)
        return paletteGrid(colors: colors, config: config)
    }

    private struct PaletteLayoutConfig {
        let swatchSize: CGFloat
        let colorsPerRow: Int
    }

    private func paletteLayoutConfig(for colorCount: Int) -> PaletteLayoutConfig {
        if colorCount > 128 {
            // 256 colors: 64 per row, 4 rows - fills horizontal space
            return PaletteLayoutConfig(swatchSize: 8, colorsPerRow: 64)
        } else if colorCount > 64 {
            // 65-128 colors: 64 per row, 2 rows
            return PaletteLayoutConfig(swatchSize: 10, colorsPerRow: 64)
        } else if colorCount > 32 {
            // 33-64 colors: 32 per row, 2 rows
            return PaletteLayoutConfig(swatchSize: 12, colorsPerRow: 32)
        } else if colorCount > 16 {
            // 17-32 colors: 32 per row, single row
            return PaletteLayoutConfig(swatchSize: 14, colorsPerRow: 32)
        } else {
            // Up to 16 colors: single row
            return PaletteLayoutConfig(swatchSize: 16, colorsPerRow: 16)
        }
    }

    private func paletteGrid(colors: [PaletteColor], config: PaletteLayoutConfig) -> some View {
        let totalRows = (colors.count + config.colorsPerRow - 1) / config.colorsPerRow
        let rowIndices = Array(0..<totalRows)
        let colIndices = Array(0..<config.colorsPerRow)

        return VStack(alignment: .leading, spacing: 1) {
            ForEach(rowIndices, id: \.self) { row in
                HStack(spacing: 1) {
                    ForEach(colIndices, id: \.self) { col in
                        let index = row * config.colorsPerRow + col
                        if index < colors.count {
                            ColorSwatchView(
                                color: colors[index],
                                index: index,
                                isEditable: paletteInfo?.isEditable ?? false,
                                isHovered: hoveredColorIndex == index,
                                swatchSize: config.swatchSize,
                                onHover: { hoveredColorIndex = $0 ? index : nil },
                                onEdit: { newColor in
                                    onColorEdit?(currentPaletteIndex, index, newColor)
                                }
                            )
                        } else {
                            // Empty space for grid alignment
                            Color.clear
                                .frame(width: config.swatchSize, height: config.swatchSize)
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
    var swatchSize: CGFloat = 16
    let onHover: (Bool) -> Void
    let onEdit: (NSColor) -> Void

    var body: some View {
        Rectangle()
            .fill(Color(color.nsColor))
            .frame(width: swatchSize, height: swatchSize)
            .border(isHovered ? Color.white : Color.gray.opacity(0.3), width: isHovered ? 2 : 0.5)
            .onHover { hovering in
                onHover(hovering)
            }
            .onTapGesture {
                if isEditable {
                    openColorPanel()
                }
            }
            .help("Color \(index): \(color.hexString)")
    }

    private func openColorPanel() {
        let colorPanel = NSColorPanel.shared
        let originalColor = color.nsColor

        // IMPORTANT: Clear target/action FIRST to prevent the old handler from firing
        // when we set the new color (since isContinuous = true)
        colorPanel.setTarget(nil)
        colorPanel.setAction(nil)

        // Now set the color - no action will fire since target is nil
        colorPanel.color = originalColor
        colorPanel.isContinuous = true
        colorPanel.showsAlpha = false

        // Create a handler for color changes that checks if color actually changed
        let handler = ColorPanelHandler(originalColor: originalColor, onColorChange: onEdit)
        colorPanel.setTarget(handler)
        colorPanel.setAction(#selector(ColorPanelHandler.colorChanged(_:)))

        // Store handler to keep it alive
        objc_setAssociatedObject(colorPanel, "colorHandler", handler, .OBJC_ASSOCIATION_RETAIN)

        colorPanel.orderFront(nil)
    }
}

// MARK: - Color Panel Handler

class ColorPanelHandler: NSObject {
    let originalColor: NSColor
    let onColorChange: (NSColor) -> Void

    init(originalColor: NSColor, onColorChange: @escaping (NSColor) -> Void) {
        self.originalColor = originalColor
        self.onColorChange = onColorChange
    }

    @objc func colorChanged(_ sender: NSColorPanel) {
        let newColor = sender.color

        // Convert both colors to sRGB for comparison
        guard let origSRGB = originalColor.usingColorSpace(.sRGB),
              let newSRGB = newColor.usingColorSpace(.sRGB) else {
            onColorChange(newColor)
            return
        }

        // Only fire change if color actually differs (with small tolerance for floating point)
        let rDiff = abs(origSRGB.redComponent - newSRGB.redComponent)
        let gDiff = abs(origSRGB.greenComponent - newSRGB.greenComponent)
        let bDiff = abs(origSRGB.blueComponent - newSRGB.blueComponent)

        let tolerance: CGFloat = 1.0 / 512.0  // Less than half a color step

        if rDiff > tolerance || gDiff > tolerance || bDiff > tolerance {
            onColorChange(newColor)
        }
    }
}

// MARK: - All Palettes View (for 3200-color mode)

struct AllPalettesView: View {
    let paletteInfo: PaletteInfo
    let currentScanline: Int?
    let onColorEdit: ((Int, Int, NSColor) -> Void)?
    @Binding var isPresented: Bool

    @State private var hoveredLine: Int? = nil
    @State private var hoveredColor: Int? = nil
    @State private var selectedLine: Int = 0

    private let swatchSize: CGFloat = 12
    private let colorsPerPalette = 16

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Palette grid - all scanlines
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: true) {
                    LazyVStack(alignment: .leading, spacing: 1) {
                        ForEach(0..<paletteInfo.paletteCount, id: \.self) { lineIndex in
                            paletteRowView(lineIndex: lineIndex)
                                .id(lineIndex)
                        }
                    }
                    .padding(8)
                }
                .onAppear {
                    // Scroll to current scanline
                    if let line = currentScanline {
                        selectedLine = line
                        proxy.scrollTo(line, anchor: .center)
                    }
                }
            }

            Divider()

            // Footer with info
            footerView
        }
        .frame(width: 420, height: 500)
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("All Palettes")
                    .font(.headline)
                let label = paletteInfo.type == .perScanline ? "scanlines" : "palettes"
                Text("\(paletteInfo.paletteCount) \(label) × \(colorsPerPalette) colors")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button("Done") {
                isPresented = false
            }
            .keyboardShortcut(.cancelAction)
        }
        .padding()
    }

    // MARK: - Palette Row

    private func paletteRowView(lineIndex: Int) -> some View {
        let isCurrentLine = lineIndex == currentScanline
        let isHoveredLine = lineIndex == hoveredLine
        let palette = paletteInfo.palettes[safe: lineIndex] ?? []

        return HStack(spacing: 4) {
            // Line number
            Text("\(lineIndex)")
                .font(.system(size: 9, weight: .medium, design: .monospaced))
                .foregroundColor(isCurrentLine ? .accentColor : .secondary)
                .frame(width: 28, alignment: .trailing)

            // Color swatches
            HStack(spacing: 1) {
                ForEach(0..<colorsPerPalette, id: \.self) { colorIndex in
                    if colorIndex < palette.count {
                        let color = palette[colorIndex]
                        Rectangle()
                            .fill(Color(color.nsColor))
                            .frame(width: swatchSize, height: swatchSize)
                            .border(
                                (hoveredLine == lineIndex && hoveredColor == colorIndex) ? Color.white : Color.clear,
                                width: 1
                            )
                            .onHover { hovering in
                                if hovering {
                                    hoveredLine = lineIndex
                                    hoveredColor = colorIndex
                                } else if hoveredLine == lineIndex && hoveredColor == colorIndex {
                                    hoveredLine = nil
                                    hoveredColor = nil
                                }
                            }
                            .onTapGesture {
                                if paletteInfo.isEditable {
                                    openColorPicker(lineIndex: lineIndex, colorIndex: colorIndex, currentColor: color)
                                }
                            }
                            .help("Line \(lineIndex), Color \(colorIndex): \(color.hexString)")
                    } else {
                        Color.gray.opacity(0.3)
                            .frame(width: swatchSize, height: swatchSize)
                    }
                }
            }

            Spacer()
        }
        .padding(.vertical, 1)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 3)
                .fill(isCurrentLine ? Color.accentColor.opacity(0.15) : (isHoveredLine ? Color.gray.opacity(0.1) : Color.clear))
        )
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack {
            if let line = hoveredLine, let color = hoveredColor,
               let palette = paletteInfo.palettes[safe: line],
               color < palette.count {
                Text("Line \(line), Color \(color): \(palette[color].hexString)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("Click a color to edit • Hover for details")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - Color Picker

    private func openColorPicker(lineIndex: Int, colorIndex: Int, currentColor: PaletteColor) {
        let colorPanel = NSColorPanel.shared
        let originalColor = currentColor.nsColor

        // IMPORTANT: Clear target/action FIRST to prevent the old handler from firing
        // when we set the new color (since isContinuous = true)
        colorPanel.setTarget(nil)
        colorPanel.setAction(nil)

        // Now set the color - no action will fire since target is nil
        colorPanel.color = originalColor
        colorPanel.isContinuous = true
        colorPanel.showsAlpha = false

        let handler = AllPalettesColorHandler(
            lineIndex: lineIndex,
            colorIndex: colorIndex,
            originalColor: originalColor,
            onColorChange: onColorEdit
        )
        colorPanel.setTarget(handler)
        colorPanel.setAction(#selector(AllPalettesColorHandler.colorChanged(_:)))

        objc_setAssociatedObject(colorPanel, "colorHandler", handler, .OBJC_ASSOCIATION_RETAIN)
        colorPanel.orderFront(nil)
    }
}

// MARK: - All Palettes Color Handler

class AllPalettesColorHandler: NSObject {
    let lineIndex: Int
    let colorIndex: Int
    let originalColor: NSColor
    let onColorChange: ((Int, Int, NSColor) -> Void)?

    init(lineIndex: Int, colorIndex: Int, originalColor: NSColor, onColorChange: ((Int, Int, NSColor) -> Void)?) {
        self.lineIndex = lineIndex
        self.colorIndex = colorIndex
        self.originalColor = originalColor
        self.onColorChange = onColorChange
    }

    @objc func colorChanged(_ sender: NSColorPanel) {
        let newColor = sender.color

        guard let origSRGB = originalColor.usingColorSpace(.sRGB),
              let newSRGB = newColor.usingColorSpace(.sRGB) else {
            onColorChange?(lineIndex, colorIndex, newColor)
            return
        }

        let rDiff = abs(origSRGB.redComponent - newSRGB.redComponent)
        let gDiff = abs(origSRGB.greenComponent - newSRGB.greenComponent)
        let bDiff = abs(origSRGB.blueComponent - newSRGB.blueComponent)

        let tolerance: CGFloat = 1.0 / 512.0

        if rDiff > tolerance || gDiff > tolerance || bDiff > tolerance {
            onColorChange?(lineIndex, colorIndex, newColor)
        }
    }
}

// MARK: - Array Safe Subscript

extension Array {
    subscript(safe index: Int) -> Element? {
        return indices.contains(index) ? self[index] : nil
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
