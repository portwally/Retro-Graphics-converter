# Changelog

## Version 4.3 - 2026-02-01

### Atari 8-bit (400/800/XL/XE) Support

- **Atari 8-bit Graphics Formats**: Added full support for Atari 8-bit computer graphics formats:
  - **GR.8** (320×192, 2 colors): Hi-res monochrome mode
  - **GR.9** (160×192, 8 luminances): GTIA mode with 16 shade values mapped to 8 distinct luminance levels
  - **GR.10** (160×192, 9 colors): GTIA mode with 9 programmable colors
  - **GR.11** (160×192, 16 colors): GTIA mode with 16 hue colors at one luminance
  - **GR.15/GR.7** (160×192, 4 colors): Standard 4-color graphics mode
  - **MIC** (MicroIllustrator): Popular paint program format with embedded palette
- **ATR Disk Image Browser**: Added full support for reading Atari 8-bit ATR disk images (.atr files)
- **Atari DOS 2.0/2.5 Filesystem**: Parses Atari DOS directory structure (sectors 361-368) and extracts files following sector chains
- **Multiple Disk Densities**: Supports single density (90KB), enhanced density (130KB), and double density (180KB) disk images
- **CTIA/GTIA Palette**: Uses authentic 128-color Atari palette (16 hues × 8 luminance levels)
- **Auto-detect Images**: Automatically identifies and displays Atari 8-bit graphics files extracted from ATR disks
- **BitPast Palette Integration**: Reads embedded color register data from BitPast-exported files for accurate color reproduction
- **Correct Aspect Ratio**: GTIA modes (GR.9, GR.10, GR.11) display at 160×192 with 2x horizontal pixel stretching for correct aspect ratio
- **Truncated Extension Detection**: Automatically detects GR.10 files when Atari DOS truncates extension to "GR1"

---

## Version 4.2 - 2026-01-29

### Amiga HAM Mode Support

- **HAM6/HAM8 Decoding**: Added full support for Amiga Hold-And-Modify (HAM) mode images. HAM6 displays up to 4096 colors, HAM8 displays up to 262144 colors.
- **CAMG Chunk Parsing**: IFF decoder now parses the CAMG chunk to detect HAM and EHB (Extra Half-Brite) viewport modes.
- **HAM Palette Display**: Palette editor now shows the actual colors extracted from the rendered HAM image (up to 256 most frequent colors), sorted by frequency. This provides a useful view of the colors actually used in the image rather than just the base palette.

### Histogram Improvements

- **Accurate Color Count**: Fixed the histogram "Colors" statistic to correctly count unique RGB colors in the image. Previously it counted histogram bins rather than actual unique color combinations.
- **HAM Color Accuracy**: HAM images now show the actual number of unique colors displayed (e.g., hundreds or thousands) rather than just the base palette size.

### PCX Format Improvements

- **EGA 16-Color Planar**: Fixed decoding of EGA 16-color PCX files (1 bit/pixel, 4 planes). Previously showed only 1/4 of the image with wrong colors.
- **EGA 64-Color Planar**: Added support for EGA 64-color mode PCX files (2 bits/pixel, 4 planes) with proper 6-bit RGB palette.
- **CGA 4-Color Mode**: Fixed CGA PCX files that have incorrect headers (claims 1 bit/pixel but bytesPerLine indicates 2 bits/pixel). Now auto-detects this mismatch and decodes correctly.
- **4-Bit Packed Mode**: Added support for 16-color packed PCX files (4 bits/pixel, 1 plane).
- **Monochrome Mode**: Fixed 1-bit monochrome PCX files (1 bit/pixel, 1 plane).
- **Standard EGA/VGA Palettes**: Added proper default EGA 16-color and EGA 64-color palettes when header palette is missing.
- **PCX Palette Editing**: Added full palette editor support for all PCX formats (CGA 4-color, EGA 16-color, EGA 64-color, VGA 256-color, monochrome). Click any color to edit it and see the image update in real-time.

