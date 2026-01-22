import Foundation
import AppKit

// MARK: - Palette Color

struct PaletteColor: Identifiable, Equatable {
    let id = UUID()
    var r: UInt8
    var g: UInt8
    var b: UInt8

    init(r: UInt8, g: UInt8, b: UInt8) {
        self.r = r
        self.g = g
        self.b = b
    }

    init(from tuple: (r: UInt8, g: UInt8, b: UInt8)) {
        self.r = tuple.r
        self.g = tuple.g
        self.b = tuple.b
    }

    init(nsColor: NSColor) {
        let color = nsColor.usingColorSpace(.sRGB) ?? nsColor
        self.r = UInt8(color.redComponent * 255)
        self.g = UInt8(color.greenComponent * 255)
        self.b = UInt8(color.blueComponent * 255)
    }

    var nsColor: NSColor {
        NSColor(red: CGFloat(r) / 255.0, green: CGFloat(g) / 255.0, blue: CGFloat(b) / 255.0, alpha: 1.0)
    }

    var swiftUIColor: Color {
        Color(nsColor)
    }

    var hexString: String {
        String(format: "#%02X%02X%02X", r, g, b)
    }

    static func == (lhs: PaletteColor, rhs: PaletteColor) -> Bool {
        lhs.r == rhs.r && lhs.g == rhs.g && lhs.b == rhs.b
    }
}

// MARK: - Palette Type

enum PaletteType: Equatable {
    case fixed           // Fixed palette (C64, ZX Spectrum) - not editable
    case single          // Single palette (standard SHR, Degas, IFF)
    case multiPalette    // Multiple palettes (SHR with 16 palettes, selectable)
    case perScanline     // Per-scanline (3200-color mode - 200 palettes)

    var isEditable: Bool {
        switch self {
        case .fixed:
            return false
        default:
            return true
        }
    }

    var description: String {
        switch self {
        case .fixed:
            return "Fixed palette"
        case .single:
            return "Single palette"
        case .multiPalette:
            return "Multiple palettes"
        case .perScanline:
            return "Per-scanline palettes"
        }
    }
}

// MARK: - Palette Info

struct PaletteInfo: Equatable {
    let type: PaletteType
    var palettes: [[PaletteColor]]  // Array of palettes (each palette = array of colors)
    let colorsPerPalette: Int
    let platformName: String        // e.g., "Apple IIgs", "C64", "Amiga"

    // For formats that use SCB to select palette per scanline
    var scbMapping: [Int]?          // Maps scanline -> palette index (for standard SHR)

    init(type: PaletteType, palettes: [[PaletteColor]], colorsPerPalette: Int, platformName: String, scbMapping: [Int]? = nil) {
        self.type = type
        self.palettes = palettes
        self.colorsPerPalette = colorsPerPalette
        self.platformName = platformName
        self.scbMapping = scbMapping
    }

    // Convenience initializer for single palette
    init(singlePalette: [PaletteColor], platformName: String) {
        self.type = .single
        self.palettes = [singlePalette]
        self.colorsPerPalette = singlePalette.count
        self.platformName = platformName
        self.scbMapping = nil
    }

    // Convenience initializer for fixed palette
    init(fixedPalette: [PaletteColor], platformName: String) {
        self.type = .fixed
        self.palettes = [fixedPalette]
        self.colorsPerPalette = fixedPalette.count
        self.platformName = platformName
        self.scbMapping = nil
    }

    var totalColors: Int {
        palettes.count * colorsPerPalette
    }

    var totalUniqueColors: Int {
        var uniqueColors = Set<String>()
        for palette in palettes {
            for color in palette {
                uniqueColors.insert("\(color.r)-\(color.g)-\(color.b)")
            }
        }
        return uniqueColors.count
    }

    var paletteCount: Int {
        palettes.count
    }

    var isEditable: Bool {
        type.isEditable
    }

    // Get palette for a specific scanline (for 3200-color mode)
    func palette(forScanline line: Int) -> [PaletteColor]? {
        switch type {
        case .perScanline:
            guard line >= 0 && line < palettes.count else { return nil }
            return palettes[line]
        case .multiPalette:
            // Use SCB mapping if available
            if let mapping = scbMapping, line < mapping.count {
                let paletteIndex = mapping[line]
                guard paletteIndex >= 0 && paletteIndex < palettes.count else { return palettes.first }
                return palettes[paletteIndex]
            }
            return palettes.first
        case .single, .fixed:
            return palettes.first
        }
    }

    // Get the primary/default palette for display
    var primaryPalette: [PaletteColor] {
        palettes.first ?? []
    }

    // Description for UI display
    var displayDescription: String {
        switch type {
        case .fixed:
            return "\(colorsPerPalette) colors (fixed)"
        case .single:
            return "\(colorsPerPalette) colors"
        case .multiPalette:
            return "\(palettes.count) palettes x \(colorsPerPalette) colors"
        case .perScanline:
            return "\(palettes.count) scanlines x \(colorsPerPalette) colors"
        }
    }

    // Mutating function to update a color
    mutating func updateColor(paletteIndex: Int, colorIndex: Int, newColor: PaletteColor) {
        guard paletteIndex >= 0 && paletteIndex < palettes.count else { return }
        guard colorIndex >= 0 && colorIndex < palettes[paletteIndex].count else { return }
        palettes[paletteIndex][colorIndex] = newColor
    }

    // Create a copy with a modified color
    func withUpdatedColor(paletteIndex: Int, colorIndex: Int, newColor: PaletteColor) -> PaletteInfo {
        var copy = self
        copy.updateColor(paletteIndex: paletteIndex, colorIndex: colorIndex, newColor: newColor)
        return copy
    }

    static func == (lhs: PaletteInfo, rhs: PaletteInfo) -> Bool {
        lhs.type == rhs.type &&
        lhs.palettes == rhs.palettes &&
        lhs.colorsPerPalette == rhs.colorsPerPalette &&
        lhs.platformName == rhs.platformName
    }
}

// MARK: - SwiftUI Color Extension

import SwiftUI

extension Color {
    init(_ paletteColor: PaletteColor) {
        self.init(red: Double(paletteColor.r) / 255.0,
                  green: Double(paletteColor.g) / 255.0,
                  blue: Double(paletteColor.b) / 255.0)
    }
}
