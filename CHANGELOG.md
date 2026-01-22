# Changelog

## Version 4.0 - 2026-01-22

### Major UI Overhaul

Complete redesign of the application interface with a modern, streamlined layout:

- **New Toolbar Layout**: Reorganized toolbar with Import/Export buttons on the left, zoom controls and tools on the right
- **Bottom Info Bar**: File information and palette display moved to a dedicated info bar at the bottom of the window
- **Status Bar**: New status bar showing real-time counts for Imported, Selected, Removed, and Exported images
- **Export Sheet**: New modal export dialog with format checkboxes (PNG, JPEG, TIFF, GIF, HEIC) and scale options (1x, 2x, 4x, 8x)
- **Mutually Exclusive Export Formats**: "Original" format and modern formats are now mutually exclusive - selecting Original automatically deselects modern formats and vice versa
- **Cleaner Preview Area**: Removed redundant status messages from preview panel for a cleaner look
- **Image Browser Default Visibility**: The sidebar now shows by default when the app opens

### Live Palette Editing

Revolutionary new feature allowing real-time palette color modification:

- **Click-to-Edit Colors**: Click any color swatch in the palette to open the macOS color picker
- **Live Preview**: Modified colors instantly update the preview image in real-time
- **All Palettes Editor**: New "Edit [count]" button for 3200-color and multi-palette images opens a sheet showing all palettes with:
  - Scrollable list of all 200 scanlines (3200-color mode) or all palettes
  - Current scanline highlighted with accent color
  - Click any color to edit with the system color picker
  - Hover tooltips showing line number, color index, and hex value
- **Per-Format Support**: Palette editing works for:
  - Apple IIgs SHR (standard and 3200-color modes)
  - Apple II HGR (6-color artifact palette)
  - Apple II DHGR (16-color palette)
  - Commodore 64 (16-color palette)
  - Amiga IFF (up to 256 colors)
  - Atari ST Degas (16 colors)
  - PC PCX and BMP (indexed color modes)
  - ZX Spectrum (16-color palette)
- **Output Only**: Palette modifications affect exported images only - original files remain unchanged
- **Fixed Palette Indication**: Non-editable palettes (C64, ZX Spectrum) are clearly marked as "fixed"

### Dynamic Palette Display

Intelligent palette visualization that adapts to the image format:

- **Live Scanline Tracking**: For 3200-color mode images, hovering over the preview image updates the palette display in real-time to show the palette for that scanline
- **Multi-Palette Support**: SHR images with SCB-controlled palettes show the active palette for the current scanline
- **Palette Type Labels**: Clear indication of palette type (Fixed, Single, Multiple, Per-scanline)
- **Color Tooltips**: Hover over any color to see its index and hex value
- **Adaptive Large Palette Layout**: Palettes with 256 colors now display in a compact grid (64 colors per row) without scrolling, using the full horizontal space
- **Help View**: New Help menu option explaining all app features and supported formats

### New Palette System Architecture

Complete palette infrastructure for extraction, display, and re-rendering:

- **PaletteInfo Model**: New data model supporting four palette types:
  - `fixed` - Non-editable system palettes (C64, ZX Spectrum)
  - `single` - Single palette (standard SHR, Degas, IFF)
  - `multiPalette` - Multiple selectable palettes (SHR with 16 palettes)
  - `perScanline` - Per-scanline palettes (3200-color mode with 200 palettes)

- **PaletteExtractor**: Extracts palette data from all supported formats:
  - Standard SHR palettes from SCB and color table areas
  - 3200-color palettes (200 scanlines x 16 colors)
  - 3201 compressed format palettes
  - DreamGrafix palettes (256-color and 3200-color modes)
  - APF (Apple Preferred Format) embedded palettes
  - Paintworks format palettes
  - Fixed palettes for HGR, DHGR, C64, ZX Spectrum

- **PaletteRenderer**: Re-renders images with modified palettes:
  - Format-aware rendering for accurate color reproduction
  - Proper handling of different 3200-color format layouts (standard, 3201, DreamGrafix)
  - HGR artifact color rendering with custom palette
  - DHGR 16-color rendering with palette support

### Format Support Improvements

- **3201 Compressed Format**: Full support for compressed 3200-color images with "APP\0" header
- **DreamGrafix Formats**: Complete support for both 256-color and 3200-color DreamGrafix images with LZW decompression
- **APF Format**: Improved Apple Preferred Format palette extraction from MAIN blocks

### Bug Fixes

- **Fixed BMP palette extraction**: BMP files with 256-color palettes were only showing 16 colors. The palette offset was incorrectly hardcoded to 54 bytes. Now correctly calculates the offset as `14 + DIB header size` and respects the `colorsUsed` field from the BMP header.

- **Fixed 3200-color image distortion when editing palette**: Different 3200-color format variants (standard, 3201/Packed, DreamGrafix) have different data layouts. The renderer now properly detects the format and extracts pixel data from the correct location.

- **Fixed colors changing immediately when clicking palette**: Opening the color picker caused immediate color changes due to color space conversion. Fixed by using consistent sRGB color space and adding change tolerance detection.

- **Fixed HGR palette modification not working**: Implemented proper HGR renderer that uses the 6-color artifact palette (Black, White, Green, Violet, Orange, Blue) with correct bit pattern and high-bit logic.

- **Fixed 3201 palette color order**: Colors in 3201 files are stored in reverse order. Fixed palette parsing to correctly reverse color indices.

### Files Added

- `SHRConverter/Models/PaletteInfo.swift` - Palette data model with color, type, and palette info structures
- `SHRConverter/Decoders/PaletteExtractor.swift` - Palette extraction for all supported formats
- `SHRConverter/Decoders/PaletteRenderer.swift` - Image re-rendering with modified palettes
- `SHRConverter/Views/ToolbarView.swift` - New toolbar component with zoom controls
- `SHRConverter/Views/PaletteView.swift` - Palette display with color editing and All Palettes sheet
- `SHRConverter/Views/InfoBarView.swift` - Bottom info bar combining file info and palette
- `SHRConverter/Views/StatusBarView.swift` - Status counter bar
- `SHRConverter/Views/ExportSheet.swift` - Export dialog with format and scale options
- `SHRConverter/Views/HelpView.swift` - Help documentation view with feature descriptions

### Files Modified

- `SHRConverter/Views/ContentView.swift` - Major restructure for new layout, palette editing integration, status tracking, scanline tracking overlay for 3200-color mode
- `SHRConverter/Models/DiskCatalog.swift` - Added paletteInfo and modifiedPalette to ImageItem
- `SHRConverter/Decoders/SHRDecoder.swift` - 3201 format support, DreamGrafix detection improvements
- `SHRConverter/Decoders/DreamGrafixDecoder.swift` - Enhanced 3200-color mode handling
- `SHRConverter/SHRConverterApp.swift` - Added Help menu with HelpView

---

## Previous Versions

For changes prior to version 4.0, please refer to the git history.