### BBC Micro Improvements

- **New .bbc Extension**: Added support for .bbc file extension commonly used for BBC Micro screen dumps.
- **Smart Mode Detection**: Parser now auto-detects BBC Micro mode from filename (e.g., "picture mode 2.bbc" loads as MODE 2).
- **Fixed Memory Layout**: Corrected decoder to use proper BBC Micro character-cell based screen memory organization (8 bytes per character column).
- **All Modes Supported**: MODE 0 (640x256, 2 colors), MODE 1 (320x256, 4 colors), MODE 2 (160x256, 16 colors), MODE 4 (320x256, 2 colors), MODE 5 (160x256, 4 colors).

### Amiga ADF Disk Image Support

- **ADF Disk Browser**: Added full support for reading Amiga ADF disk images (.adf files).
- **AmigaDOS Filesystem**: Parses AmigaDOS/FFS filesystem structure including root block, directories, and file headers.
- **File Extraction**: Extracts files from ADF disks with support for both OFS (Original File System) and FFS (Fast File System).
- **Directory Support**: Browse nested directories within ADF disk images.
- **Auto-detect IFF Images**: Automatically identifies and displays IFF/ILBM images stored on Amiga disks.
- **DD and HD Disks**: Supports both Double Density (880KB) and High Density (1.76MB) disk images.

### Amstrad CPC Disk Image Support

- **CPC DSK Disk Browser**: Added full support for reading Amstrad CPC disk images (.dsk files in CPCEMU format).
- **Format Detection**: Automatically distinguishes CPC DSK from Apple II DSK by detecting the unique "MV - CPC" or "EXTENDED CPC DSK File" header signatures.
- **Extended Format**: Supports both standard CPCEMU DSK and extended DSK formats with variable sector sizes.
- **CP/M Filesystem**: Parses the CP/M-like directory structure used by AMSDOS.
- **Multi-extent Files**: Correctly handles files spanning multiple directory extents.
- **Auto-detect Images**: Identifies and displays Amstrad CPC graphics files (SCR, etc.) stored on disks.

### Atari ST Disk Image Support

- **ST Disk Browser**: Added full support for reading Atari ST disk images (.st files - raw sector dumps).
- **FAT12 Filesystem**: Parses the FAT12 filesystem structure used by Atari ST floppies, including boot sector BPB, allocation table, and directory entries.
- **Multiple Disk Sizes**: Supports 360KB (SS/DD), 720KB (DS/DD), and 1.44MB (DS/HD) disk images.
- **Directory Support**: Browse nested directories within ST disk images.
- **Auto-detect Images**: Automatically identifies and displays Degas (.PI1/.PI2/.PI3), NEOchrome (.NEO), and IFF/ILBM images stored on disks.

### MSX Disk Image Support

- **MSX Disk Browser**: Added full support for reading MSX disk images (.dsk files with FAT12 filesystem).
- **FAT12 Filesystem**: Parses the FAT12 filesystem structure used by MSX computers, including boot sector BPB, allocation table, and directory entries.
- **Multiple Disk Sizes**: Supports 360KB (SS/DD) and 720KB (DS/DD) disk images.
- **Directory Support**: Browse nested directories within MSX disk images.
- **Auto-detect Images**: Automatically identifies MSX graphics files (SC2, SC5, SC7, SC8, GRP, SR5, SR7, SR8, GE5, GE7, GE8) including BSAVE format.
- **Smart Detection**: Distinguishes MSX disks from Apple II and CPC disks by validating FAT12 structure and media descriptor.

### Bug Fixes

