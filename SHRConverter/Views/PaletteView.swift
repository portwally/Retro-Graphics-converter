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

                    // Show edit button for all formats with palettes
                    if let info = paletteInfo, info.paletteCount >= 1 {
                        Button(action: { showAllPalettes = true }) {
                            VStack(spacing: 2) {
                                Image(systemName: "square.grid.3x3")
                                    .font(.system(size: 14))
                                Text("Edit")
                                    .font(.system(size: 9))
                            }
                            .frame(width: 40)
                        }
                        .buttonStyle(.bordered)
                        .help(info.paletteCount > 1 ? "Edit all \(info.paletteCount) palettes" : "Edit palette")
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
        .padding(.bottom, 4)
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
                                onTap: { showAllPalettes = true }
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

// MARK: - Color Swatch View (Main palette bar - clicking opens editor)

struct ColorSwatchView: View {
    let color: PaletteColor
    let index: Int
    let isEditable: Bool
    let isHovered: Bool
    var swatchSize: CGFloat = 16
    let onHover: (Bool) -> Void
    let onTap: () -> Void  // Opens the palette editor

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
                    onTap()
                }
            }
            .help(isEditable ? "Click to edit palette" : "Color \(index): \(color.hexString)")
    }
}

// MARK: - All Palettes View (BitPast-style split view editor)

struct AllPalettesView: View {
    let paletteInfo: PaletteInfo
    let currentScanline: Int?
    let onColorEdit: ((Int, Int, NSColor) -> Void)?
    @Binding var isPresented: Bool

    @State private var selectedPaletteIndex: Int = 0
    @State private var selectedColorIndex: Int? = nil
    @State private var copiedPalette: [PaletteColor]? = nil
    @State private var originalPalettes: [[PaletteColor]] = []

    private let colorsPerPalette = 16
    private let is3200Mode: Bool
    private let hasLargePalette: Bool

    // Check if palettes have been modified from original
    private var hasChanges: Bool {
        guard !originalPalettes.isEmpty else { return false }
        return paletteInfo.palettes != originalPalettes
    }