- **MSX Screen 2 Decoding**: Fixed SC2 file decoding which was showing garbled/corrupted images. The issue had two parts:
  1. MSX .dsk disk images were incorrectly identified as Atari ST disks (both use FAT12 with similar parameters). Added detection for "MSX" OEM signature in boot sector to correctly route to MSX disk reader.
  2. The SC2 decoder used wrong table order. BitPast and common MSX tools save SC2 files as PGT+CT+PNT (Pattern Generator + Color Table + Pattern Name Table), but the decoder expected PGT+PNT+CT. Fixed to use correct order for packed format files.
- **Paintworks Palette Display**: Fixed palette extraction for Paintworks format files (from previous session).
- **ADF OFS File Extraction**: Fixed extraction of larger files from OFS (Original File System) formatted ADF disks. The OFS data block chain could be broken on some disks; now uses the data block table with sequence number sorting for reliable extraction.
- **CPC DSK Block Mapping**: Fixed file extraction from CPC DSK images with non-contiguous track numbering. Some CPC disk images only contain even-numbered tracks, which caused the previous block-to-sector mapping to fail. Now uses linear sector addressing to properly handle all track layouts.
- **CPC Image Detection**: Files extracted from CPC DSK disks with .SCR extension are now forced to be identified as Amstrad CPC graphics instead of being misdetected as Apple II DHGR. The CPC decoder also now accepts files with slight size variations (16000-17000 bytes) instead of requiring exactly 16384 bytes.
- **Amstrad CPC Color Compatibility**: Fixed color display for .scr files exported from BitPast. The 27-color hardware palette is now interpreted identically to BitPast, ensuring imported images display with correct colors. Also fixed Mode 0/Mode 1 bit encoding and mode detection from embedded AMSDOS header palettes.

---

## Version 4.1 - 2026-01-25

### Palette Editor Improvements

- **Reset Button**: Added Reset button in palette editor footer to restore all colors to their original values. Button is disabled when no changes have been made.
- **Improved Click Behavior**: Clicking on color swatches in the main palette bar now opens the full palette editor instead of the color picker directly. This provides a more consistent editing experience.
- **BitPast-Style Editor**: Redesigned palette editor with split view layout featuring palette list on left, color grid on right, larger color swatches (50x50), and color index numbers below each swatch.
- **256-Color Support**: Palette editor now properly displays palettes with up to 256 colors using dynamic grid sizing (4x4 for ≤16, 8x8 for ≤64, 16x16 for >64 colors).
- **Single Palette Mode**: For formats with only one palette, the editor now shows just the color grid without the sidebar list.

### New Format Support

- **C64 Art Studio Hi-Res**: Added support for 9002-byte C64 Art Studio Hi-Res format (2-byte load address + 8000-byte bitmap + 1000-byte screen RAM).
- **MSX Graphics Editor Extensions**: Added support for .GE1, .GE2, .GE5, .GE7, .GE8, .GR5, .GR7, .GR8 MSX graphics file extensions.

### Bug Fixes

- **Fixed MSX Palette Editing**: MSX Screen 5, Screen 8, and Screen 2 images now support live palette editing with proper re-rendering.
- **Fixed Paintworks/Packed SHR Palette Editing**: Paintworks and Packed SHR format images now support live palette editing. Previously these compressed formats couldn't re-render with modified palettes.

- **Fixed Packed SHR Palette Display**: Packed SHR format images now correctly show their palettes. The extractor now decompresses the data before reading palette information.
- **Fixed PI3 Format Detection**: Atari ST Degas .PI3 files were incorrectly identified as TRS-80 CoCo images. Added proper Degas extension detection for .PI1, .PI2, .PI3 files.
- **Fixed Palette Display Cutoff**: Added bottom padding to prevent palette text from being cut off by the status bar.
- **Edit Button Visibility**: The Edit button now appears for all formats with palettes (previously only showed for multi-palette formats).

### Documentation

- **GitHub Link**: Fixed the GitHub repository link in the Help menu to point to the correct URL.
- **C64 Disk Formats**: Added documentation for C64 disk image formats (.d64, .d71, .d81) in Help view and README.

---

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