    init(paletteInfo: PaletteInfo, currentScanline: Int?, onColorEdit: ((Int, Int, NSColor) -> Void)?, isPresented: Binding<Bool>) {
        self.paletteInfo = paletteInfo
        self.currentScanline = currentScanline
        self.onColorEdit = onColorEdit
        self._isPresented = isPresented
        self.is3200Mode = paletteInfo.type == .perScanline
        self.hasLargePalette = paletteInfo.colorsPerPalette > 64
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Main content - split view for multiple palettes, single view for one palette
            if paletteInfo.paletteCount > 1 {
                HSplitView {
                    // Left: Palette list
                    paletteListView

                    // Right: Color grid for selected palette
                    colorGridView
                }
            } else {
                // Single palette - no need for list, just show color grid
                colorGridView
            }

            Divider()

            // Footer buttons
            footerView
        }
        .frame(minWidth: hasLargePalette ? 500 : 650, minHeight: hasLargePalette ? 550 : 500)
        .onAppear {
            if let line = currentScanline, line < paletteInfo.paletteCount {
                selectedPaletteIndex = line
            }
            // Store original palettes for reset functionality
            originalPalettes = paletteInfo.palettes
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Text("Palette Editor")
                .font(.headline)
            Spacer()
            Text(headerSubtitle)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var headerSubtitle: String {
        if is3200Mode {
            return "3200 Colors (\(paletteInfo.paletteCount) Scanlines)"
        } else if paletteInfo.paletteCount == 1 {
            return "\(paletteInfo.colorsPerPalette) Colors"
        } else {
            return "\(paletteInfo.paletteCount) Palettes"
        }
    }

    // MARK: - Palette List (Left Side)

    private var paletteListView: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Palettes")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.top, 8)

            ScrollViewReader { proxy in
                List(selection: $selectedPaletteIndex) {
                    ForEach(0..<paletteInfo.paletteCount, id: \.self) { index in
                        HStack(spacing: 4) {
                            Text(is3200Mode ? "Line \(index)" : "Palette \(index)")
                                .font(.caption)
                                .frame(width: 70, alignment: .leading)

                            // Mini preview of palette colors
                            HStack(spacing: 1) {
                                ForEach(0..<min(16, paletteInfo.palettes[safe: index]?.count ?? 0), id: \.self) { colorIdx in
                                    if let palette = paletteInfo.palettes[safe: index], colorIdx < palette.count {
                                        Rectangle()
                                            .fill(Color(palette[colorIdx].nsColor))
                                            .frame(width: 8, height: 12)
                                    }
                                }
                            }
                        }
                        .tag(index)
                    }
                }
                .listStyle(.sidebar)
                .onAppear {
                    if let line = currentScanline {
                        proxy.scrollTo(line, anchor: .center)
                    }
                }
            }
        }
        .frame(minWidth: 220, maxWidth: 280)
    }

    // MARK: - Color Grid (Right Side)

    // Grid configuration based on palette size
    private func gridConfig(for colorCount: Int) -> (columns: Int, cellSize: CGFloat, spacing: CGFloat) {
        if colorCount <= 16 {
            return (4, 50, 8)       // 4x4 grid, large cells
        } else if colorCount <= 64 {
            return (8, 32, 4)       // 8x8 grid, medium cells
        } else {
            return (16, 20, 2)      // 16x16 grid, small cells
        }
    }

    private var colorGridView: some View {
        VStack(spacing: 12) {
            if selectedPaletteIndex < paletteInfo.paletteCount,
               let palette = paletteInfo.palettes[safe: selectedPaletteIndex] {

                Text(is3200Mode ? "Scanline \(selectedPaletteIndex)" : "Palette \(selectedPaletteIndex)")
                    .font(.headline)
                    .padding(.top, 12)

                let config = gridConfig(for: palette.count)

                // Scrollable color grid for large palettes
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(config.cellSize + config.spacing), spacing: config.spacing), count: config.columns), spacing: config.spacing) {
                        ForEach(0..<palette.count, id: \.self) { colorIdx in
                            PaletteColorCellCompact(
                                color: palette[colorIdx],
                                index: colorIdx,
                                isSelected: selectedColorIndex == colorIdx,
                                isEditable: paletteInfo.isEditable,
                                cellSize: config.cellSize,
                                showIndex: palette.count <= 64
                            ) {
                                selectedColorIndex = colorIdx
                                if paletteInfo.isEditable {
                                    openColorPicker(paletteIndex: selectedPaletteIndex, colorIndex: colorIdx, currentColor: palette[colorIdx])
                                }
                            }
                        }
                    }
                    .padding()
                }

                // Selected color info
                if let colorIdx = selectedColorIndex, colorIdx < palette.count {
                    let color = palette[colorIdx]
                    VStack(spacing: 4) {
                        Text("Color \(colorIdx)")
                            .font(.caption)
                        Text(color.hexString)
                            .font(.system(.caption, design: .monospaced))
                        Text("RGB: \(Int(color.r)), \(Int(color.g)), \(Int(color.b))")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Copy/Paste palette buttons
                if paletteInfo.isEditable {
                    HStack {
                        Button("Copy Palette") {
                            copyPalette()
                        }
                        Button("Paste Palette") {
                            pastePalette()
                        }
                        .disabled(copiedPalette == nil)
                    }
                    .padding(.bottom, 12)
                }
            } else {
                Text("Select a palette")
                    .foregroundColor(.secondary)
                Spacer()
            }
        }
        .frame(minWidth: 320)
    }

    // MARK: - Footer

    private var footerView: some View {
        HStack {
            if !paletteInfo.isEditable {
                Text("This palette is fixed and cannot be edited")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            if paletteInfo.isEditable {
                Button("Reset") {
                    resetPalettes()
                }
                .disabled(!hasChanges)
                .help("Reset all colors to original values")
            }

            Button("Done") {
                closeColorPanel()
                isPresented = false
            }
            .keyboardShortcut(.defaultAction)
        }
        .padding()
    }

    // MARK: - Copy/Paste

    private func copyPalette() {
        if let palette = paletteInfo.palettes[safe: selectedPaletteIndex] {
            copiedPalette = palette
        }
    }

    private func pastePalette() {
        guard let copied = copiedPalette, paletteInfo.isEditable else { return }
        for (colorIndex, color) in copied.enumerated() {
            onColorEdit?(selectedPaletteIndex, colorIndex, color.nsColor)
        }
    }

    // MARK: - Reset

    private func resetPalettes() {
        // Restore all original colors
        for (paletteIndex, palette) in originalPalettes.enumerated() {
            for (colorIndex, color) in palette.enumerated() {
                onColorEdit?(paletteIndex, colorIndex, color.nsColor)
            }
        }
    }

    // MARK: - Color Picker

    private func openColorPicker(paletteIndex: Int, colorIndex: Int, currentColor: PaletteColor) {
        let colorPanel = NSColorPanel.shared
        let originalColor = currentColor.nsColor

        colorPanel.setTarget(nil)
        colorPanel.setAction(nil)

        colorPanel.color = originalColor
        colorPanel.isContinuous = true
        colorPanel.showsAlpha = false

        let handler = AllPalettesColorHandler(
            lineIndex: paletteIndex,
            colorIndex: colorIndex,
            originalColor: originalColor,
            onColorChange: onColorEdit
        )
        colorPanel.setTarget(handler)
        colorPanel.setAction(#selector(AllPalettesColorHandler.colorChanged(_:)))

        objc_setAssociatedObject(colorPanel, "colorHandler", handler, .OBJC_ASSOCIATION_RETAIN)
        colorPanel.orderFront(nil)
    }

    private func closeColorPanel() {
        let colorPanel = NSColorPanel.shared
        colorPanel.setTarget(nil)
        colorPanel.setAction(nil)
        colorPanel.close()
    }
}

// MARK: - Palette Color Cell

struct PaletteColorCell: View {
    let color: PaletteColor
    let index: Int
    let isSelected: Bool
    let isEditable: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 2) {
            Rectangle()
                .fill(Color(color.nsColor))
                .frame(width: 50, height: 50)
                .border(isSelected ? Color.accentColor : Color.gray.opacity(0.5), width: isSelected ? 3 : 1)
                .onTapGesture {
                    onTap()
                }

            Text("\(index)")
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .help(isEditable ? "Click to edit color \(index)" : "Color \(index): \(color.hexString)")
    }
}

// MARK: - Compact Palette Color Cell (for large palettes)

struct PaletteColorCellCompact: View {
    let color: PaletteColor
    let index: Int
    let isSelected: Bool
    let isEditable: Bool
    let cellSize: CGFloat
    let showIndex: Bool
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 1) {
            Rectangle()
                .fill(Color(color.nsColor))
                .frame(width: cellSize, height: cellSize)
                .border(isSelected ? Color.accentColor : Color.gray.opacity(0.3), width: isSelected ? 2 : 0.5)
                .onTapGesture {
                    onTap()
                }

            if showIndex {
                Text("\(index)")
                    .font(.system(size: 8, design: .monospaced))
                    .foregroundColor(.secondary)
            }
        }
        .help(isEditable ? "Click to edit color \(index)" : "Color \(index): \(color.hexString)")
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
